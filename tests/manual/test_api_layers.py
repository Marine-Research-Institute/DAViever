#!/usr/bin/env python3
"""
Test script to verify the API layers endpoint returns only titles
"""

import requests
import json

def test_api_layers():
    """Test the /api/layers endpoint"""
    try:
        response = requests.get("http://localhost:5000/api/layers")
        if response.status_code == 200:
            layers = response.json()
            
            print("=" * 60)
            print("API Layers Test")
            print("=" * 60)
            print(f"Found {len(layers)} layers:")
            print()
            
            for i, layer in enumerate(layers[:10], 1):  # Show first 10 layers
                print(f"{i:2d}. Title: {layer.get('title', 'N/A')}")
                print(f"    Name: {layer.get('name', 'N/A')}")
                print(f"    Description: {layer.get('description', 'N/A')}")
                print(f"    Display Text: '{layer.get('title') or layer.get('name')}'")
                print("-" * 50)
            
            if len(layers) > 10:
                print(f"... and {len(layers) - 10} more layers")
            
            # Verify descriptions are None
            has_descriptions = any(layer.get('description') for layer in layers)
            print()
            if has_descriptions:
                print("⚠️  WARNING: Some layers still have descriptions!")
            else:
                print("✅ SUCCESS: All descriptions are None - only titles will be displayed")
                
        else:
            print(f"❌ ERROR: API returned status code {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print("❌ ERROR: Could not connect to Flask server. Is it running?")
    except Exception as e:
        print(f"❌ ERROR: {e}")

if __name__ == "__main__":
    test_api_layers()