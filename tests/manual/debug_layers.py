#!/usr/bin/env python3
"""
Direct test of the get_available_layers function
"""

import requests
import xml.etree.ElementTree as ET

WMS_BASE_URL = "https://ows.emodnet-seabedhabitats.eu/emodnet_open_maplibrary/wms"
WMS_VERSION = "1.3.0"

def test_get_available_layers():
    """Test the layer parsing directly"""
    try:
        params = {
            'service': 'WMS',
            'version': WMS_VERSION,
            'request': 'GetCapabilities'
        }
        print("Fetching WMS capabilities...")
        response = requests.get(WMS_BASE_URL, params=params, timeout=10)
        print(f"Response status: {response.status_code}")
        
        if response.status_code == 200:
            # Parse XML with namespace handling
            root = ET.fromstring(response.content)
            
            # Remove namespace for easier parsing
            for elem in root.iter():
                if '}' in elem.tag:
                    elem.tag = elem.tag.split('}')[1]
            
            layers = []
            for layer in root.findall('.//Layer'):
                name_elem = layer.find('Name')
                title_elem = layer.find('Title')
                abstract_elem = layer.find('Abstract')
                
                if name_elem is not None and name_elem.text:
                    # Skip the root layer and only get actual data layers
                    if ':' not in name_elem.text:
                        
                        # Show what we're getting
                        print(f"Layer: {name_elem.text}")
                        print(f"  Title: {title_elem.text if title_elem is not None else 'None'}")
                        print(f"  Abstract present: {abstract_elem is not None}")
                        if abstract_elem is not None:
                            abstract_text = abstract_elem.text or ""
                            print(f"  Abstract length: {len(abstract_text)}")
                        
                        layer_data = {
                            'name': name_elem.text,
                            'title': title_elem.text if title_elem is not None and title_elem.text else name_elem.text,
                            'description': None  # Always set to None
                        }
                        
                        print(f"  Final description: {layer_data['description']}")
                        print("-" * 50)
                        
                        layers.append(layer_data)
                        
                        # Only show first 3 layers
                        if len(layers) >= 3:
                            break
            
            print(f"\nReturning {len(layers)} layers with descriptions set to None")
            return layers[:20]
            
    except Exception as e:
        print(f"Error fetching layers: {e}")
        return []

if __name__ == "__main__":
    layers = test_get_available_layers()
    print("\nFinal result:")
    if layers:
        for i, layer in enumerate(layers[:3]):
            print(f"{i+1}. {layer['name']}: description = {layer['description']}")
    else:
        print("No layers returned")