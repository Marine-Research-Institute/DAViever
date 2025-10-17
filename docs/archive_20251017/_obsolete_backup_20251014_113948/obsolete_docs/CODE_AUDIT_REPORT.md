# Code Audit Report - BBT Display Issue
**Date:** 2025-10-07 00:45 UTC
**Issue:** BBT features not displaying on map despite no JavaScript errors

---

## Executive Summary

Comprehensive code audit completed across all application layers. **ALL CRITICAL SYSTEMS ARE CONSISTENT AND CORRECTLY CONFIGURED**. No inconsistencies found in Flask variables, layer names, API endpoints, module loading, or initialization sequence.

**Conclusion:** The BBT display issue is likely a **layer ordering/visibility problem** (WMS overlay covering vector features), NOT a code inconsistency.

---

## 1. Flask Template Variable Injection ✅ CONSISTENT

### Backend (app.py)
```python
return render_template(
    'index.html',
    layers=all_layers["wms_layers"],           # → window.wmsLayers
    helcom_layers=all_layers["helcom_layers"], # → window.helcomLayers
    vector_layers=all_layers["vector_layers"], # → window.vectorLayers
)
```

### Frontend (templates/index.html:259-267)
```javascript
window.wmsLayers = {{ layers | tojson }};
window.helcomLayers = {{ helcom_layers | tojson }};
window.vectorLayers = {{ vector_layers | tojson }};
```

**Status:** ✅ All template variables properly injected with debug logging

---

## 2. Layer Name Consistency ✅ CONSISTENT

### Canonical Layer Name: **"Bbt - Merged"**

| File | Location | Reference | Status |
|------|----------|-----------|--------|
| **bbt-tool.js** | Lines 156, 359, 392, 414, 427, 454, 481, 492 | `'Bbt - Merged'` | ✅ All 8 refs updated |
| **app.js** | Lines 83, 88 | `'Bbt - Merged'` & `l.display_name` | ✅ Correct |
| **templates/index.html** | Line 69-70 | Button: "Lithuanian coastal zone" | ✅ Matches data |
| **API response** | `/api/vector/layer/Bbt%20-%20Merged` | Returns HTTP 200 | ✅ Working |

**Status:** ✅ All layer name references are consistent across codebase

---

## 3. API Endpoint References ✅ CONSISTENT

### Configuration Flow
1. **Flask sets API_BASE_URL** → `window.AppConfig.API_BASE_URL` (template injection)
2. **config.js** initializes `window.AppConfig` (fallback defaults)
3. **All modules** use `window.AppConfig.API_BASE_URL` for API calls

### Endpoint Usage
```javascript
// bbt-tool.js (8 locations)
const apiUrl = `${window.AppConfig.API_BASE_URL}/vector/layer/${encodeURIComponent('Bbt - Merged')}`;

// layer-manager.js
const url = `${window.AppConfig.API_BASE_URL}/vector/layer/${encodeURIComponent(layerName)}`;
```

### Verification
- ✅ API responds with HTTP 200
- ✅ Returns 11 BBT features in GeoJSON format
- ✅ No 404 errors (previous "Bbt - Bbt Areas" issue resolved)

**Status:** ✅ All API endpoints correctly referenced and functional

---

## 4. JavaScript Module Loading Order ✅ CORRECT

### HTML Loading Sequence (templates/index.html:271-276)
```html
1. config.js          → Defines window.AppConfig, window.BaseMaps
2. map-init.js        → Defines window.MapInit (depends on AppConfig, BaseMaps)
3. layer-manager.js   → Defines window.LayerManager (depends on AppConfig, MapInit)
4. bbt-tool.js        → Defines window.BBTTool (depends on AppConfig, MapInit)
5. ui-handlers.js     → Defines window.UIHandlers (depends on LayerManager, MapInit, BBTTool)
6. app.js             → Defines window.App (depends on ALL above modules)
```

### Dependency Analysis

