#!/usr/bin/env python3
"""
Snowflake SQL Generator Script
Generates INSERT statements for Snowflake RAW schema tables
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path


def escape_sql_string(value):
    """Escape string for SQL"""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def format_variant_json(data):
    """Format Python dict/list as Snowflake VARIANT JSON string"""
    if data is None:
        return "NULL"
    json_str = json.dumps(data, separators=(",", ":"))
    # Escape single quotes for SQL
    json_str = json_str.replace("'", "''")
    return f"PARSE_JSON('{json_str}')"


def generate_properties_inserts(properties):
    """Generate INSERT statements for properties table"""
    sql_lines = []
    sql_lines.append("-- Properties INSERT statements")
    sql_lines.append("-- Generated: " + datetime.now().isoformat())
    sql_lines.append("")

    for prop in properties:
        address = prop.get("address", {})
        location = prop.get("location", {})

        insert = f"""INSERT INTO RAW.PROPERTIES (
    PROPERTY_ID,
    STREET,
    CITY,
    STATE,
    ZIP_CODE,
    LOCATION_LAT,
    LOCATION_LNG,
    LOCATION_GEOJSON,
    PROPERTY_TYPE,
    SQUARE_FOOTAGE,
    ZONE,
    ZONE_NAME,
    CREATED_AT
) VALUES (
    {escape_sql_string(prop.get("property_id"))},
    {escape_sql_string(address.get("street"))},
    {escape_sql_string(address.get("city"))},
    {escape_sql_string(address.get("state"))},
    {escape_sql_string(address.get("zip_code"))},
    {location.get("coordinates", [None, None])[1]},
    {location.get("coordinates", [None, None])[0]},
    {format_variant_json(location)},
    {escape_sql_string(prop.get("property_type"))},
    {prop.get("square_footage", "NULL")},
    {escape_sql_string(prop.get("zone"))},
    {escape_sql_string(prop.get("zone_name"))},
    {escape_sql_string(prop.get("created_at"))}
);"""
        sql_lines.append(insert)
        sql_lines.append("")

    return sql_lines


def generate_technicians_inserts(technicians):
    """Generate INSERT statements for technicians table"""
    sql_lines = []
    sql_lines.append("-- Technicians INSERT statements")
    sql_lines.append("-- Generated: " + datetime.now().isoformat())
    sql_lines.append("")

    for tech in technicians:
        home_base = tech.get("home_base", {})
        address = home_base.get("address", {})
        location = home_base.get("location", {})

        insert = f"""INSERT INTO RAW.TECHNICIANS (
    TECHNICIAN_ID,
    NAME,
    EMAIL,
    PHONE,
    HOME_BASE_STREET,
    HOME_BASE_CITY,
    HOME_BASE_STATE,
    HOME_BASE_ZIP_CODE,
    HOME_BASE_LAT,
    HOME_BASE_LNG,
    HOME_BASE_GEOJSON,
    SKILLS,
    MAX_DAILY_HOURS,
    MAX_DAILY_DISTANCE_MILES,
    HOURLY_RATE,
    PREFERRED_ZONES,
    ACTIVE,
    CREATED_AT
) VALUES (
    {escape_sql_string(tech.get("technician_id"))},
    {escape_sql_string(tech.get("name"))},
    {escape_sql_string(tech.get("email"))},
    {escape_sql_string(tech.get("phone"))},
    {escape_sql_string(address.get("street"))},
    {escape_sql_string(address.get("city"))},
    {escape_sql_string(address.get("state"))},
    {escape_sql_string(address.get("zip_code"))},
    {location.get("coordinates", [None, None])[1]},
    {location.get("coordinates", [None, None])[0]},
    {format_variant_json(location)},
    {format_variant_json(tech.get("skills"))},
    {tech.get("max_daily_hours", "NULL")},
    {tech.get("max_daily_distance_miles", "NULL")},
    {tech.get("hourly_rate", "NULL")},
    {format_variant_json(tech.get("preferred_zones"))},
    {str(tech.get("active", True)).upper()},
    {escape_sql_string(tech.get("created_at"))}
);"""
        sql_lines.append(insert)
        sql_lines.append("")

    return sql_lines


def generate_work_orders_inserts(work_orders):
    """Generate INSERT statements for work_orders table"""
    sql_lines = []
    sql_lines.append("-- Work Orders INSERT statements")
    sql_lines.append("-- Generated: " + datetime.now().isoformat())
    sql_lines.append("")

    for wo in work_orders:
        address = wo.get("property_address", {})
        location = wo.get("location", {})

        insert = f"""INSERT INTO RAW.WORK_ORDERS (
    WORK_ORDER_ID,
    PROPERTY_ID,
    PROPERTY_STREET,
    PROPERTY_CITY,
    PROPERTY_STATE,
    PROPERTY_ZIP_CODE,
    LOCATION_LAT,
    LOCATION_LNG,
    LOCATION_GEOJSON,
    ZONE,
    WORK_ORDER_TYPE,
    CATEGORY,
    REQUIRED_SKILLS,
    PRIORITY,
    STATUS,
    SCHEDULED_DATE,
    TIME_WINDOW_START,
    TIME_WINDOW_END,
    ESTIMATED_DURATION_MINUTES,
    DESCRIPTION,
    CREATED_AT,
    UPDATED_AT
) VALUES (
    {escape_sql_string(wo.get("work_order_id"))},
    {escape_sql_string(wo.get("property_id"))},
    {escape_sql_string(address.get("street"))},
    {escape_sql_string(address.get("city"))},
    {escape_sql_string(address.get("state"))},
    {escape_sql_string(address.get("zip_code"))},
    {location.get("coordinates", [None, None])[1]},
    {location.get("coordinates", [None, None])[0]},
    {format_variant_json(location)},
    {escape_sql_string(wo.get("zone"))},
    {escape_sql_string(wo.get("work_order_type"))},
    {escape_sql_string(wo.get("category"))},
    {format_variant_json(wo.get("required_skills"))},
    {escape_sql_string(wo.get("priority"))},
    {escape_sql_string(wo.get("status"))},
    {escape_sql_string(wo.get("scheduled_date"))},
    {escape_sql_string(wo.get("time_window_start"))},
    {escape_sql_string(wo.get("time_window_end"))},
    {wo.get("estimated_duration_minutes", "NULL")},
    {escape_sql_string(wo.get("description"))},
    {escape_sql_string(wo.get("created_at"))},
    {escape_sql_string(wo.get("updated_at"))}
);"""
        sql_lines.append(insert)
        sql_lines.append("")

    return sql_lines


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


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(
        description="Generate Snowflake INSERT statements from JSON data"
    )
    parser.add_argument(
        "--data-dir",
        help="Directory containing JSON files (default: ../data/sample/)",
        default=None,
    )
    parser.add_argument(
        "--output",
        help="Output SQL file path (default: ../data/snowflake/seed/generated_inserts.sql)",
        default=None,
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

    # Determine output file
    if args.output:
        output_file = Path(args.output)
    else:
        output_file = (
            Path(__file__).parent.parent
            / "data"
            / "snowflake"
            / "seed"
            / "generated_inserts.sql"
        )

    # Create output directory if it doesn't exist
    output_file.parent.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("Snowflake SQL Generator")
    print("=" * 70)
    print(f"Data directory: {data_dir}")
    print(f"Output file: {output_file}")
    print()

    all_sql_lines = []

    # Header
    all_sql_lines.append("-- Snowflake INSERT Statements")
    all_sql_lines.append("-- Auto-generated from JSON data")
    all_sql_lines.append(f"-- Generated: {datetime.now().isoformat()}")
    all_sql_lines.append("-- Database: ROUTE_OPTIMIZATION")
    all_sql_lines.append("-- Schema: RAW")
    all_sql_lines.append("")
    all_sql_lines.append("USE DATABASE ROUTE_OPTIMIZATION;")
    all_sql_lines.append("USE SCHEMA RAW;")
    all_sql_lines.append("")
    all_sql_lines.append("-- Disable auto-commit for batch insert")
    all_sql_lines.append("BEGIN TRANSACTION;")
    all_sql_lines.append("")

    # Generate properties inserts
    print("Loading properties...")
    properties_file = data_dir / "properties.json"
    properties = load_json_file(properties_file)
    if properties:
        print(f"  - Generating {len(properties)} INSERT statements")
        all_sql_lines.extend(generate_properties_inserts(properties))
    else:
        print("  - WARNING: Skipping properties (file not found or invalid)")

    all_sql_lines.append("")

    # Generate technicians inserts
    print("Loading technicians...")
    technicians_file = data_dir / "technicians.json"
    technicians = load_json_file(technicians_file)
    if technicians:
        print(f"  - Generating {len(technicians)} INSERT statements")
        all_sql_lines.extend(generate_technicians_inserts(technicians))
    else:
        print("  - WARNING: Skipping technicians (file not found or invalid)")

    all_sql_lines.append("")

    # Generate work orders inserts
    print("Loading work orders...")
    work_orders_file = data_dir / "work_orders.json"
    work_orders = load_json_file(work_orders_file)
    if work_orders:
        print(f"  - Generating {len(work_orders)} INSERT statements")
        all_sql_lines.extend(generate_work_orders_inserts(work_orders))
    else:
        print("  - WARNING: Skipping work orders (file not found or invalid)")

    # Footer
    all_sql_lines.append("")
    all_sql_lines.append("-- Commit transaction")
    all_sql_lines.append("COMMIT;")
    all_sql_lines.append("")
    all_sql_lines.append("-- Verify row counts")
    all_sql_lines.append(
        "SELECT 'PROPERTIES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM RAW.PROPERTIES"
    )
    all_sql_lines.append("UNION ALL")
    all_sql_lines.append("SELECT 'TECHNICIANS', COUNT(*) FROM RAW.TECHNICIANS")
    all_sql_lines.append("UNION ALL")
    all_sql_lines.append("SELECT 'WORK_ORDERS', COUNT(*) FROM RAW.WORK_ORDERS;")

    # Write to file
    print(f"\nWriting SQL to {output_file}...")
    with open(output_file, "w") as f:
        f.write("\n".join(all_sql_lines))

    print("\n" + "=" * 70)
    print("GENERATION COMPLETE")
    print("=" * 70)
    print(
        f"Total SQL statements: {len([line for line in all_sql_lines if line.startswith('INSERT')])}"
    )
    print(f"Output file: {output_file}")
    print(f"File size: {output_file.stat().st_size} bytes")
    print("=" * 70)
    print("\nTo load into Snowflake:")
    print(f"  snowsql -f {output_file}")
    print("  or copy/paste into Snowflake web UI")


if __name__ == "__main__":
    main()
