# BBT Display Debugging Status

## Current State
- ✅ Server running and loading data correctly
- ✅ API returning 11 BBT features (HTTP 200)
- ✅ No JavaScript errors in console
- ❌ BBT features not visible on map

## Hypothesis
**Layer ordering issue**: EUNIS WMS overlay may be covering BBT vector layer

## Changes Made for Testing

### 1. Disabled EUNIS Overlay Loading
**File:** `static/js/app.js:100-109`
- Commented out `selectWMSLayerAsOverlay(defaultEUNISLayer)`
- Set layer dropdown to "none"
- This removes any overlays that might hide BBT features

### 2. Added Comprehensive Debugging
**Files with DEBUG logging:**
- `templates/index.html` - Template data injection
- `static/js/app.js` - Layer loading initialization
- `static/js/layer-manager.js` - Layer processing and map addition

### 3. Debug Messages to Look For
```
📊 Template data injected:
  - Vector layers: 1
DEBUG: window.vectorLayers = [...]
DEBUG: Calling loadVectorLayerFast with: Bbt - Merged
DEBUG LayerManager: loadVectorLayerFast called
DEBUG processVectorLayerData: Called with layerName = Bbt - Merged
DEBUG processVectorLayerData: GeoJSON has 11 features
DEBUG processVectorLayerData: Created GeoJSON layer, bounds: ...
DEBUG processVectorLayerData: Added layer to vectorLayerGroup
DEBUG processVectorLayerData: Added vectorLayerGroup to map
✅ Main BBT layer loaded
```

## Expected Visual Result
With EUNIS overlay disabled, you should see:
- Base map (satellite/OSM tiles)
- **Turquoise/teal colored polygons** for 11 BBT areas
- Polygons should be visible across Europe

## If BBT Features Appear
→ Issue is z-index/layer ordering
→ Need to ensure vector layer renders ABOVE WMS overlays

## If BBT Features Still Don't Appear
→ Issue might be with:
  - Layer bounds (features outside visible area)
  - Style rendering (invisible colors)
  - Vector layer not added to map
  - Browser cache still serving old files

## Next Steps
1. Hard refresh (Ctrl+F5 / Cmd+Shift+R)
2. Check console for DEBUG messages
3. Look for turquoise polygons on map
4. Report findings

---
*Testing in progress: 2025-10-07 00:22 UTC*
