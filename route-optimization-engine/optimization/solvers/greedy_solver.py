"""
Greedy nearest-neighbor heuristic solver for route optimization.

Provides a fast baseline solution by iteratively assigning the nearest
feasible work order to each technician. Useful for quick estimates,
warm-starting more sophisticated solvers, and benchmarking.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Set

from optimization.solvers.base_solver import (
    BaseSolver,
    OptimizationResult,
    RouteStop,
    TechnicianRoute,
)
from optimization.utils.constraints import check_daily_limit, check_skill_match
from optimization.utils.distance import estimate_travel_time

logger = logging.getLogger(__name__)


class GreedySolver(BaseSolver):
    """Nearest-neighbor greedy heuristic for field-service routing.

    Algorithm:
        1. Sort work orders by priority (emergency first, then high,
           medium, low).
        2. For each technician, starting from their home base, repeatedly
           select the nearest unassigned work order that satisfies:
           - Skill match
           - Time window feasibility
           - Daily hour limit
        3. Continue until no more feasible assignments exist for any
           technician.

    This solver is O(T * W^2) in the worst case, where T is the number
    of technicians and W is the number of work orders. It runs in
    milliseconds for typical field-service instances (< 100 orders).

    Config options:
        avg_speed_mph (float): Average travel speed. Default 30.
    """

    def solve(self) -> OptimizationResult:
        """Run the greedy nearest-neighbor solver.

        Returns:
            OptimizationResult with greedily constructed routes.
        """
        return self._timed_solve(self._solve_impl)

    def _solve_impl(self) -> OptimizationResult:
        """Internal solve logic."""
        num_technicians = len(self.technicians)
        num_orders = len(self.work_orders)
        avg_speed = self.config.get("avg_speed_mph", 30.0)

        logger.info(
            "GreedySolver starting: %d technicians, %d work orders.",
            num_technicians,
            num_orders,
        )

        # Sort work order indices by priority (most urgent first)
        sorted_wo_indices = sorted(
            range(num_orders),
            key=lambda i: self._get_priority_value(
                self.work_orders[i].get("priority", "low")
            ),
        )

        assigned: Set[int] = set()
        routes: List[TechnicianRoute] = []
        total_distance = 0.0
        total_duration = 0.0

        for v_idx, tech in enumerate(self.technicians):
            route = self._build_technician_route(
                v_idx, tech, sorted_wo_indices, assigned, avg_speed
            )
            total_distance += route.total_distance
            total_duration += route.total_duration
            routes.append(route)

        # Identify unassigned orders
        all_order_ids = [wo["id"] for wo in self.work_orders]
        unassigned = [all_order_ids[i] for i in range(num_orders) if i not in assigned]

        logger.info(
            "GreedySolver complete: %d assigned, %d unassigned, "
            "total_distance=%.2f mi.",
            len(assigned),
            len(unassigned),
            total_distance,
        )

        return OptimizationResult(
            routes=routes,
            total_distance=round(total_distance, 2),
            total_duration=round(total_duration, 2),
            unassigned_orders=unassigned,
            algorithm="GreedySolver",
            solve_time_seconds=0.0,
            metadata={
                "num_vehicles_used": sum(1 for r in routes if len(r.stops) > 0),
            },
        )

    def _build_technician_route(
        self,
        v_idx: int,
        tech: Dict[str, Any],
        sorted_wo_indices: List[int],
        assigned: Set[int],
        avg_speed: float,
    ) -> TechnicianRoute:
        """Greedily build a route for one technician.

        Starting from the technician's home depot, repeatedly finds the
        nearest unassigned, feasible work order and appends it.

        Args:
            v_idx: Technician index (0-based).
            tech: Technician dict.
            sorted_wo_indices: Work order indices sorted by priority.
            assigned: Mutable set of already-assigned work order indices.
            avg_speed: Average travel speed (mph).

        Returns:
            Completed TechnicianRoute for this technician.
        """
        num_technicians = len(self.technicians)
        max_hours = tech.get("max_hours", 8.0)
        shift_start: datetime = tech.get("shift_start")
        shift_end: datetime = tech.get("shift_end")

        stops: List[RouteStop] = []
        route_distance = 0.0
        route_duration = 0.0
        route_work_time = 0.0
        current_node = v_idx  # Start at home depot
        current_time = shift_start
        used_hours = 0.0
        seq = 0

        # Keep iterating until we cannot add any more orders
        improved = True
        while improved:
            improved = False
            best_wo_idx: Optional[int] = None
            best_dist = float("inf")

            for wo_idx in sorted_wo_indices:
                if wo_idx in assigned:
                    continue

                wo = self.work_orders[wo_idx]
                wo_node = wo_idx + num_technicians

                # --- Skill check ---
                if not self._check_skill_match(tech, wo):
                    continue

                # --- Distance & travel time ---
                dist = self.distance_matrix[current_node][wo_node]
                travel_min = estimate_travel_time(dist, avg_speed)
                service_min = wo.get("duration_minutes", 0)
                additional_hours = (travel_min + service_min) / 60.0

                # --- Daily hour limit ---
                if not check_daily_limit(used_hours, max_hours, additional_hours):
                    continue

                # --- Time window feasibility ---
                proposed_arrival = current_time + timedelta(minutes=travel_min)
                tw_start = wo.get("time_window_start")
                tw_end = wo.get("time_window_end")

                if tw_start and proposed_arrival < tw_start:
                    # We can wait, but check if we can still fit
                    wait_min = (tw_start - proposed_arrival).total_seconds() / 60.0
                    total_added = (travel_min + wait_min + service_min) / 60.0
                    if not check_daily_limit(used_hours, max_hours, total_added):
                        continue
                    proposed_arrival = tw_start

                if tw_end and proposed_arrival > tw_end:
                    continue  # Cannot arrive in time

                # --- Shift end check ---
                proposed_departure = proposed_arrival + timedelta(minutes=service_min)
                if shift_end and proposed_departure > shift_end:
                    continue

                # --- Nearest neighbor selection ---
                # Within same priority tier, pick nearest; across tiers,
                # higher priority always wins.
                wo_priority = self._get_priority_value(wo.get("priority", "low"))
                if best_wo_idx is not None:
                    best_priority = self._get_priority_value(
                        self.work_orders[best_wo_idx].get("priority", "low")
                    )
                    # Prefer higher priority (lower value)
                    if wo_priority < best_priority:
                        best_wo_idx = wo_idx
                        best_dist = dist
                    elif wo_priority == best_priority and dist < best_dist:
                        best_wo_idx = wo_idx
                        best_dist = dist
                else:
                    best_wo_idx = wo_idx
                    best_dist = dist

            # Assign the best candidate
            if best_wo_idx is not None:
                improved = True
                assigned.add(best_wo_idx)

                wo = self.work_orders[best_wo_idx]
                wo_node = best_wo_idx + num_technicians
                dist = self.distance_matrix[current_node][wo_node]
                travel_min = estimate_travel_time(dist, avg_speed)
                service_min = wo.get("duration_minutes", 0)

                proposed_arrival = current_time + timedelta(minutes=travel_min)
                tw_start = wo.get("time_window_start")

                # Wait if arriving early
                if tw_start and proposed_arrival < tw_start:
                    proposed_arrival = tw_start

                departure = proposed_arrival + timedelta(minutes=service_min)

                stop = RouteStop(
                    work_order_id=wo["id"],
                    property_id=wo["property_id"],
                    lat=wo["lat"],
                    lng=wo["lng"],
                    sequence=seq,
                    arrival_time=proposed_arrival,
                    departure_time=departure,
                    travel_distance=round(dist, 2),
                    travel_duration=round(travel_min, 2),
                )
                stops.append(stop)

                route_distance += dist
                route_duration += travel_min
                route_work_time += service_min
                used_hours = (route_duration + route_work_time) / 60.0
                current_node = wo_node
                current_time = departure
                seq += 1

        total_hours = (route_duration + route_work_time) / 60.0
        utilization = (
            min(100.0, (total_hours / max_hours) * 100.0) if max_hours > 0 else 0.0
        )

        return TechnicianRoute(
            technician_id=tech["id"],
            technician_name=tech["name"],
            stops=stops,
            total_distance=round(route_distance, 2),
            total_duration=round(route_duration, 2),
            total_work_time=round(route_work_time, 2),
            utilization_percent=round(utilization, 1),
        )
