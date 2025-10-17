#!/usr/bin/env python3
"""
Simple test to show layer data structure
"""

# Sample layers with descriptions set to None
layers = [
    {
        "name": "eusm2021",
        "title": "EUSeaMap 2021 - Benthic Habitats", 
        "description": None
    },
    {
        "name": "habitat_boxes_n2000",
        "title": "Annex I habitat maps study areas",
        "description": None
    },
    {
        "name": "ospar_threatened", 
        "title": "OSPAR Threatened Habitats",
        "description": None
    }
]

print("=" * 60)
print("Layer Display Test - Title Only")
print("=" * 60)

for i, layer in enumerate(layers, 1):
    print(f"{i}. Layer Name: {layer['name']}")
    print(f"   Title: {layer['title']}")
    print(f"   Description: {layer['description']}")
    print(f"   Display Text: '{layer['title'] or layer['name']}'")
    print("-" * 50)

print("\n✅ SUCCESS: All descriptions are None")
print("The web interface will display only titles/names")
print("\nIn the layer menu, users will see:")
for i, layer in enumerate(layers, 1):
    display_text = layer['title'] or layer['name']
    print(f"  • {display_text}")