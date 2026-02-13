"""
Route Optimization Engine - Salesforce Work Order Sync
======================================================

Synchronizes work orders from Salesforce (WorkOrder and WorkOrderLineItem
objects) into the local MongoDB data store. Supports both incremental sync
(based on LastModifiedDate) and full sync modes.

Usage:
    # Incremental sync (default) - fetches records modified since last sync
    python -m integrations.salesforce.sync_work_orders

    # Full sync - fetches all work orders
    python -m integrations.salesforce.sync_work_orders --full

    # Sync with custom lookback window
    python -m integrations.salesforce.sync_work_orders --since 2025-01-01T00:00:00Z

Environment Variables:
    SF_USERNAME          - Salesforce username
    SF_PASSWORD          - Salesforce password
    SF_SECURITY_TOKEN    - Salesforce security token
    SF_DOMAIN            - Salesforce domain (default: login)
    MONGODB_URI          - MongoDB connection string
    MONGODB_DATABASE     - MongoDB database name (default: route_optimization)
    SYNC_BATCH_SIZE      - Number of records per upsert batch (default: 200)
"""

import argparse
import logging
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from pymongo import MongoClient, UpdateOne
from pymongo.errors import BulkWriteError
from simple_salesforce import Salesforce, SalesforceAuthenticationFailed
from simple_salesforce.exceptions import SalesforceError

# ---------------------------------------------------------------------------
# Logging configuration
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("salesforce_sync")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
DEFAULT_BATCH_SIZE = 200
MAX_RETRIES = 5
BASE_RETRY_DELAY_SECONDS = 2
MAX_RETRY_DELAY_SECONDS = 120

# Salesforce SOQL queries
WORK_ORDER_FIELDS = [
    "Id",
    "WorkOrderNumber",
    "Subject",
    "Description",
    "Status",
    "Priority",
    "WorkTypeId",
    "WorkType.Name",
    "ServiceTerritoryId",
    "ServiceTerritory.Name",
    "AccountId",
    "Account.Name",
    "ContactId",
    "Street",
    "City",
    "State",
    "PostalCode",
    "Country",
    "Latitude",
    "Longitude",
    "StartDate",
    "EndDate",
    "Duration",
    "DurationType",
    "CreatedDate",
    "LastModifiedDate",
]

LINE_ITEM_FIELDS = [
    "Id",
    "WorkOrderId",
    "LineItemNumber",
    "Subject",
    "Status",
    "Duration",
    "DurationType",
    "StartDate",
    "EndDate",
    "CreatedDate",
    "LastModifiedDate",
]


# ---------------------------------------------------------------------------
# Salesforce field to internal schema mapping
# ---------------------------------------------------------------------------
FIELD_MAPPING = {
    "Id": "salesforce_id",
    "WorkOrderNumber": "work_order_number",
    "Subject": "subject",
    "Description": "description",
    "Status": "sf_status",
    "Priority": "priority",
    "Street": "address",
    "City": "city",
    "State": "state",
    "PostalCode": "zip_code",
    "Country": "country",
    "Latitude": "latitude",
    "Longitude": "longitude",
    "StartDate": "time_window_start",
    "EndDate": "time_window_end",
    "Duration": "estimated_duration_min",
    "CreatedDate": "created_at",
    "LastModifiedDate": "updated_at",
}

PRIORITY_MAPPING = {
    "Critical": "critical",
    "High": "high",
    "Medium": "medium",
    "Low": "low",
    None: "medium",
}

STATUS_MAPPING = {
    "New": "pending",
    "In Progress": "in_progress",
    "On Hold": "deferred",
    "Completed": "completed",
    "Closed": "completed",
    "Canceled": "cancelled",
    "Cannot Complete": "cancelled",
}


