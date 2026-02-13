"""Tests for the data generation script."""

import json
import random
import sys
from datetime import datetime
from pathlib import Path

import pytest

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from generate_data import (
    DENVER_LAT_MAX,
    DENVER_LAT_MIN,
    DENVER_LNG_MAX,
    DENVER_LNG_MIN,
    ZONES,
    generate_denver_address,
    generate_properties,
    generate_technicians,
    generate_work_orders,
    get_random_coordinates,
    get_zone_from_coordinates,
)


class TestGetRandomCoordinates:
    def test_within_denver_bounds(self):
        random.seed(42)
        for _ in range(50):
            lat, lng = get_random_coordinates()
            assert DENVER_LAT_MIN <= lat <= DENVER_LAT_MAX
            assert DENVER_LNG_MIN <= lng <= DENVER_LNG_MAX

    def test_within_specific_zone(self):
        random.seed(42)
        for zone_id, zone_info in ZONES.items():
            lat, lng = get_random_coordinates(zone_id)
            assert zone_info["lat_range"][0] <= lat <= zone_info["lat_range"][1]
            assert zone_info["lng_range"][0] <= lng <= zone_info["lng_range"][1]

    def test_different_coordinates_different_seeds(self):
        random.seed(1)
        c1 = get_random_coordinates()
        random.seed(2)
        c2 = get_random_coordinates()
        assert c1 != c2

    def test_coordinates_have_precision(self):
        random.seed(42)
        lat, lng = get_random_coordinates()
        # Should be rounded to 6 decimal places
        assert lat == round(lat, 6)
        assert lng == round(lng, 6)


class TestGetZoneFromCoordinates:
    def test_zone_a_downtown(self):
        lat = 39.74
        lng = -104.99
        assert get_zone_from_coordinates(lat, lng) == "Zone-A"

    def test_zone_b_north(self):
        lat = 39.80
        lng = -104.95
        assert get_zone_from_coordinates(lat, lng) == "Zone-B"

    def test_zone_c_south(self):
        lat = 39.65
        lng = -104.90
        assert get_zone_from_coordinates(lat, lng) == "Zone-C"

    def test_zone_d_west(self):
        lat = 39.73
        lng = -105.05
        assert get_zone_from_coordinates(lat, lng) == "Zone-D"

    def test_zone_e_east(self):
        lat = 39.73
        lng = -104.85
        assert get_zone_from_coordinates(lat, lng) == "Zone-E"

    def test_outside_all_zones_defaults(self):
        result = get_zone_from_coordinates(40.0, -105.5)
        assert result == "Zone-A"


class TestGenerateDenverAddress:
    def test_returns_correct_keys(self):
        random.seed(42)
        addr = generate_denver_address(39.74, -104.99)
        assert "street" in addr
        assert "city" in addr
        assert "state" in addr
        assert "zip_code" in addr

    def test_city_is_denver(self):
        random.seed(42)
        addr = generate_denver_address(39.74, -104.99)
        assert addr["city"] == "Denver"

    def test_state_is_co(self):
        random.seed(42)
        addr = generate_denver_address(39.74, -104.99)
        assert addr["state"] == "CO"

    def test_street_has_number_and_name(self):
        random.seed(42)
        addr = generate_denver_address(39.74, -104.99)
        parts = addr["street"].split(" ", 1)
        assert len(parts) == 2
        assert parts[0].isdigit()

    def test_zip_code_format(self):
        random.seed(42)
        addr = generate_denver_address(39.74, -104.99)
        assert len(addr["zip_code"]) == 5
        assert addr["zip_code"].isdigit()


