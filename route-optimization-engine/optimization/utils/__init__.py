"""
Utility modules for the Route Optimization Engine.

Provides distance computation, constraint validation, and shared helpers
used across all solver implementations.
"""

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

__all__ = [
    "haversine_distance",
    "build_distance_matrix",
    "build_duration_matrix",
    "estimate_travel_time",
    "check_skill_match",
    "check_time_window",
    "check_daily_limit",
    "validate_route",
]
