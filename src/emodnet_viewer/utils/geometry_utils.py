"""
Geometry utility functions for area analysis
MarineSABRES Demonstration Area Tool
"""

import math
import json
from typing import Dict, List, Tuple, Any, Optional


def validate_geojson_geometry(geometry: Dict[str, Any]) -> bool:
    """
    Validate GeoJSON geometry structure

    Args:
        geometry: GeoJSON geometry dictionary

    Returns:
        True if valid, False otherwise
    """
    if not isinstance(geometry, dict):
        return False

    if 'type' not in geometry or 'coordinates' not in geometry:
        return False

    valid_types = ['Point', 'LineString', 'Polygon', 'MultiPoint',
                   'MultiLineString', 'MultiPolygon']

    if geometry['type'] not in valid_types:
        return False

    # Basic structure validation
    coords = geometry['coordinates']
    if not isinstance(coords, list):
        return False

    return True


def haversine_distance(coord1: Tuple[float, float], coord2: Tuple[float, float]) -> float:
    """
    Calculate distance between two coordinates using Haversine formula

    Args:
        coord1: (longitude, latitude) tuple
        coord2: (longitude, latitude) tuple

    Returns:
        Distance in kilometers
    """
    lon1, lat1 = coord1
    lon2, lat2 = coord2

    # Convert to radians
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    # Haversine formula
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2)
    c = 2 * math.asin(math.sqrt(a))

    # Earth radius in kilometers
    r = 6371.0

    return c * r


def calculate_polygon_area_simple(coordinates: List[List[Tuple[float, float]]]) -> float:
    """
    Calculate polygon area using simple Spherical Excess formula
    Suitable for small to medium-sized polygons

    Args:
        coordinates: List of coordinate rings [[outer_ring], [hole1], ...]

    Returns:
        Area in square kilometers
    """
    if not coordinates or not coordinates[0]:
        return 0.0

    # Earth radius in kilometers
    R = 6371.0

    outer_ring = coordinates[0]

    # Calculate area using shoelace formula approximation
    # (Good enough for small areas, doesn't require external libraries)
    area = 0.0
    n = len(outer_ring)

    for i in range(n - 1):
        lon1, lat1 = outer_ring[i]
        lon2, lat2 = outer_ring[i + 1]

        # Convert to radians
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        dlon = math.radians(lon2 - lon1)

        # Approximate area element
        area += dlon * (2 + math.sin(lat1_rad) + math.sin(lat2_rad))

    area = abs(area) * R * R / 2.0

    # Subtract holes if present
    for hole in coordinates[1:]:
        hole_area = calculate_polygon_area_simple([hole])
        area -= hole_area

    return area


def calculate_polygon_perimeter(coordinates: List[Tuple[float, float]]) -> float:
    """
    Calculate polygon perimeter using Haversine distance

    Args:
        coordinates: List of (longitude, latitude) tuples forming the polygon

    Returns:
        Perimeter in kilometers
    """
    if not coordinates or len(coordinates) < 2:
        return 0.0

    perimeter = 0.0
    n = len(coordinates)

    for i in range(n - 1):
        perimeter += haversine_distance(coordinates[i], coordinates[i + 1])

    return perimeter


def calculate_centroid(coordinates: List[Tuple[float, float]]) -> Tuple[float, float]:
    """
    Calculate centroid of a polygon

    Args:
        coordinates: List of (longitude, latitude) tuples

    Returns:
        (longitude, latitude) of centroid
    """
    if not coordinates:
        return (0.0, 0.0)

    # Simple arithmetic mean (good enough for small polygons)
    lon_sum = sum(coord[0] for coord in coordinates)
    lat_sum = sum(coord[1] for coord in coordinates)
    n = len(coordinates)

    return (lon_sum / n, lat_sum / n)


def calculate_bounds(coordinates: List[Tuple[float, float]]) -> Tuple[float, float, float, float]:
    """
    Calculate bounding box of coordinates

    Args:
        coordinates: List of (longitude, latitude) tuples

    Returns:
        (minX, minY, maxX, maxY) tuple
    """
    if not coordinates:
        return (0.0, 0.0, 0.0, 0.0)

    lons = [coord[0] for coord in coordinates]
    lats = [coord[1] for coord in coordinates]

    return (min(lons), min(lats), max(lons), max(lats))


def calculate_circle_area(center: Tuple[float, float], radius_m: float) -> float:
    """
    Calculate area of a circle given center and radius

    Args:
        center: (longitude, latitude) of circle center
        radius_m: Radius in meters

    Returns:
        Area in square kilometers
    """
    # Convert radius to kilometers
    radius_km = radius_m / 1000.0

    # Simple circular area
    area_km2 = math.pi * radius_km ** 2

    return area_km2


