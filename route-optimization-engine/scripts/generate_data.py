#!/usr/bin/env python3
"""
Data Generation Script for Route Optimization Engine
Generates realistic simulated data for Denver, CO metropolitan area
"""

import json
import os
import random
from datetime import datetime, timedelta
from pathlib import Path

from faker import Faker

# Initialize Faker with US locale
fake = Faker("en_US")
random.seed(42)  # For reproducibility

# Denver metro area boundaries
DENVER_LAT_MIN = 39.60
DENVER_LAT_MAX = 39.85
DENVER_LNG_MIN = -105.10
DENVER_LNG_MAX = -104.80

# Denver street names for realistic addresses
DENVER_STREETS = [
    "Colfax Ave",
    "Broadway",
    "Colorado Blvd",
    "Federal Blvd",
    "Sheridan Blvd",
    "Wadsworth Blvd",
    "Santa Fe Dr",
    "Speer Blvd",
    "6th Ave",
    "Alameda Ave",
    "Evans Ave",
    "Mississippi Ave",
    "Yale Ave",
    "Belleview Ave",
    "Hampden Ave",
    "Quincy Ave",
    "Arapahoe Rd",
    "Dry Creek Rd",
    "County Line Rd",
    "Bowles Ave",
    "Morrison Rd",
    "Jewell Ave",
    "Kentucky Ave",
    "Tennessee Ave",
    "Florida Ave",
    "Exposition Ave",
    "8th Ave",
    "12th Ave",
    "17th Ave",
    "20th Ave",
    "23rd Ave",
    "26th Ave",
    "32nd Ave",
    "38th Ave",
    "44th Ave",
    "Monaco Pkwy",
    "Quebec St",
    "Havana St",
    "Peoria St",
    "Chambers Rd",
    "Downing St",
    "Washington St",
    "Clarkson St",
    "Emerson St",
    "Franklin St",
    "Garfield St",
    "High St",
    "Irving St",
    "Julian St",
    "King St",
]

# Zones based on Denver geography
ZONES = {
    "Zone-A": {
        "name": "Downtown",
        "lat_range": (39.72, 39.76),
        "lng_range": (-105.02, -104.97),
    },
    "Zone-B": {
        "name": "North Denver",
        "lat_range": (39.76, 39.85),
        "lng_range": (-105.05, -104.90),
    },
    "Zone-C": {
        "name": "South Denver",
        "lat_range": (39.60, 39.72),
        "lng_range": (-105.00, -104.85),
    },
    "Zone-D": {
        "name": "West Denver",
        "lat_range": (39.68, 39.78),
        "lng_range": (-105.10, -105.02),
    },
    "Zone-E": {
        "name": "East Denver",
        "lat_range": (39.68, 39.78),
        "lng_range": (-104.90, -104.80),
    },
}

PROPERTY_TYPES = {"residential": 0.60, "commercial": 0.30, "industrial": 0.10}

SKILLS = ["hvac", "plumbing", "electrical", "general", "inspection"]

WORK_ORDER_CATEGORIES = {
    "hvac": ["HVAC Repair", "HVAC Maintenance", "HVAC Installation"],
    "plumbing": ["Plumbing Repair", "Plumbing Maintenance", "Drain Cleaning"],
    "electrical": ["Electrical Repair", "Electrical Inspection", "Wiring"],
    "general": ["General Maintenance", "Preventive Maintenance", "Safety Check"],
    "inspection": ["Property Inspection", "Compliance Inspection", "Final Inspection"],
}

PRIORITY_DISTRIBUTION = {"emergency": 0.05, "high": 0.15, "medium": 0.50, "low": 0.30}


def get_random_coordinates(zone_id=None):
    """Generate random coordinates within Denver metro or specific zone"""
    if zone_id and zone_id in ZONES:
        zone = ZONES[zone_id]
        lat = random.uniform(zone["lat_range"][0], zone["lat_range"][1])
        lng = random.uniform(zone["lng_range"][0], zone["lng_range"][1])
    else:
        lat = random.uniform(DENVER_LAT_MIN, DENVER_LAT_MAX)
        lng = random.uniform(DENVER_LNG_MIN, DENVER_LNG_MAX)
    return round(lat, 6), round(lng, 6)


