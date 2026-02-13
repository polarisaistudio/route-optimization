"""Tests for the end-to-end optimization runner script."""

import json
import random
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from run_optimization import (
    build_distance_matrix,
    calculate_route_metrics,
    haversine_distance,
    load_json_file,
    run_genetic_algorithm,
    run_greedy_algorithm,
    run_vrp_algorithm,
)


# ---------------------------------------------------------------------------
# Shared Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def sample_properties():
    return [
        {
            "property_id": "P1",
            "address": {
                "street": "100 Main",
                "city": "Denver",
                "state": "CO",
                "zip_code": "80202",
            },
            "location": {"type": "Point", "coordinates": [-104.99, 39.74]},
            "zone": "Zone-A",
        },
        {
            "property_id": "P2",
            "address": {
                "street": "200 Broadway",
                "city": "Denver",
                "state": "CO",
                "zip_code": "80203",
            },
            "location": {"type": "Point", "coordinates": [-104.98, 39.73]},
            "zone": "Zone-A",
        },
        {
            "property_id": "P3",
            "address": {
                "street": "300 Colfax",
                "city": "Denver",
                "state": "CO",
                "zip_code": "80204",
            },
            "location": {"type": "Point", "coordinates": [-105.02, 39.74]},
            "zone": "Zone-D",
        },
    ]


@pytest.fixture
def sample_technicians():
    return [
        {
            "technician_id": "TECH-001",
            "name": "Alice",
            "skills": ["hvac", "general"],
            "home_base": {
                "address": {
                    "street": "1 Home",
                    "city": "Denver",
                    "state": "CO",
                    "zip_code": "80202",
                },
                "location": {"type": "Point", "coordinates": [-104.99, 39.75]},
            },
            "max_daily_hours": 8,
            "max_daily_distance_miles": 100,
            "hourly_rate": 40,
        },
        {
            "technician_id": "TECH-002",
            "name": "Bob",
            "skills": ["plumbing", "general", "electrical"],
            "home_base": {
                "address": {
                    "street": "2 Home",
                    "city": "Denver",
                    "state": "CO",
                    "zip_code": "80203",
                },
                "location": {"type": "Point", "coordinates": [-104.97, 39.72]},
            },
            "max_daily_hours": 8,
            "max_daily_distance_miles": 100,
            "hourly_rate": 35,
        },
    ]


@pytest.fixture
def sample_work_orders():
    return [
        {
            "work_order_id": "WO-001",
            "property_id": "P1",
            "category": "hvac",
            "required_skills": ["hvac"],
            "priority": "high",
            "estimated_duration_minutes": 60,
            "location": {"type": "Point", "coordinates": [-104.99, 39.74]},
            "time_window_start": "2026-01-15T08:00:00",
            "time_window_end": "2026-01-15T12:00:00",
        },
        {
            "work_order_id": "WO-002",
            "property_id": "P2",
            "category": "general",
            "required_skills": ["general"],
            "priority": "medium",
            "estimated_duration_minutes": 45,
            "location": {"type": "Point", "coordinates": [-104.98, 39.73]},
            "time_window_start": "2026-01-15T09:00:00",
            "time_window_end": "2026-01-15T15:00:00",
        },
        {
            "work_order_id": "WO-003",
            "property_id": "P3",
            "category": "plumbing",
            "required_skills": ["plumbing"],
            "priority": "emergency",
            "estimated_duration_minutes": 90,
            "location": {"type": "Point", "coordinates": [-105.02, 39.74]},
            "time_window_start": "2026-01-15T08:00:00",
            "time_window_end": "2026-01-15T17:00:00",
        },
        {
            "work_order_id": "WO-004",
            "property_id": "P1",
            "category": "general",
            "required_skills": ["general"],
            "priority": "low",
            "estimated_duration_minutes": 30,
            "location": {"type": "Point", "coordinates": [-105.00, 39.75]},
            "time_window_start": "2026-01-15T10:00:00",
            "time_window_end": "2026-01-15T16:00:00",
        },
    ]


@pytest.fixture
def distance_matrix(sample_work_orders):
    locations = [wo["location"] for wo in sample_work_orders]
    return build_distance_matrix(locations)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
class TestLoadJsonFile:
    def test_valid_file(self, tmp_path):
        data = [{"a": 1}, {"b": 2}]
        f = tmp_path / "data.json"
        f.write_text(json.dumps(data))
        result = load_json_file(str(f))
        assert result == data

    def test_missing_file(self):
        result = load_json_file("/nonexistent/missing.json")
        assert result is None

    def test_invalid_json(self, tmp_path):
        f = tmp_path / "bad.json"
        f.write_text("{invalid}")
        result = load_json_file(str(f))
        assert result is None


