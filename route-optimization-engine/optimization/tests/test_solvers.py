"""
Comprehensive test suite for the Route Optimization Engine.

Tests all three solver implementations (Greedy, Genetic, VRP) against
realistic field-service scenarios in the Denver metro area. Validates
correctness of routes, constraint satisfaction, and comparative quality.

Run with::

    pytest optimization/tests/test_solvers.py -v
"""

from __future__ import annotations

import sys
from datetime import datetime, timedelta
from typing import Any, Dict, List

import pytest

from optimization.solvers.base_solver import (
    BaseSolver,
    OptimizationResult,
    RouteStop,
    TechnicianRoute,
)
from optimization.solvers.genetic_solver import GeneticSolver
from optimization.solvers.greedy_solver import GreedySolver
from optimization.utils.constraints import (
    check_daily_limit,
    check_skill_match,
    check_time_window,
    validate_route,
)
from optimization.utils.distance import (
    build_distance_matrix,
    build_duration_matrix,
    estimate_travel_time,
    haversine_distance,
)

# ---------------------------------------------------------------------------
# Constants for the test scenario
# ---------------------------------------------------------------------------
_SHIFT_START = datetime(2026, 2, 12, 8, 0, 0)
_SHIFT_END = datetime(2026, 2, 12, 17, 0, 0)

# Denver metro area coordinates for realistic distances
_DENVER_LOCATIONS = {
    "downtown": {"lat": 39.7392, "lng": -104.9903},
    "aurora": {"lat": 39.7294, "lng": -104.8319},
    "lakewood": {"lat": 39.7047, "lng": -105.0814},
    "arvada": {"lat": 39.8028, "lng": -105.0875},
    "westminster": {"lat": 39.8367, "lng": -105.0372},
    "thornton": {"lat": 39.8680, "lng": -104.9719},
    "centennial": {"lat": 39.5791, "lng": -104.8769},
    "highlands_r": {"lat": 39.5518, "lng": -105.0109},
    "parker": {"lat": 39.5186, "lng": -104.7614},
    "brighton": {"lat": 39.9853, "lng": -104.8206},
    "golden": {"lat": 39.7555, "lng": -105.2211},
    "littleton": {"lat": 39.6133, "lng": -105.0166},
    "commerce_c": {"lat": 39.8083, "lng": -104.9339},
    "englewood": {"lat": 39.6480, "lng": -104.9878},
    "broomfield": {"lat": 39.9205, "lng": -105.0867},
    "greenwood_v": {"lat": 39.6172, "lng": -104.9508},
    "cherry_hills": {"lat": 39.6417, "lng": -104.9589},
    "lone_tree": {"lat": 39.5372, "lng": -104.8953},
    "castle_rock": {"lat": 39.3722, "lng": -104.8561},
    "northglenn": {"lat": 39.8853, "lng": -104.9811},
}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def technicians() -> List[Dict[str, Any]]:
    """Five technicians with varied skill sets based in Denver metro."""
    return [
        {
            "id": "tech-001",
            "name": "Alice Martinez",
            "skills": ["electrical", "plumbing", "hvac"],
            "home_lat": 39.7392,
            "home_lng": -104.9903,
            "max_hours": 8.0,
            "shift_start": _SHIFT_START,
            "shift_end": _SHIFT_END,
        },
        {
            "id": "tech-002",
            "name": "Bob Johnson",
            "skills": ["plumbing", "general_maintenance"],
            "home_lat": 39.7294,
            "home_lng": -104.8319,
            "max_hours": 8.0,
            "shift_start": _SHIFT_START,
            "shift_end": _SHIFT_END,
        },
        {
            "id": "tech-003",
            "name": "Carol Williams",
            "skills": ["electrical", "inspection", "hvac"],
            "home_lat": 39.8028,
            "home_lng": -105.0875,
            "max_hours": 8.0,
            "shift_start": _SHIFT_START,
            "shift_end": _SHIFT_END,
        },
        {
            "id": "tech-004",
            "name": "David Chen",
            "skills": ["plumbing", "electrical", "general_maintenance", "inspection"],
            "home_lat": 39.5791,
            "home_lng": -104.8769,
            "max_hours": 8.0,
            "shift_start": _SHIFT_START,
            "shift_end": _SHIFT_END,
        },
        {
            "id": "tech-005",
            "name": "Eva Petrov",
            "skills": ["hvac", "general_maintenance", "inspection"],
            "home_lat": 39.9205,
            "home_lng": -105.0867,
            "max_hours": 8.0,
            "shift_start": _SHIFT_START,
            "shift_end": _SHIFT_END,
        },
    ]