class TestGenerateProperties:
    @pytest.fixture
    def properties(self):
        random.seed(42)
        return generate_properties(20)

    def test_correct_count(self, properties):
        assert len(properties) == 20

    def test_correct_count_various(self):
        random.seed(42)
        assert len(generate_properties(10)) == 10
        random.seed(42)
        assert len(generate_properties(50)) == 50

    def test_required_keys(self, properties):
        for prop in properties:
            assert "property_id" in prop
            assert "address" in prop
            assert "location" in prop
            assert "property_type" in prop
            assert "zone" in prop

    def test_unique_ids(self, properties):
        ids = [p["property_id"] for p in properties]
        assert len(ids) == len(set(ids))

    def test_id_format(self, properties):
        for prop in properties:
            assert prop["property_id"].startswith("PROP-")
            assert len(prop["property_id"]) == 9  # PROP-XXXX

    def test_geojson_format(self, properties):
        for prop in properties:
            loc = prop["location"]
            assert loc["type"] == "Point"
            assert len(loc["coordinates"]) == 2
            lng, lat = loc["coordinates"]
            assert -180 <= lng <= 180
            assert -90 <= lat <= 90

    def test_valid_property_types(self, properties):
        valid = {"residential", "commercial", "industrial"}
        for prop in properties:
            assert prop["property_type"] in valid

    def test_valid_zones(self, properties):
        valid = {"Zone-A", "Zone-B", "Zone-C", "Zone-D", "Zone-E"}
        for prop in properties:
            assert prop["zone"] in valid

    def test_distributed_across_zones(self, properties):
        zones = {p["zone"] for p in properties}
        assert len(zones) >= 3  # At least 3 zones represented


class TestGenerateTechnicians:
    @pytest.fixture
    def technicians(self):
        random.seed(42)
        return generate_technicians(5)

    def test_correct_count(self, technicians):
        assert len(technicians) == 5

    def test_required_keys(self, technicians):
        for tech in technicians:
            assert "technician_id" in tech
            assert "name" in tech
            assert "skills" in tech
            assert "home_base" in tech
            assert "max_daily_hours" in tech

    def test_id_format(self, technicians):
        for tech in technicians:
            assert tech["technician_id"].startswith("TECH-")

    def test_valid_skills(self, technicians):
        valid = {"hvac", "plumbing", "electrical", "general", "inspection"}
        for tech in technicians:
            assert len(tech["skills"]) >= 1
            for skill in tech["skills"]:
                assert skill in valid

    def test_reasonable_max_hours(self, technicians):
        for tech in technicians:
            assert 1 <= tech["max_daily_hours"] <= 24

    def test_home_base_has_location(self, technicians):
        for tech in technicians:
            assert "location" in tech["home_base"]
            loc = tech["home_base"]["location"]
            assert loc["type"] == "Point"
            assert len(loc["coordinates"]) == 2


class TestGenerateWorkOrders:
    @pytest.fixture
    def properties(self):
        random.seed(42)
        return generate_properties(10)

    @pytest.fixture
    def work_orders(self, properties):
        random.seed(42)
        return generate_work_orders(50, properties)

    def test_requires_properties(self):
        with pytest.raises(ValueError):
            generate_work_orders(10, None)

    def test_correct_count(self, work_orders):
        assert len(work_orders) == 50

    def test_required_keys(self, work_orders):
        for wo in work_orders:
            assert "work_order_id" in wo
            assert "property_id" in wo
            assert "category" in wo
            assert "priority" in wo
            assert "estimated_duration_minutes" in wo
            assert "time_window_start" in wo
            assert "time_window_end" in wo

    def test_id_format(self, work_orders):
        for wo in work_orders:
            assert wo["work_order_id"].startswith("WO-")

    def test_valid_categories(self, work_orders):
        valid = {"hvac", "plumbing", "electrical", "general", "inspection"}
        for wo in work_orders:
            assert wo["category"] in valid

    def test_valid_priorities(self, work_orders):
        valid = {"emergency", "high", "medium", "low"}
        for wo in work_orders:
            assert wo["priority"] in valid

    def test_positive_duration(self, work_orders):
        for wo in work_orders:
            assert wo["estimated_duration_minutes"] > 0
            assert wo["estimated_duration_minutes"] <= 960

    def test_time_window_ordering(self, work_orders):
        for wo in work_orders:
            start = datetime.fromisoformat(wo["time_window_start"])
            end = datetime.fromisoformat(wo["time_window_end"])
            assert end > start

    def test_references_existing_properties(self, work_orders, properties):
        prop_ids = {p["property_id"] for p in properties}
        for wo in work_orders:
            assert wo["property_id"] in prop_ids

    def test_priority_distribution(self, work_orders):
        counts = {}
        for wo in work_orders:
            counts[wo["priority"]] = counts.get(wo["priority"], 0) + 1
        total = len(work_orders)
        # Medium should be the most common (target 50%)
        assert counts.get("medium", 0) > counts.get("emergency", 0)
        # Emergency should be rare (target 5%)
        assert counts.get("emergency", 0) / total < 0.20
