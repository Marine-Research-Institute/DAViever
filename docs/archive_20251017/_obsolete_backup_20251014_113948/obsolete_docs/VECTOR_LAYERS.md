# Vector Layer Support - User Guide

The EMODnet Viewer now supports displaying vector area maps from GeoPackage (GPKG) files stored in the `data/vector` directory. This guide explains how to use and manage vector layers.

## 🗺️ What are Vector Layers?

Vector layers are geospatial data represented as geometric shapes:
- **Polygons/Areas**: Marine protected areas, habitat zones, administrative boundaries
- **Lines**: Shipping routes, pipeline routes, survey tracks
- **Points**: Monitoring stations, sampling locations, infrastructure

Unlike WMS raster layers, vector layers allow for:
- Interactive feature selection and information display
- Client-side styling and filtering
- Precise geometry representation
- Rich attribute data display

## 📁 Adding Vector Data

### 1. Supported Format

The application supports **GeoPackage (.gpkg)** files, which can contain:
- Multiple layers in a single file
- Complex geometries and attributes
- Spatial indexes for performance
- Metadata and styling information

### 2. File Placement

Place your GPKG files in the `data/vector/` directory:

```
EMODNET_PyDeck/
├── data/
│   └── vector/
│       ├── marine_protected_areas.gpkg
│       ├── monitoring_stations.gpkg
│       └── shipping_routes.gpkg
```

### 3. Automatic Discovery

Vector layers are automatically discovered and loaded when the application starts:

1. **File scanning**: All `.gpkg` files in `data/vector/` are found
2. **Layer extraction**: Each layer within each GPKG file is identified
3. **Metadata reading**: Geometry types, feature counts, and spatial bounds are determined
4. **Style assignment**: Default styles are applied based on geometry type

## 🎨 Layer Styling

### Automatic Styling

The application automatically applies styles based on geometry type:

| Geometry Type | Style |
|---------------|--------|
| **Polygon/MultiPolygon** | Semi-transparent fill with colored border |
| **LineString/MultiLineString** | Colored lines with appropriate width |
| **Point/MultiPoint** | Circular markers |

### Default Style Colors