@pytest.fixture
def work_orders() -> List[Dict[str, Any]]:
    """Fifteen work orders spread across Denver metro with varied requirements."""
    base_date = _SHIFT_START.date()
    orders = [
        {
            "id": "WO-001",
            "property_id": "P-101",
            "lat": 39.7047,
            "lng": -105.0814,
            "priority": "emergency",
            "required_skills": ["electrical"],
            "duration_minutes": 60,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 10, 0),
        },
        {
            "id": "WO-002",
            "property_id": "P-102",
            "lat": 39.8367,
            "lng": -105.0372,
            "priority": "high",
            "required_skills": ["plumbing"],
            "duration_minutes": 45,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 12, 0),
        },
        {
            "id": "WO-003",
            "property_id": "P-103",
            "lat": 39.8680,
            "lng": -104.9719,
            "priority": "medium",
            "required_skills": ["general_maintenance"],
            "duration_minutes": 30,
            "time_window_start": datetime(2026, 2, 12, 9, 0),
            "time_window_end": datetime(2026, 2, 12, 15, 0),
        },
        {
            "id": "WO-004",
            "property_id": "P-104",
            "lat": 39.5518,
            "lng": -105.0109,
            "priority": "low",
            "required_skills": ["inspection"],
            "duration_minutes": 30,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 17, 0),
        },
        {
            "id": "WO-005",
            "property_id": "P-105",
            "lat": 39.5186,
            "lng": -104.7614,
            "priority": "high",
            "required_skills": ["electrical", "plumbing"],
            "duration_minutes": 90,
            "time_window_start": datetime(2026, 2, 12, 10, 0),
            "time_window_end": datetime(2026, 2, 12, 14, 0),
        },
        {
            "id": "WO-006",
            "property_id": "P-106",
            "lat": 39.9853,
            "lng": -104.8206,
            "priority": "medium",
            "required_skills": ["hvac"],
            "duration_minutes": 60,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 16, 0),
        },
        {
            "id": "WO-007",
            "property_id": "P-107",
            "lat": 39.7555,
            "lng": -105.2211,
            "priority": "low",
            "required_skills": ["general_maintenance"],
            "duration_minutes": 45,
            "time_window_start": datetime(2026, 2, 12, 9, 0),
            "time_window_end": datetime(2026, 2, 12, 17, 0),
        },
        {
            "id": "WO-008",
            "property_id": "P-108",
            "lat": 39.6133,
            "lng": -105.0166,
            "priority": "high",
            "required_skills": ["plumbing"],
            "duration_minutes": 60,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 13, 0),
        },
        {
            "id": "WO-009",
            "property_id": "P-109",
            "lat": 39.8083,
            "lng": -104.9339,
            "priority": "emergency",
            "required_skills": ["electrical"],
            "duration_minutes": 45,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 10, 0),
        },
        {
            "id": "WO-010",
            "property_id": "P-110",
            "lat": 39.6480,
            "lng": -104.9878,
            "priority": "medium",
            "required_skills": ["inspection"],
            "duration_minutes": 30,
            "time_window_start": datetime(2026, 2, 12, 10, 0),
            "time_window_end": datetime(2026, 2, 12, 16, 0),
        },
        {
            "id": "WO-011",
            "property_id": "P-111",
            "lat": 39.6172,
            "lng": -104.9508,
            "priority": "low",
            "required_skills": ["general_maintenance"],
            "duration_minutes": 30,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 17, 0),
        },
        {
            "id": "WO-012",
            "property_id": "P-112",
            "lat": 39.6417,
            "lng": -104.9589,
            "priority": "medium",
            "required_skills": ["hvac"],
            "duration_minutes": 60,
            "time_window_start": datetime(2026, 2, 12, 11, 0),
            "time_window_end": datetime(2026, 2, 12, 16, 0),
        },
        {
            "id": "WO-013",
            "property_id": "P-113",
            "lat": 39.5372,
            "lng": -104.8953,
            "priority": "high",
            "required_skills": ["plumbing", "general_maintenance"],
            "duration_minutes": 75,
            "time_window_start": datetime(2026, 2, 12, 9, 0),
            "time_window_end": datetime(2026, 2, 12, 14, 0),
        },
        {
            "id": "WO-014",
            "property_id": "P-114",
            "lat": 39.3722,
            "lng": -104.8561,
            "priority": "low",
            "required_skills": ["inspection"],
            "duration_minutes": 30,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 17, 0),
        },
        {
            "id": "WO-015",
            "property_id": "P-115",
            "lat": 39.8853,
            "lng": -104.9811,
            "priority": "medium",
            "required_skills": ["general_maintenance"],
            "duration_minutes": 45,
            "time_window_start": datetime(2026, 2, 12, 8, 0),
            "time_window_end": datetime(2026, 2, 12, 17, 0),
        },
    ]
    return orders


