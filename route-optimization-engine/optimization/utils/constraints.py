"""
Constraint validation utilities for route optimization.

Provides functions to verify that candidate route assignments satisfy
operational constraints: skill matching, time windows, daily hour limits,
and comprehensive route-level validation.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Dict, List, Set

logger = logging.getLogger(__name__)


def check_skill_match(
    technician_skills: List[str] | Set[str],
    required_skills: List[str] | Set[str],
) -> bool:
    """Check whether a technician possesses all required skills.

    Args:
        technician_skills: Skills the technician has.
        required_skills: Skills the work order requires.

    Returns:
        True if every required skill is in the technician's skill set.

    Examples:
        >>> check_skill_match(["electrical", "plumbing"], ["plumbing"])
        True
        >>> check_skill_match(["plumbing"], ["electrical", "plumbing"])
        False
    """
    return set(required_skills).issubset(set(technician_skills))


def check_time_window(
    arrival_time: datetime,
    window_start: datetime,
    window_end: datetime,
) -> bool:
    """Check whether an arrival time falls within an acceptable window.

    The arrival is considered valid if it is at or after the window start
    and at or before the window end.

    Args:
        arrival_time: Proposed arrival time.
        window_start: Earliest acceptable arrival.
        window_end: Latest acceptable arrival.

    Returns:
        True if the arrival is within the time window (inclusive).

    Raises:
        ValueError: If ``window_start`` is after ``window_end``.
    """
    if window_start > window_end:
        raise ValueError(
            f"window_start ({window_start}) is after window_end ({window_end})."
        )
    return window_start <= arrival_time <= window_end


def check_daily_limit(
    current_hours: float,
    max_hours: float,
    additional_hours: float,
) -> bool:
    """Check whether adding more work would exceed the daily hour limit.

    Args:
        current_hours: Hours already committed for the day.
        max_hours: Maximum allowed working hours.
        additional_hours: Hours the candidate work order would add
            (including travel and service time).

    Returns:
        True if the total would remain at or below the limit.

    Raises:
        ValueError: If any argument is negative.
    """
    if current_hours < 0 or max_hours < 0 or additional_hours < 0:
        raise ValueError(
            "All arguments must be non-negative. Got "
            f"current_hours={current_hours}, max_hours={max_hours}, "
            f"additional_hours={additional_hours}."
        )
    return (current_hours + additional_hours) <= max_hours


def validate_route(
    route: List[Dict[str, Any]],
    technician: Dict[str, Any],
    work_orders: Dict[str, Dict[str, Any]],
) -> List[str]:
    """Perform comprehensive validation of a complete technician route.

    Checks skill matching, time window compliance, and daily hour limit
    for every stop in the route. Returns a list of human-readable
    violation descriptions. An empty list means the route is fully valid.

    Args:
        route: Ordered list of route stop dicts, each containing at
            minimum ``work_order_id``, ``arrival_time``, and
            ``departure_time``.
        technician: Technician dict with ``id``, ``name``, ``skills``,
            ``max_hours``, ``shift_start``, ``shift_end``.
        work_orders: Mapping from work order ID to work order dict. Each
            work order must include ``required_skills``,
            ``time_window_start``, ``time_window_end``,
            ``duration_minutes``.

    Returns:
        List of violation description strings. Empty if valid.
    """
    violations: List[str] = []
    tech_id = technician.get("id", "UNKNOWN")
    tech_skills = set(technician.get("skills", []))
    max_hours = technician.get("max_hours", 8.0)
    shift_start = technician.get("shift_start")
    shift_end = technician.get("shift_end")

    cumulative_minutes = 0.0

    for stop_idx, stop in enumerate(route):
        wo_id = stop.get("work_order_id", "UNKNOWN")
        wo = work_orders.get(wo_id)

        if wo is None:
            violations.append(
                f"Stop {stop_idx}: work order '{wo_id}' not found in work_orders map."
            )
            continue

        # --- Skill match ---
        required_skills = set(wo.get("required_skills", []))
        if not required_skills.issubset(tech_skills):
            missing = required_skills - tech_skills
            violations.append(
                f"Stop {stop_idx} (WO {wo_id}): technician '{tech_id}' "
                f"missing skills {missing}."
            )

        # --- Time window ---
        arrival = stop.get("arrival_time")
        tw_start = wo.get("time_window_start")
        tw_end = wo.get("time_window_end")

        if arrival is not None and tw_start is not None and tw_end is not None:
            if not check_time_window(arrival, tw_start, tw_end):
                violations.append(
                    f"Stop {stop_idx} (WO {wo_id}): arrival {arrival} "
                    f"outside window [{tw_start}, {tw_end}]."
                )

        # --- Shift boundary ---
        if arrival is not None and shift_start is not None:
            if arrival < shift_start:
                violations.append(
                    f"Stop {stop_idx} (WO {wo_id}): arrival {arrival} is "
                    f"before shift start {shift_start}."
                )

        departure = stop.get("departure_time")
        if departure is not None and shift_end is not None:
            if departure > shift_end:
                violations.append(
                    f"Stop {stop_idx} (WO {wo_id}): departure {departure} is "
                    f"after shift end {shift_end}."
                )

        # --- Accumulate work time ---
        duration_min = wo.get("duration_minutes", 0)
        travel_min = stop.get("travel_duration", 0.0)
        cumulative_minutes += duration_min + travel_min

    # --- Daily hour limit ---
    cumulative_hours = cumulative_minutes / 60.0
    if cumulative_hours > max_hours:
        violations.append(
            f"Technician '{tech_id}' total route time {cumulative_hours:.2f}h "
            f"exceeds max_hours {max_hours}h."
        )

    if violations:
        logger.warning(
            "Route validation for technician '%s' found %d violation(s).",
            tech_id,
            len(violations),
        )
    else:
        logger.debug("Route validation for technician '%s' passed.", tech_id)

    return violations
