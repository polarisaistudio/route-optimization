"""
Abstract base class and shared data structures for route optimization solvers.

Defines the contract that all solver implementations must follow, along with
the dataclasses used to represent optimization results, technician routes,
and individual route stops.
"""

from __future__ import annotations

import logging
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional, Set

from optimization.utils.distance import estimate_travel_time, haversine_distance

logger = logging.getLogger(__name__)


@dataclass
class RouteStop:
    """A single stop on a technician's route.

    Attributes:
        work_order_id: Unique identifier for the work order at this stop.
        property_id: Unique identifier for the property being serviced.
        lat: Latitude of the property.
        lng: Longitude of the property.
        sequence: Position in the route (0-indexed).
        arrival_time: Estimated arrival time at this stop.
        departure_time: Estimated departure time from this stop.
        travel_distance: Distance traveled from the previous stop (miles).
        travel_duration: Travel time from the previous stop (minutes).
    """

    work_order_id: str
    property_id: str
    lat: float
    lng: float
    sequence: int
    arrival_time: Optional[datetime] = None
    departure_time: Optional[datetime] = None
    travel_distance: float = 0.0
    travel_duration: float = 0.0


@dataclass
class TechnicianRoute:
    """Complete route for a single technician.

    Attributes:
        technician_id: Unique identifier for the technician.
        technician_name: Display name of the technician.
        stops: Ordered list of route stops.
        total_distance: Total travel distance for the route (miles).
        total_duration: Total travel time for the route (minutes).
        total_work_time: Total on-site work time (minutes).
        utilization_percent: Percentage of available hours used (0-100).
    """

    technician_id: str
    technician_name: str
    stops: List[RouteStop] = field(default_factory=list)
    total_distance: float = 0.0
    total_duration: float = 0.0
    total_work_time: float = 0.0
    utilization_percent: float = 0.0


@dataclass
class OptimizationResult:
    """Result of a route optimization run.

    Attributes:
        routes: List of technician routes produced by the solver.
        total_distance: Sum of travel distances across all routes (miles).
        total_duration: Sum of travel durations across all routes (minutes).
        unassigned_orders: Work order IDs that could not be assigned.
        algorithm: Name of the algorithm used.
        solve_time_seconds: Wall-clock time the solver took (seconds).
        metadata: Additional solver-specific data (convergence info, etc.).
    """

    routes: List[TechnicianRoute]
    total_distance: float
    total_duration: float
    unassigned_orders: List[str]
    algorithm: str
    solve_time_seconds: float
    metadata: Dict[str, Any] = field(default_factory=dict)


