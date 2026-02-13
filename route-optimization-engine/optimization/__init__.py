"""
Route Optimization Engine for Field Service Operations.

This package provides multiple optimization algorithms for routing field
technicians to properties for maintenance, inspections, and repairs. It
minimizes total travel distance and time while respecting operational
constraints including skill matching, time windows, and daily hour limits.

Solvers:
    - VRPSolver: Google OR-Tools Vehicle Routing Problem with Time Windows.
    - GreedySolver: Fast nearest-neighbor heuristic baseline.
    - GeneticSolver: Evolutionary algorithm for flexible optimization.

Usage::

    from optimization import VRPSolver, GreedySolver, GeneticSolver
    from optimization import OptimizationResult, TechnicianRoute, RouteStop

    solver = VRPSolver(work_orders, technicians, distance_matrix)
    result = solver.solve()
"""

from optimization.solvers.base_solver import (
    BaseSolver,
    OptimizationResult,
    RouteStop,
    TechnicianRoute,
)
from optimization.solvers.vrp_solver import VRPSolver
from optimization.solvers.greedy_solver import GreedySolver
from optimization.solvers.genetic_solver import GeneticSolver

__all__ = [
    "BaseSolver",
    "OptimizationResult",
    "RouteStop",
    "TechnicianRoute",
    "VRPSolver",
    "GreedySolver",
    "GeneticSolver",
]

__version__ = "1.0.0"