| Module | Provides | Depends On | Status |
|--------|----------|------------|--------|
| **config.js** | `window.AppConfig`, `window.BaseMaps` | None | ✅ No deps |
| **map-init.js** | `window.MapInit` | `AppConfig`, `BaseMaps` | ✅ Available |
| **layer-manager.js** | `window.LayerManager` | `AppConfig`, `MapInit` | ✅ Available |
| **bbt-tool.js** | `window.BBTTool` | `AppConfig`, `MapInit` | ✅ Available |
| **ui-handlers.js** | `window.UIHandlers` | `LayerManager`, `MapInit`, `BBTTool` | ✅ Available |
| **app.js** | `window.App` | All above | ✅ Available |

**Status:** ✅ Perfect dependency order - no circular dependencies, all modules load sequentially

---

## 5. Map and Layer Initialization ✅ CORRECT

### Initialization Sequence (app.js:initApp)

```javascript
Step 1: map = window.MapInit.initMap()
        ↓
Step 2: vectorLayerGroup = L.layerGroup().addTo(map)
        ↓
Step 3: window.LayerManager.init(map, vectorLayerGroup)
        ↓
Step 4: window.UIHandlers.init()
        ↓
Step 5: BBT Tool background initialization
        ↓
Step 6: await loadInitialLayers()
        ↓
Step 7: populateLayerDropdowns()
```

### Layer Manager Initialization (layer-manager.js:116-123)
```javascript
function init(mapInstance, vectorGroup) {
    map = mapInstance;
    vectorLayerGroup = vectorGroup || L.layerGroup();
    setupMapEventHandlers();
    console.log('✅ Layer manager initialized');
}
```

### Vector Layer Loading Flow
```javascript
loadInitialLayers() [app.js:72]
    ↓
window.LayerManager.loadVectorLayerFast('Bbt - Merged') [app.js:88]
    ↓
fetchLayerGeoJSON() [layer-manager.js:~900]
    ↓
processVectorLayerData(geojson, layerName) [layer-manager.js:~935]
    ↓
L.geoJSON(geojson, {...}) creates Leaflet layer
    ↓
vectorLayerGroup.addLayer(geoJsonLayer)
    ↓
map.addLayer(vectorLayerGroup) if not already added
```

**Status:** ✅ Initialization sequence is correct and well-ordered

---

## 6. BBT Data Verification ✅ CONFIRMED

### GPKG File
- **Location:** `data/vector/BBT.gpkg`
- **Size:** 2.0 MB
- **Features:** 11 BBT areas
- **CRS:** EPSG:3035 (reprojected to EPSG:4326 by Flask)

### API Response Test
```bash
curl http://localhost:5000/api/vector/layer/Bbt%20-%20Merged
```
**Result:** HTTP 200, GeoJSON with 11 features including "Lithuanian coastal zone"

**Status:** ✅ Data file is correct and API serving properly

---

## 7. Current Debug Configuration

### Debugging Features Active
1. **Template injection logging** (templates/index.html:264-267)
   - Logs WMS, HELCOM, vector layer counts

2. **Layer loading debug** (app.js:75-92)
   - Logs vectorLayers array
   - Logs layer discovery and loading calls

3. **Layer manager debug** (layer-manager.js:900-991)
   - Logs GeoJSON feature count
   - Logs layer bounds
   - Logs vectorLayerGroup operations
   - Logs map addition

4. **EUNIS overlay disabled** (app.js:100-109)
   - Temporarily disabled to test visibility hypothesis
   - Layer dropdown set to "none"

---

## 8. Diagnosis: Layer Visibility Issue

### Evidence
- ✅ API returns data (HTTP 200, 11 features)
- ✅ No JavaScript errors in console
- ✅ All code is consistent and correct
- ✅ Template variables injected properly
- ✅ Modules load in correct order
- ✅ Initialization sequence is correct
- ❌ BBT features not visible on map

### Most Likely Cause: **Z-Index / Layer Ordering**

**Hypothesis:** WMS overlay (EUNIS seabed habitat layer) is rendering on top of the vector layer, covering the BBT polygons.