class TestHaversineDistance:
    def test_same_point(self):
        dist = haversine_distance(39.74, -104.99, 39.74, -104.99)
        assert dist == 0.0

    def test_known_distance(self):
        # Denver (39.7392, -104.9903) to Colorado Springs (38.8339, -104.8214)
        dist = haversine_distance(39.7392, -104.9903, 38.8339, -104.8214)
        assert 55 < dist < 75  # ~62 miles

    def test_symmetric(self):
        d1 = haversine_distance(39.74, -104.99, 39.73, -104.98)
        d2 = haversine_distance(39.73, -104.98, 39.74, -104.99)
        assert abs(d1 - d2) < 0.001

    def test_positive_distance(self):
        dist = haversine_distance(39.74, -104.99, 39.80, -104.90)
        assert dist > 0


class TestBuildDistanceMatrix:
    def test_square_matrix(self, distance_matrix, sample_work_orders):
        n = len(sample_work_orders)
        assert len(distance_matrix) == n
        for row in distance_matrix:
            assert len(row) == n

    def test_diagonal_zero(self, distance_matrix):
        for i in range(len(distance_matrix)):
            assert distance_matrix[i][i] == 0.0

    def test_symmetric(self, distance_matrix):
        n = len(distance_matrix)
        for i in range(n):
            for j in range(n):
                assert abs(distance_matrix[i][j] - distance_matrix[j][i]) < 0.001

    def test_positive_off_diagonal(self, distance_matrix):
        n = len(distance_matrix)
        for i in range(n):
            for j in range(n):
                if i != j:
                    assert distance_matrix[i][j] > 0

    def test_empty_locations(self):
        matrix = build_distance_matrix([])
        assert matrix == []


class TestCalculateRouteMetrics:
    def test_empty_route(self, distance_matrix, sample_technicians):
        metrics = calculate_route_metrics([], distance_matrix, sample_technicians[0])
        assert metrics["total_distance"] == 0.0
        assert metrics["total_time"] == 0.0
        assert metrics["num_stops"] == 0
        assert metrics["utilization"] == 0.0

    def test_single_stop(self, distance_matrix, sample_technicians):
        route = [{"estimated_duration_minutes": 60, "location_index": 0}]
        metrics = calculate_route_metrics(route, distance_matrix, sample_technicians[0])
        assert metrics["num_stops"] == 1
        assert metrics["total_time"] > 0  # At least the work duration

    def test_utilization_capped(self, distance_matrix):
        tech = {"max_daily_hours": 1}  # Very low max
        route = [
            {"estimated_duration_minutes": 120, "location_index": 0},
        ]
        metrics = calculate_route_metrics(route, distance_matrix, tech)
        assert metrics["utilization"] == 100  # Capped at 100


class TestRunGreedyAlgorithm:
    def test_returns_required_keys(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_greedy_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assert "algorithm" in result
        assert "routes" in result
        assert "total_distance" in result
        assert "total_time" in result
        assert "num_routes" in result
        assert "avg_utilization" in result
        assert "unassigned_orders" in result
        assert "solve_time" in result

    def test_algorithm_name(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_greedy_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assert result["algorithm"] == "Greedy"

    def test_all_orders_accounted(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_greedy_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assigned = sum(len(route) for route in result["routes"].values())
        assert assigned + result["unassigned_orders"] == len(sample_work_orders)

    def test_solve_time_positive(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_greedy_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assert result["solve_time"] >= 0


class TestRunVRPAlgorithm:
    def test_returns_required_keys(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_vrp_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assert "algorithm" in result
        assert "routes" in result
        assert "total_distance" in result
        assert result["algorithm"] == "VRP"

    def test_all_orders_accounted(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_vrp_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assigned = sum(len(route) for route in result["routes"].values())
        assert assigned + result["unassigned_orders"] == len(sample_work_orders)


class TestRunGeneticAlgorithm:
    def test_returns_required_keys(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_genetic_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assert "algorithm" in result
        assert "routes" in result
        assert result["algorithm"] == "Genetic"

    def test_all_orders_accounted(
        self, sample_work_orders, sample_technicians, distance_matrix
    ):
        result = run_genetic_algorithm(
            sample_work_orders, sample_technicians, distance_matrix
        )
        assigned = sum(len(route) for route in result["routes"].values())
        assert assigned + result["unassigned_orders"] == len(sample_work_orders)
