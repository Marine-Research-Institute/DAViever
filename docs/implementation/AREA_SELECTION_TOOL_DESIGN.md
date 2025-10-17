# Area Selection Tool - Design Document
**Feature:** Interactive Map Area Selection & Analysis
**Version:** 1.0
**Date:** October 17, 2025
**Status:** Implementation Ready

---

## 1. FEATURE OVERVIEW

### Purpose
Enable users to draw custom areas on the map and extract detailed information about:
- Seabed habitat types within the selected area
- Human activities and pressures
- Research site overlap
- Area statistics (size, centroid, bounds)
- Export data in multiple formats (GeoJSON, CSV, PDF report)

### User Stories
1. **As a marine researcher**, I want to select a custom study area to analyze habitat distribution
2. **As a policy maker**, I want to assess human activity impacts in a specific zone
3. **As a data analyst**, I want to export area statistics for further analysis
4. **As a project coordinator**, I want to generate reports for stakeholder presentations

---

## 2. TECHNICAL ARCHITECTURE

### 2.1 Frontend Components

#### **A. Drawing Tools** (Leaflet.draw integration)
```javascript
// area-selection.js - New module
(function(window) {
    'use strict';

    let drawControl;
    let drawnItems;
    let selectedArea = null;

    function init(map) {
        // Initialize Leaflet.draw
        drawnItems = new L.FeatureGroup();
        map.addLayer(drawnItems);

        drawControl = new L.Control.Draw({
            position: 'topright',
            draw: {
                polyline: false,
                polygon: {
                    allowIntersection: false,
                    showArea: true,
                    metric: true
                },
                circle: {
                    showRadius: true,
                    metric: true
                },
                rectangle: {
                    showArea: true,
                    metric: true
                },
                marker: false,
                circlemarker: false
            },
            edit: {
                featureGroup: drawnItems,
                remove: true
            }
        });

        map.addControl(drawControl);

        // Event handlers
        map.on(L.Draw.Event.CREATED, onAreaCreated);
        map.on(L.Draw.Event.EDITED, onAreaEdited);
        map.on(L.Draw.Event.DELETED, onAreaDeleted);
    }

    window.AreaSelection = {
        init,
        getSelectedArea,
        clearSelection,
        exportData,
        generateReport
    };
})(window);
```

#### **B. Analysis Panel**
```html
<!-- Add to index.html sidebar -->
<div class="control-group">
    <h3>Area Selection & Analysis</h3>

    <button id="toggle-drawing-tools" class="btn-primary">
        📐 Enable Drawing Tools
    </button>

    <div id="area-info-panel" style="display: none;">
        <h4>Selected Area</h4>
        <div class="area-stats">
            <div><strong>Area:</strong> <span id="area-size">-</span> km²</div>
            <div><strong>Perimeter:</strong> <span id="area-perimeter">-</span> km</div>
            <div><strong>Center:</strong> <span id="area-centroid">-</span></div>
        </div>

        <button id="analyze-area" class="btn-primary">
            🔍 Analyze Area
        </button>

        <button id="export-area" class="btn-secondary">
            📥 Export Data
        </button>

        <button id="generate-report" class="btn-secondary">
            📄 Generate Report
        </button>
    </div>
</div>
```

### 2.2 Backend API Endpoints

