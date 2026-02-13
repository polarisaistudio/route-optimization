#!/usr/bin/env python3
"""
MongoDB Data Loader Script
Loads generated JSON data into MongoDB collections with proper indexing
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from pymongo import ASCENDING, GEOSPHERE, MongoClient
from pymongo.errors import ConnectionFailure, OperationFailure

# Load environment variables
load_dotenv()


def get_mongo_client(uri=None):
    """Create and return MongoDB client"""
    if not uri:
        uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017/")

    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=5000)
        # Test connection
        client.admin.command("ping")
        return client
    except ConnectionFailure as e:
        print(f"ERROR: Could not connect to MongoDB: {e}")
        sys.exit(1)


def create_indexes(db):
    """Create indexes for all collections"""
    print("\nCreating indexes...")

    # Properties collection indexes
    try:
        db.properties.create_index([("property_id", ASCENDING)], unique=True)
        db.properties.create_index([("location", GEOSPHERE)])
        db.properties.create_index([("zone", ASCENDING)])
        db.properties.create_index([("property_type", ASCENDING)])
        print("  - Properties indexes created")
    except OperationFailure as e:
        print(f"  - Warning: Could not create properties indexes: {e}")

    # Technicians collection indexes
    try:
        db.technicians.create_index([("technician_id", ASCENDING)], unique=True)
        db.technicians.create_index([("home_base.location", GEOSPHERE)])
        db.technicians.create_index([("skills", ASCENDING)])
        db.technicians.create_index([("active", ASCENDING)])
        db.technicians.create_index([("preferred_zones", ASCENDING)])
        print("  - Technicians indexes created")
    except OperationFailure as e:
        print(f"  - Warning: Could not create technicians indexes: {e}")

    # Work orders collection indexes
    try:
        db.work_orders.create_index([("work_order_id", ASCENDING)], unique=True)
        db.work_orders.create_index([("property_id", ASCENDING)])
        db.work_orders.create_index([("location", GEOSPHERE)])
        db.work_orders.create_index([("zone", ASCENDING)])
        db.work_orders.create_index([("status", ASCENDING)])
        db.work_orders.create_index([("priority", ASCENDING)])
        db.work_orders.create_index([("scheduled_date", ASCENDING)])
        db.work_orders.create_index([("category", ASCENDING)])
        db.work_orders.create_index([("required_skills", ASCENDING)])
        print("  - Work orders indexes created")
    except OperationFailure as e:
        print(f"  - Warning: Could not create work_orders indexes: {e}")

    # Routes collection indexes (for optimization results)
    try:
        db.routes.create_index([("route_id", ASCENDING)])
        db.routes.create_index([("technician_id", ASCENDING)])
        db.routes.create_index([("scheduled_date", ASCENDING)])
        db.routes.create_index([("algorithm", ASCENDING)])
        db.routes.create_index([("created_at", ASCENDING)])
        print("  - Routes indexes created")
    except OperationFailure as e:
        print(f"  - Warning: Could not create routes indexes: {e}")

    # Optimization results collection indexes
    try:
        db.optimization_results.create_index([("run_id", ASCENDING)])
        db.optimization_results.create_index([("algorithm", ASCENDING)])
        db.optimization_results.create_index([("scheduled_date", ASCENDING)])
        db.optimization_results.create_index([("created_at", ASCENDING)])
        print("  - Optimization results indexes created")
    except OperationFailure as e:
        print(f"  - Warning: Could not create optimization_results indexes: {e}")


def load_json_file(file_path):
    """Load data from JSON file"""
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
        return data
    except FileNotFoundError:
        print(f"ERROR: File not found: {file_path}")
        return None
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {file_path}: {e}")
        return None


def upsert_properties(collection, properties):
    """Upsert properties data"""
    print(f"\nUpserting {len(properties)} properties...")

    inserted = 0
    updated = 0

    for prop in properties:
        result = collection.update_one(
            {"property_id": prop["property_id"]}, {"$set": prop}, upsert=True
        )
        if result.upserted_id:
            inserted += 1
        elif result.modified_count > 0:
            updated += 1

    print(f"  - Inserted: {inserted}")
    print(f"  - Updated: {updated}")
    print(f"  - Total in collection: {collection.count_documents({})}")

    return inserted, updated


def upsert_technicians(collection, technicians):
    """Upsert technicians data"""
    print(f"\nUpserting {len(technicians)} technicians...")

    inserted = 0
    updated = 0

    for tech in technicians:
        result = collection.update_one(
            {"technician_id": tech["technician_id"]}, {"$set": tech}, upsert=True
        )
        if result.upserted_id:
            inserted += 1
        elif result.modified_count > 0:
            updated += 1

    print(f"  - Inserted: {inserted}")
    print(f"  - Updated: {updated}")
    print(f"  - Total in collection: {collection.count_documents({})}")

    return inserted, updated


def upsert_work_orders(collection, work_orders):
    """Upsert work orders data"""
    print(f"\nUpserting {len(work_orders)} work orders...")

    inserted = 0
    updated = 0

    for wo in work_orders:
        result = collection.update_one(
            {"work_order_id": wo["work_order_id"]}, {"$set": wo}, upsert=True
        )
        if result.upserted_id:
            inserted += 1
        elif result.modified_count > 0:
            updated += 1

    print(f"  - Inserted: {inserted}")
    print(f"  - Updated: {updated}")
    print(f"  - Total in collection: {collection.count_documents({})}")

    return inserted, updated


def clear_collections(db, collections):
    """Drop specified collections"""
    print("\nClearing collections...")
    for coll_name in collections:
        result = db[coll_name].delete_many({})
        print(f"  - Deleted {result.deleted_count} documents from {coll_name}")


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(description="Load generated data into MongoDB")
    parser.add_argument(
        "--uri",
        help="MongoDB connection URI (default: from MONGODB_URI env var or mongodb://localhost:27017/)",
        default=None,
    )
    parser.add_argument(
        "--db",
        help="Database name (default: route_optimization)",
        default="route_optimization",
    )
    parser.add_argument(
        "--data-dir",
        help="Directory containing JSON files (default: ../data/sample/)",
        default=None,
    )
    parser.add_argument(
        "--clear", action="store_true", help="Clear collections before loading"
    )

    args = parser.parse_args()

    # Determine data directory
    if args.data_dir:
        data_dir = Path(args.data_dir)
    else:
        data_dir = Path(__file__).parent.parent / "data" / "sample"

    if not data_dir.exists():
        print(f"ERROR: Data directory does not exist: {data_dir}")
        sys.exit(1)

    print("=" * 70)
    print("MongoDB Data Loader")
    print("=" * 70)
    print(f"Data directory: {data_dir}")
    print(f"Database: {args.db}")

    # Connect to MongoDB
    print("\nConnecting to MongoDB...")
    client = get_mongo_client(args.uri)
    db = client[args.db]
    print(f"  - Connected to database: {args.db}")

    # Clear collections if requested
    if args.clear:
        clear_collections(db, ["properties", "technicians", "work_orders"])

    # Create indexes
    create_indexes(db)

    # Load and upsert properties
    properties_file = data_dir / "properties.json"
    properties = load_json_file(properties_file)
    if properties:
        upsert_properties(db.properties, properties)
    else:
        print(f"WARNING: Skipping properties (file not found or invalid)")

    # Load and upsert technicians
    technicians_file = data_dir / "technicians.json"
    technicians = load_json_file(technicians_file)
    if technicians:
        upsert_technicians(db.technicians, technicians)
    else:
        print(f"WARNING: Skipping technicians (file not found or invalid)")

    # Load and upsert work orders
    work_orders_file = data_dir / "work_orders.json"
    work_orders = load_json_file(work_orders_file)
    if work_orders:
        upsert_work_orders(db.work_orders, work_orders)
    else:
        print(f"WARNING: Skipping work orders (file not found or invalid)")

    # Final summary
    print("\n" + "=" * 70)
    print("LOAD SUMMARY")
    print("=" * 70)
    print(f"Database: {args.db}")
    print(f"Collections:")
    print(f"  - properties: {db.properties.count_documents({})} documents")
    print(f"  - technicians: {db.technicians.count_documents({})} documents")
    print(f"  - work_orders: {db.work_orders.count_documents({})} documents")
    print(f"  - routes: {db.routes.count_documents({})} documents")
    print(
        f"  - optimization_results: {db.optimization_results.count_documents({})} documents"
    )
    print("=" * 70)
    print("\nData load complete!")

    client.close()


if __name__ == "__main__":
    main()
