"""
Solver implementations for the Route Optimization Engine.

This package contains multiple solver strategies for the vehicle routing
problem, each with different trade-offs between solution quality and
computation time.
"""

from optimization.solvers.base_solver import BaseSolver, OptimizationResult
from optimization.solvers.genetic_solver import GeneticSolver
from optimization.solvers.greedy_solver import GreedySolver
from optimization.solvers.vrp_solver import VRPSolver

__all__ = [
    "BaseSolver",
    "OptimizationResult",
    "VRPSolver",
    "GreedySolver",
    "GeneticSolver",
]