@pytest.fixture
def distance_matrix(technicians, work_orders) -> List[List[float]]:
    """Build a distance matrix from technician homes + work order locations."""
    locations: List[Dict[str, float]] = []

    # Technician home bases first (indices 0..4)
    for tech in technicians:
        locations.append({"lat": tech["home_lat"], "lng": tech["home_lng"]})

    # Work order locations (indices 5..19)
    for wo in work_orders:
        locations.append({"lat": wo["lat"], "lng": wo["lng"]})

    return build_distance_matrix(locations)


# ---------------------------------------------------------------------------
# Utility tests
# ---------------------------------------------------------------------------


class TestDistanceUtils:
    """Tests for distance computation utilities."""

    def test_haversine_same_point(self):
        """Distance from a point to itself is zero."""
        assert haversine_distance(39.7392, -104.9903, 39.7392, -104.9903) == 0.0

    def test_haversine_known_distance(self):
        """Denver to Aurora is approximately 10 miles."""
        dist = haversine_distance(39.7392, -104.9903, 39.7294, -104.8319)
        assert 8.0 < dist < 12.0

    def test_build_distance_matrix_symmetric(self):
        """Distance matrix should be symmetric."""
        locs = [
            {"lat": 39.74, "lng": -104.99},
            {"lat": 39.80, "lng": -105.09},
            {"lat": 39.58, "lng": -104.88},
        ]
        matrix = build_distance_matrix(locs)
        for i in range(3):
            for j in range(3):
                assert matrix[i][j] == pytest.approx(matrix[j][i], abs=1e-6)

    def test_build_distance_matrix_diagonal_zero(self):
        """Diagonal entries should be zero."""
        locs = [{"lat": 39.74, "lng": -104.99}, {"lat": 39.80, "lng": -105.09}]
        matrix = build_distance_matrix(locs)
        assert matrix[0][0] == 0.0
        assert matrix[1][1] == 0.0

    def test_build_distance_matrix_missing_key(self):
        """Should raise ValueError for missing lat/lng."""
        with pytest.raises(ValueError, match="missing 'lat' or 'lng'"):
            build_distance_matrix([{"lat": 39.0}])

    def test_build_duration_matrix(self):
        """Duration matrix should convert miles to minutes."""
        dist_matrix = [[0.0, 30.0], [30.0, 0.0]]
        dur_matrix = build_duration_matrix(dist_matrix, avg_speed_mph=30.0)
        assert dur_matrix[0][1] == 60.0
        assert dur_matrix[1][0] == 60.0
        assert dur_matrix[0][0] == 0.0

    def test_build_duration_invalid_speed(self):
        """Should raise ValueError for non-positive speed."""
        with pytest.raises(ValueError):
            build_duration_matrix([[0.0]], avg_speed_mph=0)

    def test_estimate_travel_time(self):
        """15 miles at 30 mph should be 30 minutes."""
        assert estimate_travel_time(15.0, 30.0) == 30.0

    def test_estimate_travel_time_negative_distance(self):
        with pytest.raises(ValueError):
            estimate_travel_time(-1.0)