### Test in Progress
- EUNIS overlay loading has been disabled (app.js:101-103)
- User needs to **hard refresh (Ctrl+F5 / Cmd+Shift+R)** to clear cache
- If BBT features appear → **z-index issue confirmed**
- If BBT features still hidden → need to examine DEBUG trace

---

## 9. Expected Console Output (After Fix)

```
📊 Template data injected:
  - WMS layers: 45
  - HELCOM layers: 218
  - Vector layers: 1

🚀 MARBEFES BBT Database - Initializing application...
📍 Step 1: Initializing map...
📊 Step 2: Vector layer group created
🗺️ Step 3: Initializing layer manager...
✅ Layer manager initialized
🎛️ Step 4: Initializing UI handlers...
🔍 Step 5: Initializing BBT navigation tool...
🌊 Step 6: Loading initial layers...
🔄 Loading BBT vector layers...
DEBUG: window.vectorLayers = [{display_name: "Bbt - Merged", ...}]
DEBUG: Found 1 vector layers
DEBUG: Available layers: ["Bbt - Merged"]
DEBUG: mainLayer = {display_name: "Bbt - Merged", feature_count: 11, ...}
DEBUG: Calling loadVectorLayerFast with: Bbt - Merged
DEBUG LayerManager: loadVectorLayerFast called with layerName = Bbt - Merged
DEBUG processVectorLayerData: Called with layerName = Bbt - Merged
DEBUG processVectorLayerData: GeoJSON has 11 features
DEBUG processVectorLayerData: Created GeoJSON layer, bounds: [[lat, lng], [lat, lng]]
DEBUG processVectorLayerData: Added layer to vectorLayerGroup, layer count: 1
DEBUG processVectorLayerData: Added vectorLayerGroup to map
✅ Main BBT layer loaded
⚠️ EUNIS overlay loading DISABLED for debugging
✅ Application initialization complete!
```

---

## 10. Recommended Next Steps

### Immediate Actions
1. **User: Hard refresh browser** (Ctrl+F5 / Cmd+Shift+R)
2. **User: Check browser console** for DEBUG messages
3. **User: Report if BBT polygons now visible**

### If BBT Features Appear (Overlay Issue Confirmed)
- **Solution:** Ensure vector layer has higher z-index than WMS overlays
- **Fix:** Add vector layer to a pane with higher z-index or use `bringToFront()`
- **Re-enable:** EUNIS overlay with proper layer ordering

### If BBT Features Still Hidden (Deeper Issue)
- **Analyze:** Full DEBUG console trace from user
- **Check:** Layer bounds (features might be outside visible area)
- **Check:** Style rendering (invisible fill/stroke colors)
- **Check:** Browser cache (HTTP 304 vs HTTP 200)

---

## 11. Audit Conclusion

✅ **ALL CODE SYSTEMS ARE CONSISTENT AND CORRECT**

No inconsistencies found in:
- Flask template variable injection
- Layer name references
- API endpoint configuration
- JavaScript module loading order
- Map and layer initialization sequence

**The BBT display issue is NOT caused by code inconsistencies.**

**Most likely cause:** Layer ordering/z-index issue where WMS overlay covers vector features.

**Current test:** EUNIS overlay disabled, awaiting user confirmation.

---

## Appendix: Files Audited

### Backend
- `app.py` - Flask routes and template rendering

### Frontend HTML
- `templates/index.html` - Template variable injection, module loading

### JavaScript Modules
- `static/js/config.js` - Configuration and defaults
- `static/js/map-init.js` - Map initialization
- `static/js/layer-manager.js` - Layer management and rendering
- `static/js/bbt-tool.js` - BBT navigation tool
- `static/js/ui-handlers.js` - UI event handlers
- `static/js/app.js` - Application orchestrator

### Data
- `data/vector/BBT.gpkg` - BBT area geometries

### API Endpoints Tested
- `GET /api/vector/layer/Bbt%20-%20Merged` ✅ HTTP 200

---

*Audit completed: 2025-10-07 00:45 UTC*