def get_zone_from_coordinates(lat, lng):
    """Determine zone based on coordinates"""
    for zone_id, zone_info in ZONES.items():
        lat_range = zone_info["lat_range"]
        lng_range = zone_info["lng_range"]
        if lat_range[0] <= lat <= lat_range[1] and lng_range[0] <= lng <= lng_range[1]:
            return zone_id
    # Default to closest zone if not in any zone
    return "Zone-A"


def generate_denver_address(lat, lng):
    """Generate a realistic Denver address"""
    street_num = random.randint(100, 9999)
    street_name = random.choice(DENVER_STREETS)

    # Determine general area for zip code
    if lat > 39.75:
        zip_code = random.choice(["80221", "80216", "80238", "80249", "80239"])
    elif lat < 39.68:
        zip_code = random.choice(["80110", "80120", "80122", "80111", "80113"])
    elif lng < -105.00:
        zip_code = random.choice(["80214", "80215", "80226", "80228", "80227"])
    elif lng > -104.90:
        zip_code = random.choice(["80010", "80011", "80012", "80230", "80231"])
    else:
        zip_code = random.choice(
            ["80202", "80203", "80204", "80205", "80206", "80218", "80220"]
        )

    return {
        "street": f"{street_num} {street_name}",
        "city": "Denver",
        "state": "CO",
        "zip_code": zip_code,
    }


def generate_properties(count=50):
    """Generate property data"""
    properties = []

    # Distribute properties across zones
    zone_list = list(ZONES.keys())
    properties_per_zone = count // len(zone_list)

    property_id = 1
    for zone_id in zone_list:
        for _ in range(properties_per_zone):
            lat, lng = get_random_coordinates(zone_id)
            address = generate_denver_address(lat, lng)

            # Determine property type based on distribution
            rand = random.random()
            if rand < PROPERTY_TYPES["residential"]:
                prop_type = "residential"
                sqft = random.randint(800, 3500)
            elif rand < PROPERTY_TYPES["residential"] + PROPERTY_TYPES["commercial"]:
                prop_type = "commercial"
                sqft = random.randint(2000, 20000)
            else:
                prop_type = "industrial"
                sqft = random.randint(5000, 50000)

            property_data = {
                "property_id": f"PROP-{property_id:04d}",
                "address": address,
                "location": {"type": "Point", "coordinates": [lng, lat]},
                "property_type": prop_type,
                "square_footage": sqft,
                "zone": zone_id,
                "zone_name": ZONES[zone_id]["name"],
                "created_at": datetime.now().isoformat(),
            }
            properties.append(property_data)
            property_id += 1

    # Add remaining properties to random zones
    while len(properties) < count:
        zone_id = random.choice(zone_list)
        lat, lng = get_random_coordinates(zone_id)
        address = generate_denver_address(lat, lng)

        rand = random.random()
        if rand < PROPERTY_TYPES["residential"]:
            prop_type = "residential"
            sqft = random.randint(800, 3500)
        elif rand < PROPERTY_TYPES["residential"] + PROPERTY_TYPES["commercial"]:
            prop_type = "commercial"
            sqft = random.randint(2000, 20000)
        else:
            prop_type = "industrial"
            sqft = random.randint(5000, 50000)

        property_data = {
            "property_id": f"PROP-{property_id:04d}",
            "address": address,
            "location": {"type": "Point", "coordinates": [lng, lat]},
            "property_type": prop_type,
            "square_footage": sqft,
            "zone": zone_id,
            "zone_name": ZONES[zone_id]["name"],
            "created_at": datetime.now().isoformat(),
        }
        properties.append(property_data)
        property_id += 1

    return properties