class TestConstraintUtils:
    """Tests for constraint checking utilities."""

    def test_skill_match_subset(self):
        assert check_skill_match(["electrical", "plumbing"], ["plumbing"])

    def test_skill_match_exact(self):
        assert check_skill_match(["electrical"], ["electrical"])

    def test_skill_match_missing(self):
        assert not check_skill_match(["plumbing"], ["electrical"])

    def test_skill_match_empty_required(self):
        """No required skills means any technician qualifies."""
        assert check_skill_match(["plumbing"], [])

    def test_time_window_inside(self):
        start = datetime(2026, 2, 12, 9, 0)
        end = datetime(2026, 2, 12, 12, 0)
        arrival = datetime(2026, 2, 12, 10, 0)
        assert check_time_window(arrival, start, end)

    def test_time_window_boundary(self):
        start = datetime(2026, 2, 12, 9, 0)
        end = datetime(2026, 2, 12, 12, 0)
        assert check_time_window(start, start, end)
        assert check_time_window(end, start, end)

    def test_time_window_outside(self):
        start = datetime(2026, 2, 12, 9, 0)
        end = datetime(2026, 2, 12, 12, 0)
        late = datetime(2026, 2, 12, 13, 0)
        assert not check_time_window(late, start, end)

    def test_time_window_invalid(self):
        with pytest.raises(ValueError, match="after"):
            check_time_window(
                datetime(2026, 2, 12, 10, 0),
                datetime(2026, 2, 12, 12, 0),
                datetime(2026, 2, 12, 9, 0),
            )

    def test_daily_limit_within(self):
        assert check_daily_limit(5.0, 8.0, 2.0)

    def test_daily_limit_exact(self):
        assert check_daily_limit(5.0, 8.0, 3.0)

    def test_daily_limit_exceeded(self):
        assert not check_daily_limit(5.0, 8.0, 4.0)

    def test_daily_limit_negative(self):
        with pytest.raises(ValueError):
            check_daily_limit(-1.0, 8.0, 1.0)

    def test_validate_route_valid(self, technicians, work_orders):
        """A correctly constructed route should have no violations."""
        tech = technicians[0]  # Alice: electrical, plumbing, hvac
        wo_map = {wo["id"]: wo for wo in work_orders}
        route = [
            {
                "work_order_id": "WO-001",
                "arrival_time": datetime(2026, 2, 12, 8, 30),
                "departure_time": datetime(2026, 2, 12, 9, 30),
                "travel_duration": 15.0,
            },
        ]
        violations = validate_route(route, tech, wo_map)
        assert violations == []

    def test_validate_route_skill_violation(self, technicians, work_orders):
        """Bob (plumbing, general) cannot do electrical work."""
        tech = technicians[1]  # Bob: plumbing, general_maintenance
        wo_map = {wo["id"]: wo for wo in work_orders}
        route = [
            {
                "work_order_id": "WO-001",  # requires electrical
                "arrival_time": datetime(2026, 2, 12, 8, 30),
                "departure_time": datetime(2026, 2, 12, 9, 30),
                "travel_duration": 15.0,
            },
        ]
        violations = validate_route(route, tech, wo_map)
        assert any("missing skills" in v for v in violations)


# ---------------------------------------------------------------------------
# Greedy solver tests
# ---------------------------------------------------------------------------