#### **A. Area Analysis Endpoint**
```python
# app.py additions

@app.route("/api/analyze-area", methods=['POST'])
@limiter.limit("20 per minute")
def api_analyze_area():
    """
    Analyze a user-drawn area for habitat and activity data

    Request Body:
    {
        "geometry": {GeoJSON geometry},
        "layers": ["layer1", "layer2", ...],  # Optional
        "include_statistics": true,  # Optional
        "include_wms_features": true  # Optional
    }

    Returns:
    {
        "area_km2": float,
        "perimeter_km": float,
        "centroid": [lng, lat],
        "bounds": [minX, minY, maxX, maxY],
        "habitats": [...],  # If WMS feature info available
        "activities": [...],  # If human activities layer selected
        "research_sites": [...],  # Overlapping research sites
        "statistics": {...}
    }
    """
    try:
        data = request.json
        geometry = data.get('geometry')

        if not geometry:
            return jsonify({"error": "Missing geometry"}), 400

        # Validate geometry
        if not validate_geojson_geometry(geometry):
            return jsonify({"error": "Invalid GeoJSON geometry"}), 400

        # Calculate area statistics
        stats = calculate_area_statistics(geometry)

        # Check overlap with research sites
        research_sites = check_research_site_overlap(geometry)

        # Query WMS features within area (if requested)
        wms_features = None
        if data.get('include_wms_features'):
            wms_features = query_wms_features_in_area(
                geometry,
                data.get('layers', [])
            )

        response = {
            "area_km2": stats['area'],
            "perimeter_km": stats['perimeter'],
            "centroid": stats['centroid'],
            "bounds": stats['bounds'],
            "research_sites": research_sites,
            "wms_features": wms_features,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        return jsonify(response), 200

    except Exception as e:
        logger.error(f"Area analysis error: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500
```

#### **B. Export Endpoint**
```python
@app.route("/api/export-area", methods=['POST'])
@limiter.limit("10 per minute")
def api_export_area():
    """
    Export area data in various formats

    Request Body:
    {
        "geometry": {GeoJSON geometry},
        "format": "geojson|csv|kml",
        "analysis_data": {...}  # From analyze-area response
    }

    Returns:
    File download or JSON response
    """
    try:
        data = request.json
        geometry = data.get('geometry')
        export_format = data.get('format', 'geojson').lower()

        if export_format == 'geojson':
            return export_as_geojson(geometry, data.get('analysis_data'))
        elif export_format == 'csv':
            return export_as_csv(geometry, data.get('analysis_data'))
        elif export_format == 'kml':
            return export_as_kml(geometry, data.get('analysis_data'))
        else:
            return jsonify({"error": "Unsupported format"}), 400

    except Exception as e:
        logger.error(f"Export error: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500
```

#### **C. Report Generation Endpoint**
```python
@app.route("/api/generate-report", methods=['POST'])
@limiter.limit("5 per minute")
def api_generate_report():
    """
    Generate PDF report for selected area

    Request Body:
    {
        "geometry": {GeoJSON geometry},
        "analysis_data": {...},
        "report_options": {
            "include_map": true,
            "include_statistics": true,
            "include_layers": ["layer1", "layer2"]
        }
    }

    Returns:
    PDF file download
    """
    try:
        data = request.json

        # Generate PDF using ReportLab or similar
        pdf_buffer = generate_area_report_pdf(
            data.get('geometry'),
            data.get('analysis_data'),
            data.get('report_options', {})
        )

        return send_file(
            pdf_buffer,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=f'area_report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.pdf'
        )

    except Exception as e:
        logger.error(f"Report generation error: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500
```

### 2.3 Utility Functions

```python
# utils/geometry.py - New module

from shapely.geometry import shape, Point, Polygon
from shapely.ops import transform
import pyproj
from functools import partial

def validate_geojson_geometry(geometry):
    """Validate GeoJSON geometry structure"""
    try:
        geom = shape(geometry)
        return geom.is_valid
    except Exception:
        return False

def calculate_area_statistics(geometry):
    """Calculate area, perimeter, centroid, bounds"""
    try:
        geom = shape(geometry)

        # Project to equal-area projection for accurate measurements
        project = partial(
            pyproj.transform,
            pyproj.Proj('EPSG:4326'),  # WGS84
            pyproj.Proj('EPSG:3857')   # Web Mercator
        )

        geom_projected = transform(project, geom)

        # Calculate statistics
        area_m2 = geom_projected.area
        area_km2 = area_m2 / 1_000_000

        perimeter_m = geom_projected.length
        perimeter_km = perimeter_m / 1000

        centroid = geom.centroid
        bounds = geom.bounds  # (minx, miny, maxx, maxy)

        return {
            'area': round(area_km2, 2),
            'perimeter': round(perimeter_km, 2),
            'centroid': [round(centroid.x, 6), round(centroid.y, 6)],
            'bounds': [round(b, 6) for b in bounds]
        }

    except Exception as e:
        logger.error(f"Area calculation error: {e}")
        raise

def check_research_site_overlap(geometry):
    """Check which research sites overlap with selected area"""
    geom = shape(geometry)

    # MarineSABRES research sites (from research-sites.js)
    research_sites = [
        {
            "name": "Tuscan Archipelago",
            "bounds": [[42.2, 9.8], [43.2, 10.8]],
            "region": "Mediterranean Sea"
        },
        {
            "name": "Arctic Northeast Atlantic",
            "bounds": [[76.0, -10.0], [80.0, 35.0]],
            "region": "Arctic Ocean"
        },
        {
            "name": "Macaronesia",
            "bounds": [[27.5, -18.5], [29.5, -13.0]],
            "region": "Atlantic Ocean"
        }
    ]

    overlapping = []
    for site in research_sites:
        site_poly = box(
            site['bounds'][0][1],  # minX
            site['bounds'][0][0],  # minY
            site['bounds'][1][1],  # maxX
            site['bounds'][1][0]   # maxY
        )

        if geom.intersects(site_poly):
            intersection = geom.intersection(site_poly)
            overlap_pct = (intersection.area / geom.area) * 100
            overlapping.append({
                "name": site['name'],
                "region": site['region'],
                "overlap_percentage": round(overlap_pct, 2)
            })

    return overlapping
```