class BaseSolver(ABC):
    """Abstract base class for all route optimization solvers.

    Provides input validation, skill-matching helpers, and route metric
    calculation. Subclasses must implement the ``solve`` method.

    Args:
        work_orders: List of work order dicts. Each must contain at minimum:
            ``id``, ``property_id``, ``lat``, ``lng``, ``priority``,
            ``required_skills`` (list[str]), ``duration_minutes`` (int),
            ``time_window_start`` (datetime), ``time_window_end`` (datetime).
        technicians: List of technician dicts. Each must contain:
            ``id``, ``name``, ``skills`` (list[str]), ``home_lat``,
            ``home_lng``, ``max_hours`` (float), ``shift_start`` (datetime),
            ``shift_end`` (datetime).
        distance_matrix: Pre-computed NxN distance matrix (miles). Index 0..T-1
            are technician home bases; T..T+W-1 are work order locations.
        config: Optional solver configuration overrides.

    Raises:
        ValueError: If inputs fail validation.
    """

    # Required keys for input validation
    REQUIRED_WORK_ORDER_KEYS: Set[str] = {
        "id",
        "property_id",
        "lat",
        "lng",
        "priority",
        "required_skills",
        "duration_minutes",
        "time_window_start",
        "time_window_end",
    }
    REQUIRED_TECHNICIAN_KEYS: Set[str] = {
        "id",
        "name",
        "skills",
        "home_lat",
        "home_lng",
        "max_hours",
        "shift_start",
        "shift_end",
    }

    def __init__(
        self,
        work_orders: List[Dict[str, Any]],
        technicians: List[Dict[str, Any]],
        distance_matrix: List[List[float]],
        config: Optional[Dict[str, Any]] = None,
    ) -> None:
        self.work_orders = work_orders
        self.technicians = technicians
        self.distance_matrix = distance_matrix
        self.config = config or {}
        self._validate_inputs()

    @abstractmethod
    def solve(self) -> OptimizationResult:
        """Run the optimization algorithm and return routes.

        Returns:
            OptimizationResult with assigned routes and metrics.
        """

    # ------------------------------------------------------------------
    # Validation
    # ------------------------------------------------------------------

    def _validate_inputs(self) -> None:
        """Validate that all required fields are present and consistent.

        Raises:
            ValueError: On missing fields, empty inputs, or matrix size mismatch.
        """
        if not self.work_orders:
            raise ValueError("work_orders must not be empty.")
        if not self.technicians:
            raise ValueError("technicians must not be empty.")

        for idx, wo in enumerate(self.work_orders):
            missing = self.REQUIRED_WORK_ORDER_KEYS - set(wo.keys())
            if missing:
                raise ValueError(
                    f"Work order at index {idx} (id={wo.get('id', 'UNKNOWN')}) "
                    f"missing required keys: {missing}"
                )

        for idx, tech in enumerate(self.technicians):
            missing = self.REQUIRED_TECHNICIAN_KEYS - set(tech.keys())
            if missing:
                raise ValueError(
                    f"Technician at index {idx} (id={tech.get('id', 'UNKNOWN')}) "
                    f"missing required keys: {missing}"
                )

        expected_size = len(self.technicians) + len(self.work_orders)
        if len(self.distance_matrix) != expected_size:
            raise ValueError(
                f"Distance matrix has {len(self.distance_matrix)} rows but "
                f"expected {expected_size} (technicians={len(self.technicians)}, "
                f"work_orders={len(self.work_orders)})."
            )
        for row_idx, row in enumerate(self.distance_matrix):
            if len(row) != expected_size:
                raise ValueError(
                    f"Distance matrix row {row_idx} has {len(row)} columns "
                    f"but expected {expected_size}."
                )

        logger.info(
            "Input validation passed: %d work orders, %d technicians, "
            "%dx%d distance matrix.",
            len(self.work_orders),
            len(self.technicians),
            expected_size,
            expected_size,
        )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _check_skill_match(
        self, technician: Dict[str, Any], work_order: Dict[str, Any]
    ) -> bool:
        """Check whether a technician has every skill a work order requires.

        Args:
            technician: Technician dict with ``skills`` list.
            work_order: Work order dict with ``required_skills`` list.

        Returns:
            True if the technician possesses all required skills.
        """
        required = set(work_order.get("required_skills", []))
        available = set(technician.get("skills", []))
        return required.issubset(available)

    def _calculate_route_metrics(
        self, route_stops: List[RouteStop]
    ) -> Dict[str, float]:
        """Calculate aggregate metrics for an ordered list of route stops.

        Computes total travel distance and total travel duration by summing
        the per-stop values that were set during route construction.

        Args:
            route_stops: Ordered list of ``RouteStop`` objects.

        Returns:
            Dict with keys ``total_distance`` (miles) and
            ``total_duration`` (minutes).
        """
        total_distance = sum(stop.travel_distance for stop in route_stops)
        total_duration = sum(stop.travel_duration for stop in route_stops)
        return {
            "total_distance": round(total_distance, 2),
            "total_duration": round(total_duration, 2),
        }

    def _get_priority_value(self, priority: str) -> int:
        """Map a priority label to a numeric sort value (lower = more urgent).

        Args:
            priority: One of ``emergency``, ``high``, ``medium``, ``low``.

        Returns:
            Integer sort key.
        """
        priority_map = {
            "emergency": 0,
            "high": 1,
            "medium": 2,
            "low": 3,
        }
        return priority_map.get(priority.lower(), 99)

    def _timed_solve(self, solve_fn) -> OptimizationResult:
        """Execute a solve function and record wall-clock time.

        Args:
            solve_fn: Callable that returns an ``OptimizationResult``.

        Returns:
            The ``OptimizationResult`` with ``solve_time_seconds`` populated.
        """
        start = time.perf_counter()
        result = solve_fn()
        elapsed = time.perf_counter() - start
        result.solve_time_seconds = round(elapsed, 4)
        logger.info(
            "Solver %s completed in %.4f seconds. "
            "Routes: %d, Unassigned: %d, Total distance: %.2f mi.",
            result.algorithm,
            result.solve_time_seconds,
            len(result.routes),
            len(result.unassigned_orders),
            result.total_distance,
        )
        return result