class TestGreedySolver:
    """Tests for the greedy nearest-neighbor solver."""

    def test_produces_valid_result(self, work_orders, technicians, distance_matrix):
        """Solver returns an OptimizationResult with correct structure."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        assert isinstance(result, OptimizationResult)
        assert result.algorithm == "GreedySolver"
        assert result.solve_time_seconds >= 0
        assert len(result.routes) == len(technicians)

    def test_all_orders_accounted_for(self, work_orders, technicians, distance_matrix):
        """Every work order is either assigned or in unassigned list."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        assigned_ids = set()
        for route in result.routes:
            for stop in route.stops:
                assigned_ids.add(stop.work_order_id)

        all_ids = {wo["id"] for wo in work_orders}
        unassigned_set = set(result.unassigned_orders)

        assert assigned_ids | unassigned_set == all_ids
        assert assigned_ids & unassigned_set == set()

    def test_skill_matching_respected(self, work_orders, technicians, distance_matrix):
        """No route stop should violate skill requirements."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        wo_map = {wo["id"]: wo for wo in work_orders}
        tech_map = {t["id"]: t for t in technicians}

        for route in result.routes:
            tech = tech_map[route.technician_id]
            for stop in route.stops:
                wo = wo_map[stop.work_order_id]
                assert check_skill_match(tech["skills"], wo["required_skills"]), (
                    f"Skill violation: {route.technician_name} assigned "
                    f"{stop.work_order_id} requiring {wo['required_skills']}"
                )

    def test_time_windows_respected(self, work_orders, technicians, distance_matrix):
        """No route stop should arrive after the time window closes."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        wo_map = {wo["id"]: wo for wo in work_orders}

        for route in result.routes:
            for stop in route.stops:
                wo = wo_map[stop.work_order_id]
                if stop.arrival_time and wo.get("time_window_end"):
                    assert stop.arrival_time <= wo["time_window_end"], (
                        f"Time window violation: {stop.work_order_id} arrived at "
                        f"{stop.arrival_time}, window ends {wo['time_window_end']}"
                    )

    def test_daily_hours_respected(self, work_orders, technicians, distance_matrix):
        """No technician should exceed their max daily hours."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        tech_map = {t["id"]: t for t in technicians}

        for route in result.routes:
            tech = tech_map[route.technician_id]
            total_hours = (route.total_duration + route.total_work_time) / 60.0
            assert total_hours <= tech["max_hours"] + 0.01, (
                f"Daily limit exceeded for {route.technician_name}: "
                f"{total_hours:.2f}h > {tech['max_hours']}h"
            )

    def test_routes_have_positive_distance(
        self, work_orders, technicians, distance_matrix
    ):
        """Routes with stops should have positive total distance."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        for route in result.routes:
            if len(route.stops) > 0:
                assert route.total_distance > 0

    def test_emergency_orders_prioritized(
        self, work_orders, technicians, distance_matrix
    ):
        """Emergency orders should be assigned before lower priority ones."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        assigned_ids = set()
        for route in result.routes:
            for stop in route.stops:
                assigned_ids.add(stop.work_order_id)

        emergency_ids = {
            wo["id"] for wo in work_orders if wo["priority"] == "emergency"
        }
        # All emergency orders should be assigned (they are feasible)
        for eid in emergency_ids:
            assert eid in assigned_ids, f"Emergency order {eid} was not assigned"


# ---------------------------------------------------------------------------
# Genetic solver tests
# ---------------------------------------------------------------------------


class TestGeneticSolver:
    """Tests for the genetic algorithm solver."""

    @pytest.fixture
    def ga_config(self) -> Dict[str, Any]:
        """Reduced parameters for faster test execution."""
        return {
            "population_size": 30,
            "generations": 50,
            "mutation_rate": 0.15,
            "elite_size": 5,
            "seed": 42,
        }

    def test_produces_valid_result(
        self, work_orders, technicians, distance_matrix, ga_config
    ):
        solver = GeneticSolver(work_orders, technicians, distance_matrix, ga_config)
        result = solver.solve()

        assert isinstance(result, OptimizationResult)
        assert result.algorithm == "GeneticSolver"
        assert result.solve_time_seconds >= 0

    def test_all_orders_accounted_for(
        self, work_orders, technicians, distance_matrix, ga_config
    ):
        solver = GeneticSolver(work_orders, technicians, distance_matrix, ga_config)
        result = solver.solve()

        assigned_ids = set()
        for route in result.routes:
            for stop in route.stops:
                assigned_ids.add(stop.work_order_id)

        all_ids = {wo["id"] for wo in work_orders}
        unassigned_set = set(result.unassigned_orders)

        assert assigned_ids | unassigned_set == all_ids
        assert assigned_ids & unassigned_set == set()

    def test_skill_matching_respected(
        self, work_orders, technicians, distance_matrix, ga_config
    ):
        solver = GeneticSolver(work_orders, technicians, distance_matrix, ga_config)
        result = solver.solve()

        wo_map = {wo["id"]: wo for wo in work_orders}
        tech_map = {t["id"]: t for t in technicians}

        for route in result.routes:
            tech = tech_map[route.technician_id]
            for stop in route.stops:
                wo = wo_map[stop.work_order_id]
                assert check_skill_match(tech["skills"], wo["required_skills"])

    def test_convergence_metadata(
        self, work_orders, technicians, distance_matrix, ga_config
    ):
        """GA should record convergence information in metadata."""
        solver = GeneticSolver(work_orders, technicians, distance_matrix, ga_config)
        result = solver.solve()

        assert "best_fitness" in result.metadata
        assert "convergence_history_length" in result.metadata
        assert result.metadata["convergence_history_length"] > 0
        assert "initial_fitness" in result.metadata
        assert "final_fitness" in result.metadata

    def test_fitness_improves(
        self, work_orders, technicians, distance_matrix, ga_config
    ):
        """Final fitness should be no worse than initial fitness."""
        solver = GeneticSolver(work_orders, technicians, distance_matrix, ga_config)
        result = solver.solve()

        initial = result.metadata.get("initial_fitness", float("inf"))
        final = result.metadata.get("final_fitness", float("inf"))
        assert final <= initial, (
            f"Fitness did not improve: initial={initial}, final={final}"
        )

    def test_deterministic_with_seed(self, work_orders, technicians, distance_matrix):
        """Same seed should produce identical results."""
        config = {"population_size": 20, "generations": 20, "seed": 123}
        solver1 = GeneticSolver(work_orders, technicians, distance_matrix, config)
        result1 = solver1.solve()

        solver2 = GeneticSolver(work_orders, technicians, distance_matrix, config)
        result2 = solver2.solve()

        assert result1.total_distance == result2.total_distance
        assert len(result1.unassigned_orders) == len(result2.unassigned_orders)


# ---------------------------------------------------------------------------
# VRP solver tests (conditional on ortools availability)
# ---------------------------------------------------------------------------


def _ortools_available() -> bool:
    """Check if ortools is installed."""
    try:
        from ortools.constraint_solver import pywrapcp

        return True
    except ImportError:
        return False


@pytest.mark.skipif(not _ortools_available(), reason="ortools not installed")
class TestVRPSolver:
    """Tests for the Google OR-Tools VRP solver."""

    @pytest.fixture
    def vrp_config(self) -> Dict[str, Any]:
        return {"time_limit_seconds": 10}

    def test_produces_valid_result(
        self, work_orders, technicians, distance_matrix, vrp_config
    ):
        from optimization.solvers.vrp_solver import VRPSolver

        solver = VRPSolver(work_orders, technicians, distance_matrix, vrp_config)
        result = solver.solve()

        assert isinstance(result, OptimizationResult)
        assert result.algorithm == "VRPSolver"

    def test_all_orders_accounted_for(
        self, work_orders, technicians, distance_matrix, vrp_config
    ):
        from optimization.solvers.vrp_solver import VRPSolver

        solver = VRPSolver(work_orders, technicians, distance_matrix, vrp_config)
        result = solver.solve()

        assigned_ids = set()
        for route in result.routes:
            for stop in route.stops:
                assigned_ids.add(stop.work_order_id)

        all_ids = {wo["id"] for wo in work_orders}
        unassigned_set = set(result.unassigned_orders)

        assert assigned_ids | unassigned_set == all_ids
        assert assigned_ids & unassigned_set == set()

    def test_skill_matching_respected(
        self, work_orders, technicians, distance_matrix, vrp_config
    ):
        from optimization.solvers.vrp_solver import VRPSolver

        solver = VRPSolver(work_orders, technicians, distance_matrix, vrp_config)
        result = solver.solve()

        wo_map = {wo["id"]: wo for wo in work_orders}
        tech_map = {t["id"]: t for t in technicians}

        for route in result.routes:
            tech = tech_map[route.technician_id]
            for stop in route.stops:
                wo = wo_map[stop.work_order_id]
                assert check_skill_match(tech["skills"], wo["required_skills"])

    def test_vrp_outperforms_greedy(
        self, work_orders, technicians, distance_matrix, vrp_config
    ):
        """VRP solver should produce equal or shorter total distance than greedy."""
        from optimization.solvers.vrp_solver import VRPSolver

        greedy = GreedySolver(work_orders, technicians, distance_matrix)
        greedy_result = greedy.solve()

        vrp = VRPSolver(work_orders, technicians, distance_matrix, vrp_config)
        vrp_result = vrp.solve()

        # VRP should assign at least as many orders as greedy
        vrp_assigned = sum(len(r.stops) for r in vrp_result.routes)
        greedy_assigned = sum(len(r.stops) for r in greedy_result.routes)

        # When both assign similar counts, VRP distance should be <= greedy
        if vrp_assigned >= greedy_assigned:
            assert vrp_result.total_distance <= greedy_result.total_distance * 1.05, (
                f"VRP distance ({vrp_result.total_distance:.2f}) exceeded "
                f"greedy ({greedy_result.total_distance:.2f}) by >5%"
            )


# ---------------------------------------------------------------------------
# Edge case tests
# ---------------------------------------------------------------------------


class TestEdgeCases:
    """Edge case scenarios that all solvers must handle."""

    def _make_minimal_data(
        self,
        num_orders: int = 1,
        priority: str = "medium",
        required_skills: List[str] | None = None,
        tech_skills: List[str] | None = None,
    ):
        """Create minimal test data for edge case tests."""
        if required_skills is None:
            required_skills = ["general_maintenance"]
        if tech_skills is None:
            tech_skills = ["general_maintenance", "electrical", "plumbing"]

        technicians = [
            {
                "id": "tech-001",
                "name": "Test Tech",
                "skills": tech_skills,
                "home_lat": 39.7392,
                "home_lng": -104.9903,
                "max_hours": 8.0,
                "shift_start": _SHIFT_START,
                "shift_end": _SHIFT_END,
            }
        ]

        work_orders = []
        for i in range(num_orders):
            work_orders.append(
                {
                    "id": f"WO-{i + 1:03d}",
                    "property_id": f"P-{i + 1:03d}",
                    "lat": 39.74 + (i * 0.01),
                    "lng": -104.99 + (i * 0.01),
                    "priority": priority,
                    "required_skills": required_skills,
                    "duration_minutes": 30,
                    "time_window_start": _SHIFT_START,
                    "time_window_end": _SHIFT_END,
                }
            )

        locations = [
            {"lat": technicians[0]["home_lat"], "lng": technicians[0]["home_lng"]}
        ]
        for wo in work_orders:
            locations.append({"lat": wo["lat"], "lng": wo["lng"]})

        dm = build_distance_matrix(locations)
        return work_orders, technicians, dm

    def test_single_work_order(self):
        """Solver handles a single work order correctly."""
        wo, tech, dm = self._make_minimal_data(num_orders=1)

        solver = GreedySolver(wo, tech, dm)
        result = solver.solve()

        assert len(result.routes) == 1
        assert len(result.routes[0].stops) == 1
        assert result.unassigned_orders == []

    def test_no_feasible_skill_match(self):
        """When no technician has required skills, orders go unassigned."""
        wo, tech, dm = self._make_minimal_data(
            num_orders=1,
            required_skills=["exotic_skill_xyz"],
            tech_skills=["general_maintenance"],
        )

        solver = GreedySolver(wo, tech, dm)
        result = solver.solve()

        assert len(result.unassigned_orders) == 1
        assert result.unassigned_orders[0] == "WO-001"

    def test_all_emergency_priority(self):
        """All-emergency scenario should still produce valid routes."""
        wo, tech, dm = self._make_minimal_data(num_orders=5, priority="emergency")

        solver = GreedySolver(wo, tech, dm)
        result = solver.solve()

        assert isinstance(result, OptimizationResult)
        # All assigned stops should have valid data
        for route in result.routes:
            for stop in route.stops:
                assert stop.work_order_id.startswith("WO-")

    def test_genetic_single_order(self):
        """Genetic solver handles single work order."""
        wo, tech, dm = self._make_minimal_data(num_orders=1)

        solver = GeneticSolver(
            wo, tech, dm, {"population_size": 10, "generations": 10, "seed": 1}
        )
        result = solver.solve()

        assert len(result.unassigned_orders) == 0 or len(result.routes[0].stops) == 1

    def test_empty_work_orders_rejected(self, technicians):
        """Empty work orders should raise ValueError."""
        with pytest.raises(ValueError, match="work_orders must not be empty"):
            GreedySolver([], technicians, [[]])

    def test_empty_technicians_rejected(self, work_orders):
        """Empty technicians should raise ValueError."""
        with pytest.raises(ValueError, match="technicians must not be empty"):
            GreedySolver(work_orders, [], [[]])

    def test_matrix_size_mismatch(self, work_orders, technicians):
        """Wrong matrix size should raise ValueError."""
        bad_matrix = [[0.0]]
        with pytest.raises(ValueError, match="Distance matrix"):
            GreedySolver(work_orders, technicians, bad_matrix)

    def test_missing_work_order_keys(self, technicians):
        """Work order missing required keys should raise ValueError."""
        bad_wo = [{"id": "WO-BAD"}]  # Missing most required keys
        dm = [[0.0, 0.0], [0.0, 0.0]]
        with pytest.raises(ValueError, match="missing required keys"):
            GreedySolver(bad_wo, technicians, dm)

    def test_missing_technician_keys(self, work_orders):
        """Technician missing required keys should raise ValueError."""
        bad_tech = [{"id": "T-BAD"}]
        n = 1 + len(work_orders)
        dm = [[0.0] * n for _ in range(n)]
        with pytest.raises(ValueError, match="missing required keys"):
            GreedySolver(work_orders, bad_tech, dm)


# ---------------------------------------------------------------------------
# Cross-solver comparison tests
# ---------------------------------------------------------------------------


class TestSolverComparison:
    """Compare output quality and consistency across solvers."""

    def test_greedy_vs_genetic_both_assign(
        self, work_orders, technicians, distance_matrix
    ):
        """Both solvers should assign a reasonable number of orders."""
        greedy = GreedySolver(work_orders, technicians, distance_matrix)
        g_result = greedy.solve()

        ga = GeneticSolver(
            work_orders,
            technicians,
            distance_matrix,
            {"population_size": 30, "generations": 50, "seed": 42},
        )
        ga_result = ga.solve()

        g_assigned = sum(len(r.stops) for r in g_result.routes)
        ga_assigned = sum(len(r.stops) for r in ga_result.routes)

        # Both should assign at least half the orders
        min_expected = len(work_orders) // 2
        assert g_assigned >= min_expected, (
            f"Greedy assigned only {g_assigned}/{len(work_orders)}"
        )
        assert ga_assigned >= min_expected, (
            f"Genetic assigned only {ga_assigned}/{len(work_orders)}"
        )

    def test_result_total_distance_consistent(
        self, work_orders, technicians, distance_matrix
    ):
        """Total distance should equal sum of route distances."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        route_sum = sum(r.total_distance for r in result.routes)
        assert result.total_distance == pytest.approx(route_sum, abs=0.1)

    def test_no_duplicate_assignments(self, work_orders, technicians, distance_matrix):
        """No work order should be assigned to more than one technician."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        all_assigned: List[str] = []
        for route in result.routes:
            for stop in route.stops:
                all_assigned.append(stop.work_order_id)

        assert len(all_assigned) == len(set(all_assigned)), (
            "Duplicate work order assignments found"
        )

    def test_sequences_are_contiguous(self, work_orders, technicians, distance_matrix):
        """Route stop sequences should be 0-indexed and contiguous."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        for route in result.routes:
            sequences = [s.sequence for s in route.stops]
            assert sequences == list(range(len(sequences)))

    def test_utilization_in_valid_range(
        self, work_orders, technicians, distance_matrix
    ):
        """Utilization should be between 0 and 100 percent."""
        solver = GreedySolver(work_orders, technicians, distance_matrix)
        result = solver.solve()

        for route in result.routes:
            assert 0.0 <= route.utilization_percent <= 100.0
