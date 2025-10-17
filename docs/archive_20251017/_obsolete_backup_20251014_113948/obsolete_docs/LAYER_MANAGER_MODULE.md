# Layer Manager Module Documentation

## Overview

The **layer-manager.js** module is a comprehensive JavaScript module that manages all layer interactions in the EMODnet PyDeck application. It has been extracted from the monolithic `templates/index.html` file to provide better code organization, maintainability, and reusability.

**File Location:** `/home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/static/js/layer-manager.js`

**File Size:** 1,208 lines (~47 KB)

## Architecture

### Module Pattern

The module uses an **Immediately Invoked Function Expression (IIFE)** pattern with a revealing module pattern to encapsulate private variables and expose only the necessary public API:

```javascript
(function(window) {
    'use strict';
    
    // Private variables and functions
    let map = null;
    let currentLayer = null;
    // ...
    
    // Public API
    window.LayerManager = {
        init: init,
        updateWMSLayer: updateWMSLayer,
        // ...
    };
})(window);
```

### Dependencies

The module depends on:

1. **window.AppConfig** (from `config.js`)
   - `API_BASE_URL` - API endpoint base URL
   - `WMS_BASE_URL` - EMODnet WMS service URL
   - `HELCOM_WMS_BASE_URL` - HELCOM WMS service URL

2. **window.MapInit.getMap()** (from `map-init.js`)
   - Provides access to the Leaflet map instance

3. **Leaflet Library** (loaded via CDN)
   - Core mapping functionality

4. **Leaflet.GeometryUtil Plugin** (optional)
   - Enhanced geodesic area calculations for vector features

## Module Structure

### 1. Private Variables (Lines 20-35)

```javascript
let map = null;                    // Leaflet map instance
let currentLayer = null;           // Currently active layer name
let currentLayerType = 'vector';   // Layer type: 'wms', 'wms-overlay', 'helcom-overlay', 'vector'
let currentOpacity = 0.7;          // Current layer opacity
let wmsLayer = null;               // WMS layer instance
let helcomLayer = null;            // HELCOM layer instance
let vectorLayerGroup = null;       // Vector layer group
let hoverTooltip = null;           // Hover tooltip element
let currentActiveBBT = null;       // Currently active BBT area
let autoSwitchEnabled = true;      // Auto zoom-based layer switching
let lastAutoSwitchedZoom = -1;     // Last zoom level that triggered auto-switch
let isManualZoom = false;          // Manual zoom flag
const layerCache = new Map();      // Layer cache for instant access
```

### 2. BBT Region Information (Lines 37-121)

Enhanced metadata for MARBEFES Broad Belt Transect regions:

```javascript
const bbtRegionInfo = {
    'Archipelago': {
        region: 'Baltic Sea',
        description: 'Marine ecosystem functioning in the Swedish archipelago region',
        habitat: 'Coastal archipelago with complex habitat mosaic',
        research_focus: 'Benthic-pelagic coupling in coastal zones'
    },
    // ... 10 more regions
};
```

### 3. Functional Categories

#### **Initialization Functions**
- `init(mapInstance, vectorGroup)` - Initialize layer manager
- `setupMapEventHandlers()` - Setup map event listeners

#### **Tooltip Functions** (Lines 172-303)
- `calculateFeatureArea(feature)` - Calculate feature area in km²
- `createTooltip(content, x, y)` - Create hover tooltip
- `removeTooltip()` - Remove hover tooltip
- `updateTooltip(x, y)` - Update tooltip position
- `generateTooltipContent(feature, layerName)` - Generate enhanced tooltip HTML

#### **Zoom & Extent Functions** (Lines 308-450)
- `scaleToZoom(scale)` - Convert scale denominator to zoom level
- `calculateOptimalZoom(bounds, minScale, maxScale)` - Calculate optimal zoom
- `zoomToLayerExtent(layerName)` - Zoom to WMS layer extent

#### **GetFeatureInfo Functions** (Lines 455-580)
- `setupGetFeatureInfo(layerName)` - Setup click handlers for feature info
- `handleMapClick(e, layerName)` - Handle map clicks
- `buildGetFeatureInfoUrl(...)` - Build WMS GetFeatureInfo URL
- `displayFeatureInfo(htmlContent, latlng)` - Display feature info popup

#### **WMS Layer Management** (Lines 585-780)
- `updateWMSLayer(layerName, opacity)` - Update/add WMS layer
- `checkLayerVisibility(layerName)` - Check layer visibility at current zoom
- `updateLegend(layerName)` - Update legend image
- `selectWMSLayerAsOverlay(layerName)` - Add WMS as overlay
- `getOptimalEUSeaMapLayer(zoom)` - Get optimal EUNIS layer for zoom
- `switchEUSeaMapLayerByZoom()` - Auto-switch layer based on zoom

#### **HELCOM Layer Management** (Lines 785-815)
- `selectHELCOMLayerAsOverlay(layerName)` - Add HELCOM WMS overlay

