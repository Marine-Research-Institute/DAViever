#!/usr/bin/env python3
"""
Calculate bathymetry statistics for BBT areas using EMODnet data.

This script:
1. Loads BBT polygons from GPKG
2. Samples bathymetry data points across each BBT area using EMODnet WMS
3. Calculates min, max, and average depth
4. Saves results to JSON file

EMODnet Bathymetry: https://portal.emodnet-bathymetry.eu/
"""

import json
import datetime
from pathlib import Path

import geopandas as gpd
import numpy as np
import requests
from shapely.geometry import Point

# Output file
OUTPUT_FILE = Path("data/bbt_bathymetry_stats.json")


def get_bbt_areas(gpkg_path="data/vector/BBT.gpkg", layer="BBT areas"):
    """Load BBT areas from GPKG file."""
    print(f"📂 Loading BBT areas from {gpkg_path}...")
    gdf = gpd.read_file(gpkg_path, layer=layer)

    # Reproject to WGS84 if needed
    if gdf.crs.to_epsg() != 4326:
        print(f"🔄 Reprojecting from {gdf.crs} to EPSG:4326")
        gdf = gdf.to_crs("EPSG:4326")

    print(f"✅ Loaded {len(gdf)} BBT areas")
    return gdf


def get_depth_at_point(lon, lat):
    """Get depth at a specific point using EMODnet WMS GetFeatureInfo."""
    # Use a small bbox around the point
    buffer = 0.001  # ~100m
    bbox = f"{lon-buffer},{lat-buffer},{lon+buffer},{lat+buffer}"

    params = {
        'service': 'WMS',
        'version': '1.3.0',
        'request': 'GetFeatureInfo',
        'layers': 'emodnet:mean_atlas_land',
        'query_layers': 'emodnet:mean_atlas_land',
        'crs': 'EPSG:4326',
        'bbox': bbox,
        'width': 10,
        'height': 10,
        'i': 5,  # x pixel
        'j': 5,  # y pixel
        'info_format': 'application/json'
    }

    try:
        response = requests.get(
            "https://ows.emodnet-bathymetry.eu/wms",
            params=params,
            timeout=5
        )

        if response.status_code == 200:
            data = response.json()
            if 'features' in data and len(data['features']) > 0:
                properties = data['features'][0].get('properties', {})
                # Look for depth value (field name may vary)
                for key in ['GRAY_INDEX', 'depth', 'value', 'elevation']:
                    if key in properties:
                        value = properties[key]
                        if value is not None and value != 'null':
                            # Convert to positive depth if negative
                            return abs(float(value))

    except Exception:
        pass

    return None


def calculate_bathymetry_stats(gdf):
    """Calculate bathymetry statistics for each BBT using point sampling."""
    results = {}

    for idx, row in gdf.iterrows():
        name = row['Name']
        print(f"\n🔍 Processing: {name}")

        # Get bounds
        bounds = row.geometry.bounds  # (minx, miny, maxx, maxy)
        minx, miny, maxx, maxy = bounds

        # Create a grid of sample points
        num_samples = 25  # 25x25 = 625 points max
        x_points = np.linspace(minx, maxx, num_samples)
        y_points = np.linspace(miny, maxy, num_samples)

        depths = []
        sampled = 0

        for x in x_points:
            for y in y_points:
                point = Point(x, y)

                # Check if point is inside polygon
                if row.geometry.contains(point):
                    sampled += 1
                    # Query bathymetry at this point
                    depth = get_depth_at_point(x, y)
                    if depth is not None and depth > 0 and depth < 10000:  # Sanity check
                        depths.append(depth)

                    # Print progress every 50 points
                    if sampled % 50 == 0:
                        print(f"  📍 Sampled {sampled} points, {len(depths)} valid depths...")

        if depths:
            results[name] = {
                'min_depth_m': round(float(np.min(depths)), 1),
                'max_depth_m': round(float(np.max(depths)), 1),
                'avg_depth_m': round(float(np.mean(depths)), 1),
                'std_depth_m': round(float(np.std(depths)), 1),
                'sample_count': len(depths)
            }
            print(f"  ✅ Min: {results[name]['min_depth_m']}m, "
                  f"Max: {results[name]['max_depth_m']}m, "
                  f"Avg: {results[name]['avg_depth_m']}m ({len(depths)} samples)")
        else:
            print(f"  ⚠️ No valid depth data found")
            results[name] = None

    return results


def main():
    """Main execution function."""
    print("🌊 BBT Bathymetry Statistics Calculator")
    print("=" * 60)

    # Load BBT areas
    gdf = get_bbt_areas()

    # Calculate bathymetry statistics
    print("\n📊 Calculating bathymetry statistics (this may take a few minutes)...")
    results = calculate_bathymetry_stats(gdf)

    # Add metadata
    output_data = {
        'metadata': {
            'source': 'EMODnet Bathymetry',
            'url': 'https://portal.emodnet-bathymetry.eu/',
            'method': 'Point sampling across BBT polygons using WMS GetFeatureInfo',
            'unit': 'meters below sea level',
            'generated': datetime.datetime.now().isoformat()
        },
        'statistics': results
    }

    # Save to JSON
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output_data, f, indent=2)

    print(f"\n✅ Results saved to: {OUTPUT_FILE}")
    print(f"📁 File size: {OUTPUT_FILE.stat().st_size} bytes")

    # Print summary
    print("\n📋 Summary:")
    valid_count = sum(1 for v in results.values() if v is not None)
    print(f"  - Total BBT areas: {len(results)}")
    print(f"  - With bathymetry data: {valid_count}")
    print(f"  - Without data: {len(results) - valid_count}")

    print("\n🎉 Done!")


if __name__ == "__main__":
    main()