def generate_technicians(count=10):
    """Generate technician data"""
    technicians = []
    zone_list = list(ZONES.keys())

    for i in range(1, count + 1):
        # Generate home base in suburbs (slightly outside main zones)
        lat = random.uniform(DENVER_LAT_MIN, DENVER_LAT_MAX)
        lng = random.uniform(DENVER_LNG_MIN, DENVER_LNG_MAX)
        address = generate_denver_address(lat, lng)

        # Each tech has 2-4 skills, always including 'general'
        num_skills = random.randint(2, 4)
        tech_skills = ["general"]
        other_skills = [s for s in SKILLS if s != "general"]
        tech_skills.extend(random.sample(other_skills, num_skills - 1))

        # Zone preferences (1-2 zones)
        preferred_zones = random.sample(zone_list, random.randint(1, 2))

        technician_data = {
            "technician_id": f"TECH-{i:03d}",
            "name": fake.name(),
            "email": fake.email(),
            "phone": fake.phone_number(),
            "home_base": {
                "address": address,
                "location": {"type": "Point", "coordinates": [lng, lat]},
            },
            "skills": tech_skills,
            "max_daily_hours": random.choice([8, 8.5, 9, 9.5, 10]),
            "max_daily_distance_miles": random.randint(80, 120),
            "hourly_rate": round(random.uniform(25, 55), 2),
            "preferred_zones": preferred_zones,
            "active": True,
            "created_at": datetime.now().isoformat(),
        }
        technicians.append(technician_data)

    return technicians