#### **Vector Layer Management** (Lines 820-1080)
- `loadVectorLayer(layerName)` - Load vector layer from API
- `loadVectorLayerFast(layerName)` - Load with cache support
- `processVectorLayerData(geojson, layerName)` - Process and render GeoJSON
- `loadMultipleLayersConcurrently(layerNames, maxConcurrent)` - Concurrent loading
- `preloadLayersInBackground(vectorLayers)` - Background preloading

#### **Utility Functions** (Lines 1085-1150)
- `updateStatus(message, type)` - Update status indicator
- `setOpacity(opacity)` - Set layer opacity
- `clearLayers()` - Clear all layers

## Public API

### Initialization

```javascript
// Initialize the layer manager
LayerManager.init(mapInstance, vectorLayerGroup);
```

### WMS Layer Functions

```javascript
// Update/add WMS layer
LayerManager.updateWMSLayer('eusm_2023_eunis2019_full', 0.7);

// Add WMS as overlay (keeps vector layers visible)
LayerManager.selectWMSLayerAsOverlay('eusm_2023_eunis2019_full');

// Check if layer is visible at current zoom
LayerManager.checkLayerVisibility('layerName');

// Update legend
LayerManager.updateLegend('layerName');
```

### HELCOM Layer Functions

```javascript
// Add HELCOM layer as overlay
LayerManager.selectHELCOMLayerAsOverlay('helcom:pressure_layer');
```

### Vector Layer Functions

```javascript
// Load vector layer (with simplification based on zoom)
await LayerManager.loadVectorLayer('Bbt - Bbt Areas');

// Load with cache support (faster)
await LayerManager.loadVectorLayerFast('Bbt - Bbt Areas');

// Preload layers in background for instant access
await LayerManager.preloadLayersInBackground(vectorLayersArray);
```

### Extent/Zoom Functions

```javascript
// Zoom to layer extent with scale awareness
LayerManager.zoomToLayerExtent('layerName');

// Convert scale to zoom level
const zoom = LayerManager.scaleToZoom(1000000);

// Calculate optimal zoom for bounds with constraints
const optimalZoom = LayerManager.calculateOptimalZoom(bounds, minScale, maxScale);
```

### GetFeatureInfo Functions

```javascript
// Setup GetFeatureInfo click handler
LayerManager.setupGetFeatureInfo('layerName');

// Build GetFeatureInfo URL
const url = LayerManager.buildGetFeatureInfoUrl(layerName, bounds, width, height, x, y);

// Display feature info in popup
LayerManager.displayFeatureInfo(htmlContent, latlng);
```

### Tooltip Functions

```javascript
// Create hover tooltip
LayerManager.createTooltip('<div>Content</div>', x, y);

// Remove tooltip
LayerManager.removeTooltip();

// Update tooltip position
LayerManager.updateTooltip(newX, newY);

// Generate tooltip content for feature
const content = LayerManager.generateTooltipContent(feature, 'Bbt - Bbt Areas');

// Calculate feature area
const area = LayerManager.calculateFeatureArea(feature); // Returns km² as string
```

### Utility Functions

```javascript
// Update status indicator
LayerManager.updateStatus('Loading...', 'loading');

// Set opacity for active layer
LayerManager.setOpacity(0.8);

// Clear all layers
LayerManager.clearLayers();
```

### Getters

```javascript
// Get current layer name
const layer = LayerManager.getCurrentLayer();

// Get current layer type ('wms', 'wms-overlay', 'helcom-overlay', 'vector')
const type = LayerManager.getCurrentLayerType();

// Get WMS layer instance
const wmsLayer = LayerManager.getWMSLayer();

// Get HELCOM layer instance
const helcomLayer = LayerManager.getHELCOMLayer();

// Get vector layer group
const vectorGroup = LayerManager.getVectorLayerGroup();

// Get layer cache (Map object)
const cache = LayerManager.getLayerCache();
```

## Key Features

### 1. Simplification-Aware Vector Loading

The module automatically applies geometry simplification based on zoom level:

- **Zoom < 8** (all BBTs view): Uses 800m simplification (0.007 degrees)
- **Zoom >= 8** (individual BBT): Full resolution, no simplification

This is implemented throughout vector loading functions and caching system.

### 2. Layer Caching

The module maintains a simplification-aware cache using keys like:
- `"Bbt - Bbt Areas:simplified"` - For zoom < 8
- `"Bbt - Bbt Areas:full"` - For zoom >= 8

This enables instant layer switching without re-fetching from the server.

### 3. Automatic Zoom-Based Layer Switching

For EUSeaMap EUNIS layers, the module automatically switches between:
- `eusm_2023_eunis2019_400` (400m simplification) for zoom < 8
- `eusm_2023_eunis2019_full` (full resolution) for zoom >= 8

This is handled by the `switchEUSeaMapLayerByZoom()` function with debouncing (300ms).

### 4. Enhanced BBT Tooltips

Special handling for BBT (Broad Belt Transect) features with MARBEFES project context:
- Area calculations using Leaflet.GeometryUtil
- Region information (Baltic Sea, Mediterranean, etc.)
- Habitat descriptions
- Research focus details

