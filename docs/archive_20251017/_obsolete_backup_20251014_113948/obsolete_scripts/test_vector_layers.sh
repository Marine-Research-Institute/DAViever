#!/bin/bash

cd /var/www/marbefes-bbt
sudo -u www-data /var/www/marbefes-bbt/venv/bin/python << 'PYEOF'
import sys
sys.path.insert(0, '/var/www/marbefes-bbt')
sys.path.insert(0, '/var/www/marbefes-bbt/src')

print("Testing vector layer loading...")
print("=" * 60)

from emodnet_viewer.utils.vector_loader import vector_loader, get_vector_layer_geojson

# Check loaded layers
layers = vector_loader.layers
print(f"\nLoaded {len(layers)} vector layers:")
for layer in layers:
    print(f"\n  Layer ID: {layer.layer_id}")
    print(f"  Display name: {layer.display_name}")
    print(f"  Source: {layer.source_file}/{layer.layer_name}")
    print(f"  Features: {layer.feature_count}")

# Test getting GeoJSON
print("\n" + "=" * 60)
print("Testing GeoJSON retrieval...")

test_ids = ["BBts.gpkg/merged", "merged", "BBts.gpkg_merged"]
for test_id in test_ids:
    print(f"\nTrying ID: '{test_id}'")
    geojson = get_vector_layer_geojson(test_id)
    if geojson:
        print(f"  ✓ SUCCESS - {len(geojson.get('features', []))} features")
    else:
        print(f"  ✗ FAILED - not found")

print("\n" + "=" * 60)
PYEOF