- **Areas (Polygons)**: Blue fill (#3388ff) with 40% transparency
- **Lines**: Orange (#ff7800) with 80% opacity
- **Points**: Red (#ff0000) markers with 80% opacity

## 🔧 Using Vector Layers

### 1. Layer Selection

Vector layers appear in the main layer dropdown, organized in groups:

```
Layer Selection:
├── WMS Layers
│   ├── EUSeaMap 2021 - All Habitats
│   ├── Benthic Habitats
│   └── ...
└── Vector Layers
    ├── Marine Protected Areas
    ├── Monitoring Stations
    └── Shipping Routes
```

### 2. Interactive Features

When a vector layer is active:

- **Hover tooltips**: Hover over features to see information including calculated areas
- **Real-time area calculation**: Accurate geodesic area measurements in km²
- **Click features**: Click on any shape to view its attributes
- **Popup information**: Feature properties are displayed in popups
- **Automatic zoom**: Layer bounds are automatically fitted to the map
- **Opacity control**: Use the opacity slider to adjust transparency

### 3. Hover Tooltip Information

**New Feature: Real-time hover tooltips with area calculations!**

When hovering over vector features:

```
Feature Information Tooltip
┌─────────────────────────────────┐
│ Broad Belt Transect #1          │
│ Area: 1,250.45 km²              │
│ ID: BBT_001                     │
└─────────────────────────────────┘
```

**Tooltip Features:**
- **Real-time area calculation**: Uses geodesic calculations for accurate area measurements
- **Feature identification**: Shows feature names and IDs from the data
- **Cursor following**: Tooltips move with your mouse cursor
- **Smart positioning**: Automatically avoids map edges
- **Instant display**: No click required, just hover over any feature

### 4. Feature Information

Vector features display rich attribute information:

```
Marine Protected Area #1
Name: Baltic Sea Protected Area
Type: Marine Protected Area
Area: 1250.5 km²
Established: 2010
Protection Level: High
```

## 📊 Performance Considerations

### File Size Recommendations

- **Small files** (<5MB): Load instantly
- **Medium files** (5-20MB): Load within a few seconds
- **Large files** (>20MB): May take longer, consider simplification

### Optimization Tips

1. **Simplify geometries** for web display
2. **Remove unnecessary attributes** to reduce file size
3. **Use appropriate coordinate systems** (WGS84/EPSG:4326 preferred)
4. **Split large datasets** into multiple smaller files

### Automatic Simplification

The application supports automatic geometry simplification via the API:

```
/api/vector/layer/MyLayer?simplify=0.001
```

## 🛠️ Creating Vector Data

### Sample Data Creation

Use the included script to create sample data:

```bash
python scripts/create_sample_data.py
```

This creates:
- `marine_protected_areas.gpkg` - Sample polygon areas
- `monitoring_stations.gpkg` - Sample point locations
- `shipping_routes.gpkg` - Sample line features
- `european_marine_data.gpkg` - Multi-layer file with all data

### Data Sources

Common sources for marine vector data:

1. **EMODnet Data Portals**
   - Human Activities
   - Protected Areas
   - Vessel Density Maps

2. **GEBCO**
   - Bathymetry contours
   - Undersea features

3. **Natural Earth**
   - Administrative boundaries
   - Geographic features

4. **OpenStreetMap**
   - Coastlines and water bodies
   - Infrastructure

### Format Conversion

Convert other formats to GPKG using tools like:

```bash
# Using GDAL/OGR
ogr2ogr -f GPKG output.gpkg input.shp

# Using Python/GeoPandas
import geopandas as gpd
gdf = gpd.read_file("input.geojson")
gdf.to_file("output.gpkg", driver="GPKG")
```

## 🔍 API Endpoints

### Vector Layer APIs

The application provides REST APIs for vector data:

| Endpoint | Description | Example |
|----------|-------------|---------|
| `/api/vector/layers` | List all vector layers | `GET /api/vector/layers` |
| `/api/vector/layer/<name>` | Get GeoJSON for layer | `GET /api/vector/layer/Marine%20Areas` |
| `/api/vector/bounds` | Get bounds of all layers | `GET /api/vector/bounds` |
| `/api/all-layers` | Get WMS + vector layers | `GET /api/all-layers` |

### Example API Response

```json
{
  "layers": [
    {
      "display_name": "Marine Protected Areas",
      "geometry_type": "Polygon",
      "feature_count": 4,
      "bounds": [-10.0, 42.0, 17.0, 57.0],
      "crs": "EPSG:4326",
      "source_file": "marine_protected_areas.gpkg"
    }
  ],
  "count": 1
}
```

## 🐛 Troubleshooting

### Common Issues

1. **Layers not appearing**
   - Check file format is valid GPKG
   - Verify files are in `data/vector/` directory
   - Restart the application to reload layers

2. **Slow loading**
   - Large files may take time to load
   - Consider using simplification parameter
   - Check browser console for errors

3. **Styling issues**
   - Default styles are applied automatically
   - Complex geometries may render slowly
   - Multi-part geometries are supported

4. **Coordinate system problems**
   - Data should be in WGS84 (EPSG:4326)
   - Other CRS will be reprojected automatically
   - Check for invalid geometries

### Diagnostic Commands

```bash
# Test vector layer loading
python -c "from src.emodnet_viewer.utils.vector_loader import load_all_vector_data; print(load_all_vector_data())"

# Check GPKG file contents
python -c "import fiona; print(fiona.listlayers('data/vector/your_file.gpkg'))"

# Validate geometries
python -c "import geopandas as gpd; gdf = gpd.read_file('your_file.gpkg'); print(gdf.is_valid.all())"
```

## 🚀 Advanced Usage

### Custom Styling

Future versions may support custom styling through:
- Layer-specific style configurations
- Attribute-based styling rules
- Interactive style editing

### Multi-layer Files

GPKG files can contain multiple layers:

```python
# Creating multi-layer GPKG
areas.to_file("marine_data.gpkg", layer="protected_areas", driver="GPKG")
stations.to_file("marine_data.gpkg", layer="stations", driver="GPKG", append=True)
routes.to_file("marine_data.gpkg", layer="routes", driver="GPKG", append=True)
```

### Integration with WMS

Vector layers work alongside WMS layers:
- Switch between layer types using the dropdown
- Vector layers override WMS layers when selected
- Opacity controls work for both layer types
- Basemap selection applies to all layers

## 📋 Best Practices

### Data Preparation

1. **Clean geometries**: Fix invalid or self-intersecting polygons
2. **Optimize attributes**: Include only necessary fields
3. **Use consistent naming**: Avoid spaces and special characters in field names
4. **Include metadata**: Add description and source information

### Performance Optimization

1. **Spatial indexing**: GPKG files automatically include spatial indexes
2. **Feature limits**: Large datasets may be filtered or paginated
3. **Geometry simplification**: Use tolerance appropriate for zoom level
4. **Caching**: Browser caches GeoJSON responses for performance

### Security Considerations

1. **File validation**: Only valid GPKG files are processed
2. **Path security**: File paths are sanitized and validated
3. **Feature limits**: Maximum feature counts prevent memory issues
4. **Error handling**: Invalid data is handled gracefully

This vector layer support significantly enhances the EMODnet Viewer's capabilities, allowing you to display and interact with local geospatial data alongside remote WMS services.