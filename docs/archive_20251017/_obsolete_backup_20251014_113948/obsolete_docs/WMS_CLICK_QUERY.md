# WMS Layer Click Query Feature

## Overview

The MARBEFES BBT application now supports clicking on EMODnet WMS (Web Map Service) layers to query feature information. This allows users to interactively explore seabed habitat data by clicking directly on the map.

## Feature Status

✅ **Fully Implemented and Active**

The WMS GetFeatureInfo functionality has been implemented and is automatically enabled for all EMODnet and HELCOM WMS layers loaded in the application.

## How It Works

### User Experience

1. **Load a WMS Layer**
   - Select any EMODnet overlay from the "Layer Overlays" dropdown
   - Or wait for the default EUNIS 2019 layer to auto-load when zoomed in

2. **Click on the Map**
   - Click anywhere on the map where the WMS layer is visible
   - The application will query the WMS server for feature information at that location

3. **View Feature Information**
   - A popup appears showing attribute data from the clicked location
   - Information is formatted as HTML for easy reading
   - If no data is available, a message indicates this

### Example Workflow

```
User Action → System Response
──────────────────────────────────────────────────────────────
Select "EUNIS 2019" layer → WMS overlay loads on map

Click on coastal area → Status: "Getting feature info..."
                      → Popup shows habitat classification data

Click on open ocean → Popup shows "No information available"
                    → (Area outside dataset coverage)
```

## Technical Implementation

### Architecture

The click query system uses the WMS GetFeatureInfo standard:

1. **Click Handler Setup** (`setupGetFeatureInfo`)
   - Registers a map click event listener
   - Stores the current layer name and WMS base URL
   - Removes previous handlers to avoid conflicts

2. **Click Processing** (`handleMapClick`)
   - Captures click coordinates (lat/lng)
   - Converts to pixel coordinates for the WMS request
   - Builds the GetFeatureInfo URL with proper parameters

3. **GetFeatureInfo Request** (`buildGetFeatureInfoUrl`)
   - Constructs WMS 1.1.0 GetFeatureInfo URL
   - Includes bounding box, layer name, click coordinates
   - Requests HTML format response

4. **Response Display** (`displayFeatureInfo`)
   - Fetches feature information from WMS server
   - Parses HTML response
   - Shows in Leaflet popup at click location

### Code Locations

**File:** `templates/index.html`

| Function | Line | Purpose |
|----------|------|---------|
| `setupGetFeatureInfo` | 1082 | Set up click handler for layer |
| `handleMapClick` | 1096 | Process map click event |
| `buildGetFeatureInfoUrl` | 1144 | Build WMS GetFeatureInfo URL |
| `displayFeatureInfo` | 1170 | Show feature info in popup |

### WMS Layers with Click Query

All WMS layers automatically support click queries:

✅ **EMODnet Layers** (via `{{ WMS_BASE_URL }}`)
- EUSeaMap 2021/2023 layers
- EUNIS habitat classifications
- Substrate types
- Confidence assessments
- Annex I habitats
- OSPAR threatened habitats

✅ **HELCOM Layers** (via `{{ HELCOM_WMS_BASE_URL }}`)
- Baltic Sea environmental pressure data
- Marine spatial planning layers

### Integration Points

The `setupGetFeatureInfo()` function is called in these locations:

1. **Line 1222** - `updateWMSLayer()` - When WMS layer updates
2. **Line 1723** - `selectWMSLayer()` - When selecting WMS as base layer
3. **Line 1751** - `selectWMSLayerAsOverlay()` - When selecting WMS overlay ⭐ **ADDED**
4. **Line 1779** - `selectHELCOMLayerAsOverlay()` - When selecting HELCOM overlay ⭐ **ADDED**
5. **Line 1957** - `loadFallbackWMSLayer()` - When loading fallback layer
6. **Line 2032** - `loadEuropeanEuSeaMapLayer()` - When loading European layer

## Recent Improvements

### Changes Made

#### 1. Enhanced Function Signatures ✅
Added optional `wmsBaseUrl` parameter to support multiple WMS endpoints:

```javascript
// Before
function setupGetFeatureInfo(layerName)
function buildGetFeatureInfoUrl(layerName, bounds, width, height, x, y)

// After
function setupGetFeatureInfo(layerName, wmsBaseUrl)
function buildGetFeatureInfoUrl(layerName, bounds, width, height, x, y, wmsBaseUrl)
```

#### 2. Added Missing Integration Points ✅

**`selectWMSLayerAsOverlay()` - Line 1751**
- This is the primary function used for overlay selection
- Was missing `setupGetFeatureInfo()` call
- Now properly enables click queries for WMS overlays

**`selectWMSLayer()` - Line 1723**
- Used when WMS is selected as base layer
- Was missing `setupGetFeatureInfo()` call
- Now properly enables click queries

**`selectHELCOMLayerAsOverlay()` - Line 1779**
- Enables click queries for HELCOM Baltic Sea data
- Uses HELCOM WMS base URL

#### 3. Multi-Endpoint Support ✅

The system now supports querying different WMS servers:

```javascript
// EMODnet layers (default)
setupGetFeatureInfo(layerName)

// HELCOM layers (explicit URL)
setupGetFeatureInfo(layerName, '{{ HELCOM_WMS_BASE_URL }}')
```

## GetFeatureInfo Request Format

### Request Parameters

```
service=WMS
version=1.1.0
request=GetFeatureInfo
layers=eusm_2023_eunis2019_full
query_layers=eusm_2023_eunis2019_full
styles=
bbox=10.5,53.5,11.5,54.5
width=1024
height=768
format=image/png
info_format=text/html
srs=EPSG:4326
x=512
y=384
```

### Response Format

The application requests `info_format=text/html`, which returns formatted HTML containing:
- Feature attributes
- Classification codes
- Habitat descriptions
- Confidence values
- Any additional metadata

## User Interface

### Status Indicators

| Status Message | Meaning |
|----------------|---------|
| "Getting feature info..." | Querying WMS server |
| Layer name visible | Query complete, showing results |
| "No information available" | Click location has no data |

### Popup Behavior

- **Maximum Width:** 350px
- **Maximum Height:** 450px
- **Scrolling:** Auto (if content exceeds height)
- **Close Button:** Yes
- **Auto-close:** No (stays open until manually closed)
- **Close on Escape:** Yes
- **Auto-pan:** Yes (map pans to keep popup visible)

## Error Handling

### Scenarios

1. **No Data at Location**
   - Shows: "No information available - This area has no data for the selected layer"
   - Common in areas outside dataset coverage

2. **Network Error**
   - Shows: "No information available - Click elsewhere to try again"
   - Logs error to console for debugging

3. **Invalid Response**
   - Shows: "No information available"
   - Handles empty or malformed responses gracefully

## Performance Considerations

- **Single Active Handler:** Only one layer's click handler is active at a time
- **Lightweight Requests:** GetFeatureInfo requests are small (<10KB typically)
- **Non-blocking:** Uses async fetch() to avoid freezing the UI
- **Timeout:** Inherits browser default timeouts (typically 30-60 seconds)

## Limitations

### Known Constraints

1. **Single Layer Query**
   - Only queries the currently active WMS layer
   - Does not query multiple overlapping layers simultaneously

2. **WMS Server Dependent**
   - Feature info availability depends on server configuration
   - Some layers may not support GetFeatureInfo

3. **Format Limitation**
   - Currently requests HTML format only
   - Could be extended to support GML, JSON, etc.

4. **No Spatial Tolerance**
   - Queries exact pixel location
   - Small features may be hard to click

## Future Enhancements

### Potential Improvements

1. **Multi-Layer Query**
   - Query all visible WMS/HELCOM layers in one click
   - Show combined results in tabbed popup

2. **Alternative Formats**
   - Support GeoJSON response parsing
   - Structured data display with better formatting

3. **Query Radius**
   - Add pixel tolerance for small features
   - Make it easier to click on point/line features

4. **Query History**
   - Remember previous queries
   - Allow navigation between recent results

5. **Export Results**
   - Copy feature info to clipboard
   - Export as CSV or JSON

## Testing

### Verification Steps

1. **Basic Click Query**
   ```
   1. Load application: http://laguna.ku.lt/BBTS
   2. Zoom to BBT coverage area (zoom >= 8)
   3. Wait for EUNIS 2019 layer to auto-load
   4. Click on a colored area
   5. Verify popup appears with habitat data
   ```

2. **Different Layers**
   ```
   1. Select "EUSeaMap 2021 - All Habitats" from dropdown
   2. Click on different map areas
   3. Verify feature info matches selected layer
   ```

3. **HELCOM Layers**
   ```
   1. Navigate to Baltic Sea
   2. Select a HELCOM layer from dropdown
   3. Click on the map
   4. Verify HELCOM data appears
   ```

4. **No Data Handling**
   ```
   1. Click on open ocean or land area
   2. Verify "No information available" message
   ```

### Browser Console Checks

```javascript
// Check if click handler is registered
map.listens('click') // Should return true

// Monitor GetFeatureInfo requests
// Open Network tab in DevTools
// Click on map
// Look for requests to WMS with "GetFeatureInfo"
```

## Support

### Troubleshooting

**Problem:** Clicking on map does nothing

**Solutions:**
- Check if a WMS layer is loaded (visible in overlay)
- Open browser console for JavaScript errors
- Verify WMS service is responding (check Network tab)
- Try different layer from dropdown

**Problem:** Popup shows "No information available" everywhere

**Solutions:**
- Layer may not have data in the visible area
- Try zooming to a different location
- Try a different layer
- Check if WMS service supports GetFeatureInfo

**Problem:** Slow response after clicking

**Solutions:**
- WMS server may be under load
- Complex layers take longer to query
- Network latency to EMODnet servers
- Wait a few seconds and try again

## Related Documentation

- `CLAUDE.md` - Project overview and architecture
- `LOGO_FIX.md` - Subpath URL fix (relevant for API calls)
- `README_DEPLOYMENT.md` - Deployment procedures

---

**Feature Status:** ✅ Production Ready
**Last Updated:** 2025-10-03
**Version:** 1.0