### 5. WMS GetFeatureInfo Support

Click-based feature information retrieval from WMS services:
- Builds proper GetFeatureInfo URLs
- Handles coordinate transformations
- Displays results in Leaflet popups
- Error handling with user-friendly messages

### 6. Scale-Aware Zoom

Respects WMS layer scale constraints (MinScaleDenominator/MaxScaleDenominator):
- Calculates optimal zoom levels
- Provides user feedback when layer isn't visible at current zoom
- Automatically adjusts view to visible scale ranges

### 7. Concurrent Layer Loading

Background preloading of multiple layers with:
- Batch processing (default: 3 concurrent requests)
- Timeout handling (20s per layer)
- Progress tracking (success/error counts)
- Server-friendly delays between batches (200ms)

## Integration Example

```html
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
    <div id="map" style="width: 100%; height: 600px;"></div>
    
    <!-- Load modules in order -->
    <script src="/static/js/config.js"></script>
    <script src="/static/js/map-init.js"></script>
    <script src="/static/js/layer-manager.js"></script>
    
    <script>
        // Configure endpoints (normally done by Flask template)
        window.AppConfig.API_BASE_URL = '/api';
        window.AppConfig.WMS_BASE_URL = 'https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms';
        window.AppConfig.HELCOM_WMS_BASE_URL = 'https://maps.helcom.fi/arcgis/services/MADS/wms';
        
        // Initialize map
        const map = window.MapInit.initMap();
        
        // Create vector layer group
        const vectorGroup = L.layerGroup().addTo(map);
        
        // Initialize layer manager
        window.LayerManager.init(map, vectorGroup);
        
        // Load a WMS overlay
        window.LayerManager.selectWMSLayerAsOverlay('eusm_2023_eunis2019_full');
        
        // Load vector layer
        window.LayerManager.loadVectorLayerFast('Bbt - Bbt Areas');
    </script>
</body>
</html>
```

## Migration Notes

When migrating from inline code in `templates/index.html` to this module:

1. **Replace direct variable access** with getter functions:
   ```javascript
   // Before: currentLayer
   // After: LayerManager.getCurrentLayer()
   ```

2. **Replace direct function calls** with module API:
   ```javascript
   // Before: updateWMSLayer('layer', 0.7)
   // After: LayerManager.updateWMSLayer('layer', 0.7)
   ```

3. **Initialize the module** before using:
   ```javascript
   window.LayerManager.init(map, vectorLayerGroup);
   ```

4. **Ensure dependencies are loaded** in correct order:
   - config.js (first)
   - map-init.js (second)
   - layer-manager.js (third)

## Performance Optimizations

### 1. Geometry Simplification
- Reduces data transfer for overview maps (zoom < 8)
- 800m simplification = ~90% size reduction for BBT polygons

### 2. Layer Caching
- Instant layer switching without API calls
- Separate cache keys for simplified vs full resolution

### 3. Concurrent Loading
- Parallel API requests (3 concurrent by default)
- Reduces total loading time for multiple layers

### 4. Debounced Zoom Events
- 300ms debounce prevents excessive layer switches
- Zoom threshold = 1 prevents switches for minor zoom changes

### 5. Abort Controllers
- 15s timeout for vector layers
- 20s timeout for concurrent batch loading
- Prevents hanging requests

## Error Handling

The module includes comprehensive error handling:

1. **Network errors** - Displays user-friendly status messages
2. **Timeout errors** - Aborts requests after configured timeout
3. **XML parsing errors** - Fallback to default European view
4. **Missing legend images** - Silently hides legend container
5. **Invalid layer names** - Console warnings, no crashes
6. **Missing DOM elements** - Null checks before DOM manipulation

## Browser Compatibility

- **Modern browsers** (ES6+): Full support
- **IE11 and older**: Not supported (uses arrow functions, async/await, Map, etc.)
- **Recommended**: Chrome 90+, Firefox 88+, Safari 14+, Edge 90+

## Future Enhancements

Potential improvements for future versions:

1. **TypeScript conversion** - Add type safety
2. **Layer groups** - Support for multiple simultaneous overlays
3. **Custom styling** - Programmatic style updates for vector layers
4. **Animation support** - Smooth transitions between layers
5. **Touch gestures** - Mobile-friendly tooltip interactions
6. **Layer search** - Filter and search through available layers
7. **Export functionality** - Save current view/layers as image or data

## Summary

The **layer-manager.js** module provides a robust, feature-rich system for managing all layer types in the EMODnet PyDeck application. With 1,208 lines of well-organized code, it handles WMS layers, HELCOM overlays, and vector features with advanced features like caching, concurrent loading, automatic simplification, and intelligent zoom-based switching.

The module follows best practices with:
- Clear separation of concerns
- Comprehensive JSDoc comments
- Public API with revealing module pattern
- Defensive programming with error handling
- Performance optimizations throughout

This extraction improves code maintainability, testability, and reusability while maintaining all existing functionality.
