# Layer Manager Quick Reference

## Setup

```javascript
// Initialize
const map = window.MapInit.initMap();
const vectorGroup = L.layerGroup().addTo(map);
window.LayerManager.init(map, vectorGroup);
```

## Common Operations

### Load WMS Overlay
```javascript
LayerManager.selectWMSLayerAsOverlay('eusm_2023_eunis2019_full');
```

### Load Vector Layer
```javascript
await LayerManager.loadVectorLayerFast('Bbt - Bbt Areas');
```

### Load HELCOM Layer
```javascript
LayerManager.selectHELCOMLayerAsOverlay('helcom:layer_name');
```

### Change Opacity
```javascript
LayerManager.setOpacity(0.8); // 80% opacity
```

### Clear All Layers
```javascript
LayerManager.clearLayers();
```

### Update Status
```javascript
LayerManager.updateStatus('Loading...', 'loading');
LayerManager.updateStatus('Ready', '');
LayerManager.updateStatus('Error occurred', 'error');
```

## Advanced Operations

### Preload Layers in Background
```javascript
const vectorLayers = [
    { display_name: 'Bbt - Bbt Areas' },
    { display_name: 'Other Layer' }
];
await LayerManager.preloadLayersInBackground(vectorLayers);
```

### Zoom to Layer Extent
```javascript
LayerManager.zoomToLayerExtent('eusm_2023_eunis2019_full');
```

### Setup GetFeatureInfo
```javascript
LayerManager.setupGetFeatureInfo('layer_name');
```

## State Queries

```javascript
// Current layer name
const layer = LayerManager.getCurrentLayer();

// Current layer type
const type = LayerManager.getCurrentLayerType();
// Returns: 'wms', 'wms-overlay', 'helcom-overlay', or 'vector'

// Get layer instances
const wms = LayerManager.getWMSLayer();
const helcom = LayerManager.getHELCOMLayer();
const vectors = LayerManager.getVectorLayerGroup();

// Access cache
const cache = LayerManager.getLayerCache();
```

## Public API Summary

| Category | Functions |
|----------|-----------|
| **Init** | `init()` |
| **WMS** | `updateWMSLayer()`, `selectWMSLayerAsOverlay()`, `checkLayerVisibility()`, `updateLegend()` |
| **HELCOM** | `selectHELCOMLayerAsOverlay()` |
| **Vector** | `loadVectorLayer()`, `loadVectorLayerFast()`, `preloadLayersInBackground()` |
| **Zoom** | `zoomToLayerExtent()`, `scaleToZoom()`, `calculateOptimalZoom()` |
| **FeatureInfo** | `setupGetFeatureInfo()`, `handleMapClick()`, `buildGetFeatureInfoUrl()`, `displayFeatureInfo()` |
| **Tooltips** | `createTooltip()`, `removeTooltip()`, `updateTooltip()`, `generateTooltipContent()`, `calculateFeatureArea()` |
| **Utility** | `setOpacity()`, `clearLayers()`, `updateStatus()` |
| **Getters** | `getCurrentLayer()`, `getCurrentLayerType()`, `getWMSLayer()`, `getHELCOMLayer()`, `getVectorLayerGroup()`, `getLayerCache()` |

## Key Concepts

### Layer Types
- **wms**: WMS layer as base (replaces vector)
- **wms-overlay**: WMS layer over vector (both visible)
- **helcom-overlay**: HELCOM WMS over vector
- **vector**: Only vector layers visible

### Simplification Levels
- **Zoom < 8**: 800m simplification (0.007 degrees)
- **Zoom >= 8**: Full resolution

### Cache Keys
- Format: `"LayerName:simplified"` or `"LayerName:full"`
- Example: `"Bbt - Bbt Areas:simplified"`

### Auto-Switching
- Automatically switches between EUNIS layers based on zoom
- Threshold: 1 zoom level change
- Debounce: 300ms