# ---------------------------------------------------------------------------
# Retry decorator with exponential backoff
# ---------------------------------------------------------------------------
def retry_with_backoff(
    max_retries: int = MAX_RETRIES,
    base_delay: float = BASE_RETRY_DELAY_SECONDS,
    max_delay: float = MAX_RETRY_DELAY_SECONDS,
    retryable_exceptions: tuple = (SalesforceError, ConnectionError, TimeoutError),
):
    """Decorator that retries a function with exponential backoff."""

    def decorator(func):
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(1, max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except retryable_exceptions as exc:
                    last_exception = exc
                    if attempt == max_retries:
                        logger.error(
                            "Max retries (%d) reached for %s: %s",
                            max_retries,
                            func.__name__,
                            str(exc),
                        )
                        raise

                    delay = min(base_delay * (2 ** (attempt - 1)), max_delay)
                    logger.warning(
                        "Attempt %d/%d for %s failed: %s. Retrying in %.1f seconds...",
                        attempt,
                        max_retries,
                        func.__name__,
                        str(exc),
                        delay,
                    )
                    time.sleep(delay)

            raise last_exception  # Should not reach here, but safety net

        return wrapper

    return decorator


# ---------------------------------------------------------------------------
# Salesforce connection
# ---------------------------------------------------------------------------
@retry_with_backoff(
    max_retries=3,
    retryable_exceptions=(SalesforceAuthenticationFailed, ConnectionError),
)
def connect_salesforce() -> Salesforce:
    """Establish an authenticated connection to Salesforce."""
    username = os.environ["SF_USERNAME"]
    password = os.environ["SF_PASSWORD"]
    security_token = os.environ["SF_SECURITY_TOKEN"]
    domain = os.environ.get("SF_DOMAIN", "login")

    logger.info("Connecting to Salesforce as %s (domain: %s)...", username, domain)

    sf = Salesforce(
        username=username,
        password=password,
        security_token=security_token,
        domain=domain,
    )

    logger.info("Successfully connected to Salesforce (org: %s)", sf.sf_instance)
    return sf


# ---------------------------------------------------------------------------
# MongoDB connection
# ---------------------------------------------------------------------------
def connect_mongodb() -> tuple:
    """Establish a connection to MongoDB and return (client, database)."""
    uri = os.environ.get(
        "MONGODB_URI",
        "mongodb://routeadmin:routepass123@localhost:27017/route_optimization?authSource=admin",
    )
    db_name = os.environ.get("MONGODB_DATABASE", "route_optimization")

    logger.info("Connecting to MongoDB database '%s'...", db_name)
    client = MongoClient(uri, serverSelectionTimeoutMS=10000)

    # Verify connectivity
    client.admin.command("ping")
    db = client[db_name]
    logger.info("Successfully connected to MongoDB.")
    return client, db


# ---------------------------------------------------------------------------
# Data transformation
# ---------------------------------------------------------------------------
def map_work_order(sf_record: dict[str, Any]) -> dict[str, Any]:
    """Transform a Salesforce WorkOrder record to our internal schema."""
    mapped = {}

    for sf_field, internal_field in FIELD_MAPPING.items():
        value = sf_record.get(sf_field)
        if value is not None:
            mapped[internal_field] = value

    # Map priority using lookup table
    raw_priority = sf_record.get("Priority")
    mapped["priority"] = PRIORITY_MAPPING.get(raw_priority, "medium")

    # Map status using lookup table
    raw_status = sf_record.get("Status")
    mapped["status"] = STATUS_MAPPING.get(raw_status, "pending")

    # Extract nested WorkType name
    work_type = sf_record.get("WorkType")
    if work_type and isinstance(work_type, dict):
        mapped["category"] = work_type.get("Name", "general")
    else:
        mapped["category"] = "general"

    # Extract nested ServiceTerritory
    territory = sf_record.get("ServiceTerritory")
    if territory and isinstance(territory, dict):
        mapped["zone_name"] = territory.get("Name")

    # Extract nested Account
    account = sf_record.get("Account")
    if account and isinstance(account, dict):
        mapped["account_name"] = account.get("Name")

    # Convert duration to minutes (Salesforce may use hours)
    duration_type = sf_record.get("DurationType", "Minutes")
    if mapped.get("estimated_duration_min") and duration_type == "Hours":
        mapped["estimated_duration_min"] = mapped["estimated_duration_min"] * 60

    # Add sync metadata
    mapped["sync_source"] = "salesforce"
    mapped["synced_at"] = datetime.now(timezone.utc).isoformat()

    return mapped


def map_line_item(sf_record: dict[str, Any]) -> dict[str, Any]:
    """Transform a Salesforce WorkOrderLineItem record."""
    return {
        "salesforce_id": sf_record.get("Id"),
        "work_order_salesforce_id": sf_record.get("WorkOrderId"),
        "line_item_number": sf_record.get("LineItemNumber"),
        "subject": sf_record.get("Subject"),
        "status": sf_record.get("Status"),
        "duration": sf_record.get("Duration"),
        "duration_type": sf_record.get("DurationType"),
        "start_date": sf_record.get("StartDate"),
        "end_date": sf_record.get("EndDate"),
        "created_at": sf_record.get("CreatedDate"),
        "updated_at": sf_record.get("LastModifiedDate"),
        "sync_source": "salesforce",
        "synced_at": datetime.now(timezone.utc).isoformat(),
    }


# ---------------------------------------------------------------------------
# Query Salesforce
# ---------------------------------------------------------------------------
@retry_with_backoff()
def fetch_work_orders(
    sf: Salesforce, since: Optional[str] = None
) -> list[dict[str, Any]]:
    """Fetch work orders from Salesforce, optionally filtered by date."""
    fields_str = ", ".join(WORK_ORDER_FIELDS)
    query = f"SELECT {fields_str} FROM WorkOrder"

    if since:
        query += f" WHERE LastModifiedDate >= {since}"

    query += " ORDER BY LastModifiedDate ASC"

    logger.info("Executing SOQL query: %s", query[:200] + "...")

    results = sf.query_all(query)
    records = results.get("records", [])

    logger.info("Fetched %d work order records from Salesforce.", len(records))
    return records


@retry_with_backoff()
def fetch_line_items(sf: Salesforce, work_order_ids: list[str]) -> list[dict[str, Any]]:
    """Fetch line items for the given work order IDs."""
    if not work_order_ids:
        return []

    fields_str = ", ".join(LINE_ITEM_FIELDS)

    # Salesforce has a limit on IN clause, process in chunks
    all_records = []
    chunk_size = 200

    for i in range(0, len(work_order_ids), chunk_size):
        chunk = work_order_ids[i : i + chunk_size]
        ids_str = "', '".join(chunk)
        query = (
            f"SELECT {fields_str} FROM WorkOrderLineItem "
            f"WHERE WorkOrderId IN ('{ids_str}') "
            f"ORDER BY WorkOrderId, LineItemNumber"
        )

        results = sf.query_all(query)
        all_records.extend(results.get("records", []))

    logger.info("Fetched %d line item records from Salesforce.", len(all_records))
    return all_records


# ---------------------------------------------------------------------------
# MongoDB upsert
# ---------------------------------------------------------------------------
def upsert_work_orders(
    db, records: list[dict[str, Any]], batch_size: int = DEFAULT_BATCH_SIZE
) -> dict[str, int]:
    """Upsert work order records into MongoDB using bulk operations."""
    collection = db["work_orders"]
    stats = {"upserted": 0, "modified": 0, "errors": 0}

    if not records:
        logger.info("No work order records to upsert.")
        return stats

    # Ensure index on salesforce_id for efficient upserts
    collection.create_index("salesforce_id", unique=True, background=True)

    for i in range(0, len(records), batch_size):
        batch = records[i : i + batch_size]
        operations = []

        for record in batch:
            mapped = map_work_order(record)
            operations.append(
                UpdateOne(
                    {"salesforce_id": mapped["salesforce_id"]},
                    {"$set": mapped},
                    upsert=True,
                )
            )

        try:
            result = collection.bulk_write(operations, ordered=False)
            stats["upserted"] += result.upserted_count
            stats["modified"] += result.modified_count
            logger.debug(
                "Batch %d-%d: upserted=%d, modified=%d",
                i,
                i + len(batch),
                result.upserted_count,
                result.modified_count,
            )
        except BulkWriteError as bwe:
            write_errors = bwe.details.get("writeErrors", [])
            stats["errors"] += len(write_errors)
            logger.error(
                "Bulk write error in batch %d-%d: %d errors. First error: %s",
                i,
                i + len(batch),
                len(write_errors),
                write_errors[0] if write_errors else "unknown",
            )

    logger.info(
        "Work order upsert complete: upserted=%d, modified=%d, errors=%d",
        stats["upserted"],
        stats["modified"],
        stats["errors"],
    )
    return stats


def upsert_line_items(
    db, records: list[dict[str, Any]], batch_size: int = DEFAULT_BATCH_SIZE
) -> dict[str, int]:
    """Upsert work order line item records into MongoDB."""
    collection = db["work_order_line_items"]
    stats = {"upserted": 0, "modified": 0, "errors": 0}

    if not records:
        logger.info("No line item records to upsert.")
        return stats

    collection.create_index("salesforce_id", unique=True, background=True)
    collection.create_index("work_order_salesforce_id", background=True)

    for i in range(0, len(records), batch_size):
        batch = records[i : i + batch_size]
        operations = []

        for record in batch:
            mapped = map_line_item(record)
            operations.append(
                UpdateOne(
                    {"salesforce_id": mapped["salesforce_id"]},
                    {"$set": mapped},
                    upsert=True,
                )
            )

        try:
            result = collection.bulk_write(operations, ordered=False)
            stats["upserted"] += result.upserted_count
            stats["modified"] += result.modified_count
        except BulkWriteError as bwe:
            write_errors = bwe.details.get("writeErrors", [])
            stats["errors"] += len(write_errors)
            logger.error("Line item bulk write error: %d errors", len(write_errors))

    logger.info(
        "Line item upsert complete: upserted=%d, modified=%d, errors=%d",
        stats["upserted"],
        stats["modified"],
        stats["errors"],
    )
    return stats


# ---------------------------------------------------------------------------
# Sync state management
# ---------------------------------------------------------------------------
def get_last_sync_timestamp(db) -> Optional[str]:
    """Retrieve the last successful sync timestamp from MongoDB."""
    meta = db["sync_metadata"].find_one({"_id": "salesforce_work_orders"})
    if meta:
        return meta.get("last_sync_timestamp")
    return None


def save_sync_timestamp(db, timestamp: str, stats: dict) -> None:
    """Save the current sync timestamp and statistics."""
    db["sync_metadata"].update_one(
        {"_id": "salesforce_work_orders"},
        {
            "$set": {
                "last_sync_timestamp": timestamp,
                "last_sync_at": datetime.now(timezone.utc).isoformat(),
                "last_sync_stats": stats,
            }
        },
        upsert=True,
    )
    logger.info("Saved sync timestamp: %s", timestamp)


# ---------------------------------------------------------------------------
# Main sync orchestration
# ---------------------------------------------------------------------------
def run_sync(full_sync: bool = False, since: Optional[str] = None) -> dict[str, Any]:
    """
    Execute the Salesforce to MongoDB work order sync.

    Args:
        full_sync: If True, fetch all records regardless of last sync time.
        since: ISO 8601 timestamp to use as the incremental sync boundary.
               Overrides the stored last sync timestamp.

    Returns:
        Dictionary containing sync statistics.
    """
    start_time = time.time()
    sync_timestamp = datetime.now(timezone.utc).isoformat()

    logger.info(
        "Starting Salesforce work order sync (mode: %s)",
        "full" if full_sync else "incremental",
    )

    # Connect to services
    sf = connect_salesforce()
    mongo_client, db = connect_mongodb()

    try:
        # Determine sync boundary
        if full_sync:
            since_filter = None
            logger.info("Full sync: fetching all work orders.")
        elif since:
            since_filter = since
            logger.info("Incremental sync from provided timestamp: %s", since_filter)
        else:
            since_filter = get_last_sync_timestamp(db)
            if since_filter:
                logger.info(
                    "Incremental sync from last stored timestamp: %s", since_filter
                )
            else:
                logger.info("No previous sync found. Falling back to 30-day lookback.")
                since_filter = (
                    datetime.now(timezone.utc) - timedelta(days=30)
                ).strftime("%Y-%m-%dT%H:%M:%SZ")

        # Fetch work orders from Salesforce
        sf_work_orders = fetch_work_orders(sf, since=since_filter)

        # Fetch associated line items
        work_order_ids = [r["Id"] for r in sf_work_orders if r.get("Id")]
        sf_line_items = fetch_line_items(sf, work_order_ids)

        # Upsert into MongoDB
        batch_size = int(os.environ.get("SYNC_BATCH_SIZE", DEFAULT_BATCH_SIZE))
        wo_stats = upsert_work_orders(db, sf_work_orders, batch_size=batch_size)
        li_stats = upsert_line_items(db, sf_line_items, batch_size=batch_size)

        # Save sync state
        combined_stats = {
            "work_orders": wo_stats,
            "line_items": li_stats,
            "source_records_fetched": len(sf_work_orders),
            "line_items_fetched": len(sf_line_items),
            "duration_seconds": round(time.time() - start_time, 2),
        }

        save_sync_timestamp(db, sync_timestamp, combined_stats)

        logger.info(
            "Sync completed successfully in %.2f seconds. "
            "Work orders: %d fetched, %d upserted, %d modified. "
            "Line items: %d fetched, %d upserted, %d modified.",
            combined_stats["duration_seconds"],
            len(sf_work_orders),
            wo_stats["upserted"],
            wo_stats["modified"],
            len(sf_line_items),
            li_stats["upserted"],
            li_stats["modified"],
        )

        return combined_stats

    except Exception:
        logger.exception("Sync failed with an unhandled exception.")
        raise

    finally:
        mongo_client.close()
        logger.info("MongoDB connection closed.")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Sync work orders from Salesforce to MongoDB"
    )
    parser.add_argument(
        "--full",
        action="store_true",
        help="Perform a full sync instead of incremental",
    )
    parser.add_argument(
        "--since",
        type=str,
        default=None,
        help="ISO 8601 timestamp for incremental sync boundary (e.g., 2025-01-01T00:00:00Z)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug-level logging",
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        stats = run_sync(full_sync=args.full, since=args.since)
        total_errors = stats["work_orders"]["errors"] + stats["line_items"]["errors"]
        if total_errors > 0:
            logger.warning("Sync completed with %d errors.", total_errors)
            sys.exit(2)
        sys.exit(0)
    except Exception:
        logger.exception("Sync failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
