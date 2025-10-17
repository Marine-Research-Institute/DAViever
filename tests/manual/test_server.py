#!/usr/bin/env python3
"""
Simple Flask app to test layer display with descriptions removed
"""

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

# Hardcoded layers with descriptions set to None
EMODNET_LAYERS = [
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
    },
    {
        "name": "substrate",
        "title": "Seabed Substrate",
        "description": None
    },
    {
        "name": "confidence",
        "title": "Confidence Assessment", 
        "description": None
    },
    {
        "name": "annexiMaps_all",
        "title": "Annex I Habitats",
        "description": None
    }
]

@app.route('/api/layers')
def api_layers():
    """API endpoint to get available layers - descriptions always None"""
    return jsonify(EMODNET_LAYERS)

@app.route('/')
def index():
    return """
    <h1>EMODnet Layer Test</h1>
    <p>Testing layer display with titles only</p>
    <a href="/api/layers">View API layers</a>
    """

if __name__ == '__main__':
    print("🌊 Starting EMODnet Test Server...")
    print("Available at: http://localhost:5000")
    print("API: http://localhost:5000/api/layers")
    app.run(debug=True, host='127.0.0.1', port=5000)