def generate_work_orders(count=100, properties=None):
    """Generate work order data"""
    if not properties:
        raise ValueError("Properties list is required")

    work_orders = []
    base_date = datetime.now().replace(hour=8, minute=0, second=0, microsecond=0)

    # Priority distribution
    priorities = []
    for priority, weight in PRIORITY_DISTRIBUTION.items():
        priorities.extend([priority] * int(count * weight))
    # Fill remaining to reach exact count
    while len(priorities) < count:
        priorities.append("medium")
    random.shuffle(priorities)

    for i in range(1, count + 1):
        # Random property
        property_data = random.choice(properties)

        # Random skill category
        skill_category = random.choice(SKILLS)
        work_order_type = random.choice(WORK_ORDER_CATEGORIES[skill_category])

        # Priority
        priority = priorities[i - 1] if i - 1 < len(priorities) else "medium"

        # Time window (business hours 8am-5pm)
        window_start_hour = random.randint(8, 14)
        window_duration = random.randint(1, 4)  # 1-4 hour window
        window_start = base_date.replace(hour=window_start_hour)
        window_end = window_start + timedelta(hours=window_duration)

        # Ensure window doesn't exceed 5pm
        if window_end.hour > 17:
            window_end = base_date.replace(hour=17, minute=0)

        # Estimated duration based on category
        if skill_category == "inspection":
            duration = random.randint(30, 90)
        elif skill_category in ["hvac", "electrical"]:
            duration = random.randint(60, 180)
        elif skill_category == "plumbing":
            duration = random.randint(45, 150)
        else:
            duration = random.randint(30, 120)

        work_order_data = {
            "work_order_id": f"WO-{i:05d}",
            "property_id": property_data["property_id"],
            "property_address": property_data["address"],
            "location": property_data["location"],
            "zone": property_data["zone"],
            "work_order_type": work_order_type,
            "category": skill_category,
            "required_skills": [skill_category],
            "priority": priority,
            "status": "pending",
            "scheduled_date": base_date.date().isoformat(),
            "time_window_start": window_start.isoformat(),
            "time_window_end": window_end.isoformat(),
            "estimated_duration_minutes": duration,
            "description": f"{work_order_type} at {property_data['address']['street']}",
            "created_at": (
                base_date - timedelta(days=random.randint(1, 7))
            ).isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
        work_orders.append(work_order_data)

    return work_orders


def print_summary(properties, technicians, work_orders):
    """Print summary statistics"""
    print("\n" + "=" * 70)
    print("DATA GENERATION SUMMARY")
    print("=" * 70)

    print(f"\nPROPERTIES: {len(properties)} total")
    prop_type_count = {}
    zone_count = {}
    for prop in properties:
        prop_type_count[prop["property_type"]] = (
            prop_type_count.get(prop["property_type"], 0) + 1
        )
        zone_count[prop["zone"]] = zone_count.get(prop["zone"], 0) + 1

    for ptype, count in sorted(prop_type_count.items()):
        pct = (count / len(properties)) * 100
        print(f"  - {ptype.capitalize()}: {count} ({pct:.1f}%)")

    print(f"\n  By Zone:")
    for zone, count in sorted(zone_count.items()):
        zone_name = ZONES[zone]["name"]
        print(f"  - {zone} ({zone_name}): {count}")

    print(f"\nTECHNICIANS: {len(technicians)} total")
    all_skills = set()
    for tech in technicians:
        all_skills.update(tech["skills"])
    print(f"  - Skills coverage: {sorted(all_skills)}")

    avg_hourly_rate = sum(t["hourly_rate"] for t in technicians) / len(technicians)
    print(f"  - Average hourly rate: ${avg_hourly_rate:.2f}")

    avg_max_hours = sum(t["max_daily_hours"] for t in technicians) / len(technicians)
    print(f"  - Average max daily hours: {avg_max_hours:.1f}")

    print(f"\nWORK ORDERS: {len(work_orders)} total")
    priority_count = {}
    category_count = {}
    for wo in work_orders:
        priority_count[wo["priority"]] = priority_count.get(wo["priority"], 0) + 1
        category_count[wo["category"]] = category_count.get(wo["category"], 0) + 1

    print(f"  By Priority:")
    for priority in ["emergency", "high", "medium", "low"]:
        count = priority_count.get(priority, 0)
        pct = (count / len(work_orders)) * 100
        print(f"  - {priority.capitalize()}: {count} ({pct:.1f}%)")

    print(f"\n  By Category:")
    for category, count in sorted(category_count.items()):
        pct = (count / len(work_orders)) * 100
        print(f"  - {category.capitalize()}: {count} ({pct:.1f}%)")

    avg_duration = sum(wo["estimated_duration_minutes"] for wo in work_orders) / len(
        work_orders
    )
    print(f"\n  Average estimated duration: {avg_duration:.1f} minutes")

    print("\n" + "=" * 70)


def main():
    """Main execution function"""
    print("Generating data for Route Optimization Engine...")
    print(f"Target area: Denver, CO metropolitan area")
    print(
        f"Coordinates: Lat {DENVER_LAT_MIN} to {DENVER_LAT_MAX}, Lng {DENVER_LNG_MIN} to {DENVER_LNG_MAX}\n"
    )

    # Generate data
    print("Generating 50 properties...")
    properties = generate_properties(50)

    print("Generating 10 technicians...")
    technicians = generate_technicians(10)

    print("Generating 100 work orders...")
    work_orders = generate_work_orders(100, properties)

    # Create output directory
    output_dir = Path(__file__).parent.parent / "data" / "sample"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Write to JSON files
    print(f"\nWriting data to {output_dir}...")

    with open(output_dir / "properties.json", "w") as f:
        json.dump(properties, f, indent=2)
    print(f"  - properties.json ({len(properties)} records)")

    with open(output_dir / "technicians.json", "w") as f:
        json.dump(technicians, f, indent=2)
    print(f"  - technicians.json ({len(technicians)} records)")

    with open(output_dir / "work_orders.json", "w") as f:
        json.dump(work_orders, f, indent=2)
    print(f"  - work_orders.json ({len(work_orders)} records)")

    # Print summary
    print_summary(properties, technicians, work_orders)

    print(f"\nData generation complete!")
    print(f"Files saved to: {output_dir}")


if __name__ == "__main__":
    main()