---

## 3. UI/UX DESIGN

### 3.1 Drawing Tools Panel

```
┌─────────────────────────────────┐
│ Area Selection & Analysis       │
├─────────────────────────────────┤
│                                 │
│ 📐 Drawing Tools: [ Active ]    │
│                                 │
│ Draw Shape:                     │
│ [🔲 Rectangle] [⬟ Polygon]     │
│ [⭕ Circle]                      │
│                                 │
│ [ Edit ] [ Delete ] [ Clear ]   │
│                                 │
│ ──────────────────────────      │
│                                 │
│ Selected Area Info:             │
│ Area: 245.7 km²                 │
│ Perimeter: 89.3 km              │
│ Center: 42.75°N, 10.31°E        │
│                                 │
│ Overlapping Research Sites:     │
│ ✓ Tuscan Archipelago (87%)      │
│                                 │
│ [ 🔍 Analyze ] [ 📥 Export ]    │
│ [ 📄 Generate Report ]          │
└─────────────────────────────────┘
```

### 3.2 Analysis Results Modal

```
╔═══════════════════════════════════════════╗
║ 🗺️ Area Analysis Results                  ║
╠═══════════════════════════════════════════╣
║                                           ║
║ BASIC STATISTICS                          ║
║ ─────────────────                         ║
║ Area: 245.7 km²                           ║
║ Perimeter: 89.3 km                        ║
║ Centroid: 42.75°N, 10.31°E                ║
║                                           ║
║ RESEARCH SITES                            ║
║ ─────────────────                         ║
║ ✓ Tuscan Archipelago (87% overlap)        ║
║                                           ║
║ HABITAT DISTRIBUTION (if available)       ║
║ ─────────────────                         ║
║ • Seagrass Meadows: 45%                   ║
║ • Rocky Reefs: 30%                        ║
║ • Sandy Bottom: 25%                       ║
║                                           ║
║ HUMAN ACTIVITIES (if selected)            ║
║ ─────────────────                         ║
║ • Shipping Routes: Present                ║
║ • Fishing Areas: Moderate intensity       ║
║                                           ║
║ [ Close ] [ Export ] [ Generate Report ]  ║
╚═══════════════════════════════════════════╝
```

---

## 4. EXPORT FORMATS

### 4.1 GeoJSON Export
```json
{
  "type": "Feature",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[...]]
  },
  "properties": {
    "analysis_date": "2025-10-17T10:30:00Z",
    "area_km2": 245.7,
    "perimeter_km": 89.3,
    "centroid": [10.31, 42.75],
    "research_sites": [...],
    "statistics": {...}
  }
}
```

### 4.2 CSV Export
```csv
Statistic,Value,Unit
Area,245.7,km²
Perimeter,89.3,km
Centroid_Lat,42.75,degrees
Centroid_Lng,10.31,degrees
Research_Site,Tuscan Archipelago,
Overlap_Percentage,87,%
Analysis_Date,2025-10-17T10:30:00Z,
```

