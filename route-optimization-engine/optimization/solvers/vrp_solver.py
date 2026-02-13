"""
Google OR-Tools Vehicle Routing Problem with Time Windows (VRPTW) solver.

This solver provides the highest-quality solutions by formulating the
field-service routing problem as a constrained VRP and solving it with
OR-Tools' industrial-grade optimization engine. It supports time windows,
capacity constraints, skill matching, and priority-based penalty costs.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from optimization.solvers.base_solver import (
    BaseSolver,
    OptimizationResult,
    RouteStop,
    TechnicianRoute,
)
from optimization.utils.constraints import check_skill_match
from optimization.utils.distance import estimate_travel_time

logger = logging.getLogger(__name__)

# Priority-based penalties for dropping (not serving) a work order.
# Higher values make the solver try harder to include the order.
_PRIORITY_DROP_PENALTIES: Dict[str, int] = {
    "emergency": 10_000,
    "high": 5_000,
    "medium": 1_000,
    "low": 100,
}

# Scale factor: OR-Tools works with integers, so we multiply distances
# (in miles) by this factor to preserve precision.
_DISTANCE_SCALE = 1000

# Scale factor for time: convert minutes to integer units.
_TIME_SCALE = 1


class VRPSolver(BaseSolver):
    """Vehicle Routing Problem solver using Google OR-Tools.

    Formulates the field-service routing problem as a Capacitated Vehicle
    Routing Problem with Time Windows (CVRPTW) and solves it using
    OR-Tools' constraint programming engine.

    Config options (passed via ``config`` dict):
        time_limit_seconds (int): Max solver time. Default 120.
        avg_speed_mph (float): Average travel speed. Default 30.
        first_solution_strategy (str): OR-Tools first-solution strategy
            name. Default ``"PATH_CHEAPEST_ARC"``.
        metaheuristic (str): Local search metaheuristic name.
            Default ``"GUIDED_LOCAL_SEARCH"``.
    """

    def solve(self) -> OptimizationResult:
        """Run the OR-Tools VRPTW solver.

        Returns:
            OptimizationResult with optimized routes.

        Raises:
            ImportError: If ``ortools`` is not installed.
            RuntimeError: If OR-Tools fails to find any solution.
        """
        return self._timed_solve(self._solve_impl)

    def _solve_impl(self) -> OptimizationResult:
        """Internal solve implementation wrapped by _timed_solve."""
        try:
            from ortools.constraint_solver import pywrapcp, routing_enums_pb2
        except ImportError as exc:
            raise ImportError(
                "Google OR-Tools is required for VRPSolver. "
                "Install with: pip install ortools"
            ) from exc

        num_technicians = len(self.technicians)
        num_orders = len(self.work_orders)
        num_nodes = num_technicians + num_orders
        avg_speed = self.config.get("avg_speed_mph", 30.0)
        time_limit = self.config.get("time_limit_seconds", 120)

        logger.info(
            "VRPSolver starting: %d technicians, %d work orders, "
            "time_limit=%ds, avg_speed=%.0f mph.",
            num_technicians,
            num_orders,
            time_limit,
            avg_speed,
        )

        # -----------------------------------------------------------------
        # Build skill-feasibility mask: which technician can do which order
        # -----------------------------------------------------------------
        feasible = self._build_feasibility_mask()

        # -----------------------------------------------------------------
        # OR-Tools data model
        # -----------------------------------------------------------------
        # Nodes 0..T-1 are technician depots, T..T+W-1 are work orders.
        # Each vehicle starts and ends at its own depot.
        starts = list(range(num_technicians))
        ends = list(range(num_technicians))

        manager = pywrapcp.RoutingIndexManager(num_nodes, num_technicians, starts, ends)
        routing = pywrapcp.RoutingModel(manager)

        # -----------------------------------------------------------------
        # Distance callback
        # -----------------------------------------------------------------
        def distance_callback(from_index: int, to_index: int) -> int:
            from_node = manager.IndexToNode(from_index)
            to_node = manager.IndexToNode(to_index)
            return int(self.distance_matrix[from_node][to_node] * _DISTANCE_SCALE)

        transit_cb_index = routing.RegisterTransitCallback(distance_callback)
        routing.SetArcCostEvaluatorOfAllVehicles(transit_cb_index)

        # -----------------------------------------------------------------
        # Time callback and time dimension
        # -----------------------------------------------------------------
        def time_callback(from_index: int, to_index: int) -> int:
            from_node = manager.IndexToNode(from_index)
            to_node = manager.IndexToNode(to_index)
            dist = self.distance_matrix[from_node][to_node]
            travel_min = estimate_travel_time(dist, avg_speed)
            # Add service time at the destination if it is a work order
            service_min = 0
            if to_node >= num_technicians:
                wo_idx = to_node - num_technicians
                service_min = self.work_orders[wo_idx].get("duration_minutes", 0)
            return int(travel_min + service_min)

        time_cb_index = routing.RegisterTransitCallback(time_callback)

        # Max daily minutes across all technicians
        max_daily_minutes = int(
            max(t.get("max_hours", 8.0) for t in self.technicians) * 60
        )

        routing.AddDimension(
            time_cb_index,
            max_daily_minutes,  # slack: allow waiting at a location
            max_daily_minutes,  # max cumulative time per vehicle
            False,  # don't force start at time zero
            "Time",
        )
        time_dimension = routing.GetDimensionOrDie("Time")

        # Per-vehicle capacity constraint
        for v_idx in range(num_technicians):
            tech_max_min = int(self.technicians[v_idx].get("max_hours", 8.0) * 60)
            end_index = routing.End(v_idx)
            time_dimension.CumulVar(end_index).SetMax(tech_max_min)

        # -----------------------------------------------------------------
        # Time windows for each work order node
        # -----------------------------------------------------------------
        for wo_idx, wo in enumerate(self.work_orders):
            node = wo_idx + num_technicians
            index = manager.NodeToIndex(node)

            tw_start = wo.get("time_window_start")
            tw_end = wo.get("time_window_end")
            shift_ref = self.technicians[0].get("shift_start", tw_start)

            if tw_start and tw_end and shift_ref:
                start_min = max(0, int((tw_start - shift_ref).total_seconds() / 60))
                end_min = int((tw_end - shift_ref).total_seconds() / 60)
                time_dimension.CumulVar(index).SetRange(start_min, end_min)

        # Depot time windows (shift boundaries)
        for v_idx in range(num_technicians):
            tech = self.technicians[v_idx]
            shift_ref = tech.get("shift_start")
            shift_end = tech.get("shift_end")

            start_index = routing.Start(v_idx)
            end_index = routing.End(v_idx)

            if shift_ref and shift_end:
                shift_len_min = int((shift_end - shift_ref).total_seconds() / 60)
                time_dimension.CumulVar(start_index).SetRange(0, shift_len_min)
                time_dimension.CumulVar(end_index).SetRange(0, shift_len_min)

        # -----------------------------------------------------------------
        # Skill-based disallowed assignments
        # -----------------------------------------------------------------
        for wo_idx in range(num_orders):
            node = wo_idx + num_technicians
            index = manager.NodeToIndex(node)
            allowed_vehicles: List[int] = []
            for v_idx in range(num_technicians):
                if feasible[v_idx][wo_idx]:
                    allowed_vehicles.append(v_idx)
            if allowed_vehicles:
                routing.VehicleVar(index).SetValues(allowed_vehicles)

        # -----------------------------------------------------------------
        # Allow dropping work orders with priority-based penalties
        # -----------------------------------------------------------------
        for wo_idx, wo in enumerate(self.work_orders):
            node = wo_idx + num_technicians
            index = manager.NodeToIndex(node)
            priority = wo.get("priority", "medium").lower()
            penalty = _PRIORITY_DROP_PENALTIES.get(priority, 1000)
            routing.AddDisjunction([index], penalty)

        # -----------------------------------------------------------------
        # Search parameters
        # -----------------------------------------------------------------
        search_params = pywrapcp.DefaultRoutingSearchParameters()

        strategy_name = self.config.get("first_solution_strategy", "PATH_CHEAPEST_ARC")
        search_params.first_solution_strategy = getattr(
            routing_enums_pb2.FirstSolutionStrategy, strategy_name
        )

        meta_name = self.config.get("metaheuristic", "GUIDED_LOCAL_SEARCH")
        search_params.local_search_metaheuristic = getattr(
            routing_enums_pb2.LocalSearchMetaheuristic, meta_name
        )

        search_params.time_limit.FromSeconds(time_limit)
        search_params.log_search = False

        logger.info(
            "Solving with strategy=%s, metaheuristic=%s, time_limit=%ds.",
            strategy_name,
            meta_name,
            time_limit,
        )

        # -----------------------------------------------------------------
        # Solve
        # -----------------------------------------------------------------
        solution = routing.SolveWithParameters(search_params)

        if not solution:
            logger.warning("OR-Tools found no solution.")
            return OptimizationResult(
                routes=[],
                total_distance=0.0,
                total_duration=0.0,
                unassigned_orders=[wo["id"] for wo in self.work_orders],
                algorithm="VRPSolver",
                solve_time_seconds=0.0,
                metadata={"status": "NO_SOLUTION"},
            )

        # -----------------------------------------------------------------
        # Parse solution
        # -----------------------------------------------------------------
        return self._parse_solution(
            manager, routing, solution, avg_speed, num_technicians
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _build_feasibility_mask(self) -> List[List[bool]]:
        """Build a technician x work_order feasibility matrix.

        Returns:
            2D list where ``mask[v][w]`` is True if technician v can
            perform work order w.
        """
        mask: List[List[bool]] = []
        for tech in self.technicians:
            row = [
                check_skill_match(tech.get("skills", []), wo.get("required_skills", []))
                for wo in self.work_orders
            ]
            mask.append(row)
        return mask

    def _parse_solution(
        self,
        manager,
        routing,
        solution,
        avg_speed: float,
        num_technicians: int,
    ) -> OptimizationResult:
        """Extract TechnicianRoute objects from the OR-Tools solution.

        Args:
            manager: RoutingIndexManager.
            routing: RoutingModel.
            solution: OR-Tools assignment solution.
            avg_speed: Average speed used for duration estimation.
            num_technicians: Number of vehicles/technicians.

        Returns:
            Populated OptimizationResult.
        """
        routes: List[TechnicianRoute] = []
        assigned_orders: set = set()
        total_distance = 0.0
        total_duration = 0.0
        time_dimension = routing.GetDimensionOrDie("Time")

        for v_idx in range(num_technicians):
            tech = self.technicians[v_idx]
            shift_start = tech.get(
                "shift_start",
                datetime.now().replace(hour=8, minute=0, second=0, microsecond=0),
            )
            max_hours = tech.get("max_hours", 8.0)

            stops: List[RouteStop] = []
            route_distance = 0.0
            route_duration = 0.0
            route_work_time = 0.0
            seq = 0

            index = routing.Start(v_idx)
            prev_node = manager.IndexToNode(index)
            index = solution.Value(routing.NextVar(index))

            while not routing.IsEnd(index):
                node = manager.IndexToNode(index)
                wo_idx = node - num_technicians

                if 0 <= wo_idx < len(self.work_orders):
                    wo = self.work_orders[wo_idx]
                    dist = self.distance_matrix[prev_node][node]
                    travel_min = estimate_travel_time(dist, avg_speed)
                    service_min = wo.get("duration_minutes", 0)

                    time_var = time_dimension.CumulVar(index)
                    arrival_min = solution.Value(time_var)
                    arrival_dt = shift_start + timedelta(minutes=arrival_min)
                    departure_dt = arrival_dt + timedelta(minutes=service_min)

                    stop = RouteStop(
                        work_order_id=wo["id"],
                        property_id=wo["property_id"],
                        lat=wo["lat"],
                        lng=wo["lng"],
                        sequence=seq,
                        arrival_time=arrival_dt,
                        departure_time=departure_dt,
                        travel_distance=round(dist, 2),
                        travel_duration=round(travel_min, 2),
                    )
                    stops.append(stop)
                    assigned_orders.add(wo["id"])

                    route_distance += dist
                    route_duration += travel_min
                    route_work_time += service_min
                    seq += 1

                prev_node = node
                index = solution.Value(routing.NextVar(index))

            total_hours = (route_duration + route_work_time) / 60.0
            utilization = (
                min(100.0, (total_hours / max_hours) * 100.0) if max_hours > 0 else 0.0
            )

            tech_route = TechnicianRoute(
                technician_id=tech["id"],
                technician_name=tech["name"],
                stops=stops,
                total_distance=round(route_distance, 2),
                total_duration=round(route_duration, 2),
                total_work_time=round(route_work_time, 2),
                utilization_percent=round(utilization, 1),
            )
            routes.append(tech_route)
            total_distance += route_distance
            total_duration += route_duration

        # Determine unassigned orders
        all_order_ids = {wo["id"] for wo in self.work_orders}
        unassigned = sorted(all_order_ids - assigned_orders)

        logger.info(
            "VRPSolver solution: %d routes, %d assigned, %d unassigned, "
            "total_distance=%.2f mi.",
            len(routes),
            len(assigned_orders),
            len(unassigned),
            total_distance,
        )

        return OptimizationResult(
            routes=routes,
            total_distance=round(total_distance, 2),
            total_duration=round(total_duration, 2),
            unassigned_orders=unassigned,
            algorithm="VRPSolver",
            solve_time_seconds=0.0,
            metadata={
                "status": "SOLUTION_FOUND",
                "num_vehicles_used": sum(1 for r in routes if len(r.stops) > 0),
            },
        )
