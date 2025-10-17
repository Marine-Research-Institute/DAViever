#!/usr/bin/env python3
"""
Test script to verify how layer display logic works with the new changes
"""

# Test data mimicking EMODNET layer structure
test_layers = [
    {
        "name": "habitat_boxes_n2000",
        "title": "Annex I habitat maps study areas",
        "description": None
    },
    {
        "name": "all_eusm2021", 
        "title": "EUSeaMap 2021 - All Habitats",
        "description": "Broad-scale seabed habitat map for Europe"
    },
    {
        "name": "substrate",
        "title": "Seabed Substrate", 
        "description": "Seabed substrate types"
    },
    {
        "name": "confidence_layer",
        "title": "Confidence Assessment",
        "description": None
    }
]

def test_layer_display_logic(layer):
    """Test the JavaScript display logic in Python"""
    print(f"\nTesting layer: {layer['name']}")
    print(f"Raw data: {layer}")
    
    # Mimic the new simplified JavaScript logic
    title_html = layer['title'] or layer['name']
    
    print("Display result:")
    print(f"  Title only: '{title_html}'")
    print("-" * 50)

if __name__ == "__main__":
    print("=" * 60)
    print("EMODNET Layer Display Test")
    print("=" * 60)
    
    for layer in test_layers:
        test_layer_display_logic(layer)
    
    print("\nTest completed!")