def calculate_area_statistics(geometry: Dict[str, Any]) -> Dict[str, Any]:
    """
    Calculate comprehensive area statistics for a GeoJSON geometry

    Args:
        geometry: GeoJSON geometry dictionary

    Returns:
        Dictionary with area, perimeter, centroid, and bounds
    """
    geom_type = geometry.get('type')
    coords = geometry.get('coordinates')

    if geom_type == 'Polygon':
        # Polygon: coordinates = [[outer_ring], [hole1], ...]
        outer_ring = coords[0]

        area = calculate_polygon_area_simple(coords)
        perimeter = calculate_polygon_perimeter(outer_ring)
        centroid = calculate_centroid(outer_ring)
        bounds = calculate_bounds(outer_ring)

    elif geom_type == 'MultiPolygon':
        # MultiPolygon: coordinates = [[[outer_ring], [hole1], ...], ...]
        total_area = 0.0
        total_perimeter = 0.0
        all_coords = []

        for polygon in coords:
            outer_ring = polygon[0]
            total_area += calculate_polygon_area_simple(polygon)
            total_perimeter += calculate_polygon_perimeter(outer_ring)
            all_coords.extend(outer_ring)

        area = total_area
        perimeter = total_perimeter
        centroid = calculate_centroid(all_coords)
        bounds = calculate_bounds(all_coords)

    elif geom_type == 'Point':
        # Point: coordinates = [lon, lat]
        area = 0.0
        perimeter = 0.0
        centroid = (coords[0], coords[1])
        bounds = (coords[0], coords[1], coords[0], coords[1])

    elif geom_type == 'LineString':
        # LineString: coordinates = [[lon, lat], ...]
        area = 0.0
        perimeter = calculate_polygon_perimeter(coords)
        centroid = calculate_centroid(coords)
        bounds = calculate_bounds(coords)

    else:
        # Unsupported geometry type
        area = 0.0
        perimeter = 0.0
        centroid = (0.0, 0.0)
        bounds = (0.0, 0.0, 0.0, 0.0)

    return {
        'area': round(area, 2),
        'perimeter': round(perimeter, 2),
        'centroid': [round(centroid[0], 6), round(centroid[1], 6)],
        'bounds': [round(b, 6) for b in bounds]
    }


def point_in_polygon(point: Tuple[float, float], polygon: List[Tuple[float, float]]) -> bool:
    """
    Check if a point is inside a polygon using ray casting algorithm

    Args:
        point: (longitude, latitude) tuple
        polygon: List of (longitude, latitude) tuples forming the polygon

    Returns:
        True if point is inside polygon, False otherwise
    """
    x, y = point
    n = len(polygon)
    inside = False

    p1x, p1y = polygon[0]
    for i in range(1, n + 1):
        p2x, p2y = polygon[i % n]

        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x

                    if p1x == p2x or x <= xinters:
                        inside = not inside

        p1x, p1y = p2x, p2y

    return inside


def bbox_intersects(bbox1: Tuple[float, float, float, float],
                    bbox2: Tuple[float, float, float, float]) -> bool:
    """
    Check if two bounding boxes intersect

    Args:
        bbox1: (minX, minY, maxX, maxY) tuple
        bbox2: (minX, minY, maxX, maxY) tuple

    Returns:
        True if bounding boxes intersect, False otherwise
    """
    min_x1, min_y1, max_x1, max_y1 = bbox1
    min_x2, min_y2, max_x2, max_y2 = bbox2

    return not (max_x1 < min_x2 or max_x2 < min_x1 or
                max_y1 < min_y2 or max_y2 < min_y1)


def calculate_overlap_percentage(geom_bounds: Tuple[float, float, float, float],
                                 site_bounds: Tuple[float, float, float, float]) -> float:
    """
    Calculate approximate overlap percentage between two bounding boxes

    Args:
        geom_bounds: (minX, minY, maxX, maxY) of selected geometry
        site_bounds: (minX, minY, maxX, maxY) of research site

    Returns:
        Overlap percentage (0-100)
    """
    # Calculate intersection bounds
    inter_min_x = max(geom_bounds[0], site_bounds[0])
    inter_min_y = max(geom_bounds[1], site_bounds[1])
    inter_max_x = min(geom_bounds[2], site_bounds[2])
    inter_max_y = min(geom_bounds[3], site_bounds[3])

    # Check if there's intersection
    if inter_min_x >= inter_max_x or inter_min_y >= inter_max_y:
        return 0.0

    # Calculate areas (approximation using rectangular bounds)
    geom_width = geom_bounds[2] - geom_bounds[0]
    geom_height = geom_bounds[3] - geom_bounds[1]
    geom_area = geom_width * geom_height

    inter_width = inter_max_x - inter_min_x
    inter_height = inter_max_y - inter_min_y
    inter_area = inter_width * inter_height

    # Calculate percentage
    if geom_area > 0:
        overlap_pct = (inter_area / geom_area) * 100
        return round(overlap_pct, 2)

    return 0.0