### 4.3 PDF Report (Structure)
```
MARINESABRES AREA ANALYSIS REPORT
═════════════════════════════════════

Date: October 17, 2025
Generated by: MarineSABRES DA Tool

STUDY AREA OVERVIEW
───────────────────
Area: 245.7 km²
Perimeter: 89.3 km
Center: 42.75°N, 10.31°E

[Map Thumbnail - Optional]

RESEARCH SITE OVERLAP
─────────────────────
✓ Tuscan Archipelago
  - Overlap: 87%
  - Region: Mediterranean Sea

HABITAT DISTRIBUTION
────────────────────
[If available from WMS GetFeatureInfo]

HUMAN ACTIVITIES
────────────────
[If selected layers include human activities]

RECOMMENDATIONS
───────────────
[Future enhancement - AI-generated insights]

═════════════════════════════════════
Report generated by MarineSABRES DA Tool
Horizon Europe Grant Agreement No. 101093169
```

---

## 5. IMPLEMENTATION DEPENDENCIES

### Required Libraries

**Backend:**
```txt
# Add to requirements.txt
shapely>=2.0.0       # Geometry calculations
pyproj>=3.6.0        # Coordinate transformations
reportlab>=4.0.0     # PDF generation (optional)
```

**Frontend:**
```html
<!-- Add to index.html -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css" />
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js"></script>
```

---

## 6. SECURITY CONSIDERATIONS

1. **Input Validation**
   - Validate GeoJSON geometry structure
   - Limit polygon complexity (max vertices)
   - Limit area size (max 10,000 km²)

2. **Rate Limiting**
   - Analysis: 20 requests/minute
   - Export: 10 requests/minute
   - Report: 5 requests/minute

3. **Resource Protection**
   - Timeout for complex calculations
   - Maximum PDF file size
   - Concurrent request limits

---

## 7. TESTING STRATEGY

### Unit Tests
```python
def test_calculate_area_statistics():
    geometry = {
        "type": "Polygon",
        "coordinates": [[[10, 42], [11, 42], [11, 43], [10, 43], [10, 42]]]
    }
    stats = calculate_area_statistics(geometry)
    assert stats['area'] > 0
    assert stats['perimeter'] > 0
    assert len(stats['centroid']) == 2

def test_validate_geojson_geometry():
    valid_geom = {"type": "Point", "coordinates": [10, 42]}
    assert validate_geojson_geometry(valid_geom) == True

    invalid_geom = {"type": "Invalid"}
    assert validate_geojson_geometry(invalid_geom) == False
```

### Integration Tests
```python
def test_area_analysis_api(client):
    data = {
        "geometry": {
            "type": "Polygon",
            "coordinates": [[[10, 42], [11, 42], [11, 43], [10, 43], [10, 42]]]
        }
    }
    response = client.post('/api/analyze-area', json=data)
    assert response.status_code == 200
    assert 'area_km2' in response.json
```

---

## 8. FUTURE ENHANCEMENTS

1. **Multi-area Comparison**
   - Select multiple areas
   - Compare statistics side-by-side

2. **Temporal Analysis**
   - Compare same area across different time periods
   - Track habitat changes over time

3. **Advanced Export Formats**
   - Shapefile (.shp + supporting files)
   - KMZ (for Google Earth)
   - Excel workbooks with multiple sheets

4. **AI-Powered Insights**
   - Habitat quality assessment
   - Risk analysis for human impacts
   - Conservation priority scoring

5. **Collaboration Features**
   - Share selected areas with colleagues
   - Annotate areas with notes
   - Version history for analyses

---

## CONCLUSION

The Area Selection Tool provides researchers with powerful spatial analysis capabilities directly integrated into the MarineSABRES DA Tool. By combining interactive drawing tools with robust backend analysis, users can quickly assess habitats, activities, and research sites within custom study areas.

**Status:** Ready for implementation
**Estimated Development Time:** 5-7 days
**Priority:** HIGH (directly supports research workflows)
