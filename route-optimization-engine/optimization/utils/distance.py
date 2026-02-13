"""
Distance and travel-time computation utilities.

Provides haversine distance calculations and matrix construction for use
by all route optimization solvers. All distances are in miles and all
durations are in minutes unless otherwise noted.
"""

from __future__ import annotations

import logging
import math
from typing import Dict, List, Tuple

logger = logging.getLogger(__name__)

# Earth radius in miles (mean radius)
_EARTH_RADIUS_MILES = 3958.8


def haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Compute the great-circle distance between two points on Earth.

    Uses the haversine formula. Accurate for most field-service routing
    distances; does not account for road networks or terrain.

    Args:
        lat1: Latitude of the first point in decimal degrees.
        lng1: Longitude of the first point in decimal degrees.
        lat2: Latitude of the second point in decimal degrees.
        lng2: Longitude of the second point in decimal degrees.

    Returns:
        Distance in miles.

    Examples:
        >>> round(haversine_distance(39.7392, -104.9903, 39.7506, -104.9998), 2)
        0.92
    """
    lat1_r, lng1_r = math.radians(lat1), math.radians(lng1)
    lat2_r, lng2_r = math.radians(lat2), math.radians(lng2)

    dlat = lat2_r - lat1_r
    dlng = lng2_r - lng1_r

    a = (
        math.sin(dlat / 2.0) ** 2
        + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlng / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    return _EARTH_RADIUS_MILES * c


def build_distance_matrix(
    locations: List[Dict[str, float]],
) -> List[List[float]]:
    """Build a symmetric NxN distance matrix from a list of locations.

    Each location must be a dict with ``lat`` and ``lng`` keys. The
    resulting matrix is indexed consistently with the input list order.

    Args:
        locations: List of location dicts, e.g.
            ``[{"lat": 39.74, "lng": -104.99}, ...]``.

    Returns:
        NxN list-of-lists with pairwise haversine distances in miles.
        Diagonal entries are 0.0.

    Raises:
        ValueError: If any location is missing ``lat`` or ``lng``.
    """
    n = len(locations)
    if n == 0:
        logger.warning("build_distance_matrix called with empty locations list.")
        return []

    for idx, loc in enumerate(locations):
        if "lat" not in loc or "lng" not in loc:
            raise ValueError(
                f"Location at index {idx} is missing 'lat' or 'lng': {loc}"
            )

    matrix: List[List[float]] = [[0.0] * n for _ in range(n)]

    for i in range(n):
        for j in range(i + 1, n):
            dist = haversine_distance(
                locations[i]["lat"],
                locations[i]["lng"],
                locations[j]["lat"],
                locations[j]["lng"],
            )
            dist = round(dist, 4)
            matrix[i][j] = dist
            matrix[j][i] = dist

    logger.info("Built %dx%d distance matrix for %d locations.", n, n, n)
    return matrix


def build_duration_matrix(
    distance_matrix: List[List[float]],
    avg_speed_mph: float = 30.0,
) -> List[List[float]]:
    """Convert a distance matrix (miles) to a duration matrix (minutes).

    Assumes a constant average travel speed. For urban field-service
    routing, 30 mph is a reasonable default that accounts for city traffic,
    parking, and walking to the property.

    Args:
        distance_matrix: NxN matrix of distances in miles.
        avg_speed_mph: Average travel speed in miles per hour. Must be > 0.

    Returns:
        NxN matrix of travel durations in minutes.

    Raises:
        ValueError: If ``avg_speed_mph`` is not positive.
    """
    if avg_speed_mph <= 0:
        raise ValueError(f"avg_speed_mph must be positive, got {avg_speed_mph}.")

    duration_matrix: List[List[float]] = []
    for row in distance_matrix:
        duration_row = [round((d / avg_speed_mph) * 60.0, 2) for d in row]
        duration_matrix.append(duration_row)

    logger.debug("Built duration matrix with avg_speed_mph=%.1f.", avg_speed_mph)
    return duration_matrix


def estimate_travel_time(distance_miles: float, speed_mph: float = 30.0) -> float:
    """Estimate travel time for a single distance value.

    Args:
        distance_miles: Distance in miles (must be >= 0).
        speed_mph: Travel speed in miles per hour (must be > 0).

    Returns:
        Estimated travel time in minutes.

    Raises:
        ValueError: If ``distance_miles`` is negative or ``speed_mph``
            is not positive.
    """
    if distance_miles < 0:
        raise ValueError(f"distance_miles must be non-negative, got {distance_miles}.")
    if speed_mph <= 0:
        raise ValueError(f"speed_mph must be positive, got {speed_mph}.")

    return round((distance_miles / speed_mph) * 60.0, 2)
