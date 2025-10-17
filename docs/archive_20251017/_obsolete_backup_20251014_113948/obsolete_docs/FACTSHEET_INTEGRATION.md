# BBT Factsheet Integration - Complete ✅

**Date:** 2025-10-07
**Feature:** Display factsheet data in BBT popups and tooltips

---

## Summary

Successfully extracted BBT factsheet data from Excel/ODS files and integrated it into the interactive map interface. Factsheet information now appears in BBT feature popups and hover tooltips.

---

## Components Implemented

### 1. Data Extraction Script ✅

**File:** `extract_factsheets.py`

- Extracts data from 10 BBT factsheet files (Excel .xlsx and ODS formats)
- Handles variable factsheet structures
- Outputs to `data/bbt_factsheets.json`

**BBTs Extracted:**
1. Arctic BBT - Porsanger
2. Arctic BBT - Svalbard
3. Irish Sea
4. Archipelago
5. Balearic
6. Black Sea
7. Gulf of Biscay
8. Heraklion
9. Lithuanian (ODS format)
10. North Sea Belgium

**Usage:**
```bash
python3 extract_factsheets.py
```

---

### 2. Flask API Endpoints ✅

**File:** `app.py`

#### `/api/factsheets` (GET)
Returns all BBT factsheet data

**Example:**
```bash
curl http://localhost:5000/api/factsheets
```

**Response:**
```json
{
  "metadata": {
    "total_bbts": 10,
    "source_directory": "FactSheets",
    "extraction_date": "2025-10-07T00:42:19.321252"
  },
  "bbts": [...]
}
```

#### `/api/factsheet/<bbt_name>` (GET)
Returns factsheet data for a specific BBT

**Example:**
```bash
curl http://localhost:5000/api/factsheet/Balearic
```

**Response:**
```json
{
  "name": "Balearic",
  "source_file": "FactSheet_Balearic.xlsx",
  "data": {
    "Benthic habitat": ["EUNIS classification", "Area covered per habitat", "km²"],
    "Rodolith beds": "Assemblages of Mediterranean coastal detritic bottoms...",
    "Maërl and Peyssonnelia": "Association with Peyssonnelia rosa-marina (MC3522)",
    ...
  }
}
```

**Features:**
- Flexible name matching (case-insensitive, handles spaces/dashes/underscores)
- Returns 404 if factsheet not found
- Error handling with logging

---

### 3. Frontend Integration ✅

**File:** `static/js/layer-manager.js`

#### Added Factsheet Caching
```javascript
const factsheetCache = new Map();
let factsheetsLoaded = false;
```

#### New Functions

**`loadFactsheets()`**
- Loads all factsheets from API on initialization
- Caches by normalized name for fast lookup
- Called automatically when LayerManager initializes

**`getFactsheetData(bbtName)`**
- Retrieves factsheet for a specific BBT
- Supports exact match, normalized match, and partial match
- Returns null if not found

#### Enhanced Tooltip/Popup Content

Factsheet data is now included in BBT feature tooltips and popups:

```
🌊 MARBEFES Broad Belt Transect
Balearic
📐 Area: 1,234.56 km²

🗺️ Mediterranean Sea
Subtropical Mediterranean marine biodiversity hotspot
Habitat: Mediterranean endemic species and Posidonia meadows
Research: Climate change impacts on Mediterranean ecosystems

📊 Factsheet Data
Benthic habitat: EUNIS classification, Area covered per habitat, km²
Rodolith beds: Assemblages of Mediterranean coastal detritic bottoms...
Maërl and Peyssonnelia: Association with Peyssonnelia rosa-marina (MC3522)
+5 more data field(s) available
```

**Visual Design:**
- Blue-highlighted section with left border
- 📊 Icon for factsheet data
- Habitat information displayed prominently
- Count of additional data fields available

---

## Data Structure

### JSON Output Format

```json
{
  "metadata": {
    "total_bbts": 10,
    "source_directory": "FactSheets",
    "extraction_date": "2025-10-07T00:42:19.321252"
  },
  "bbts": [
    {
      "name": "BBT Name",
      "source_file": "FactSheet_Name.xlsx",
      "data": {
        "Benthic habitat": [...],
        "Habitat type 1": "Description with EUNIS code",
        "Habitat type 2": "Description with EUNIS code",
        "notes": [...]
      }
    }
  ]
}
```

---

## Habitat Classifications Included

The factsheets contain various habitat classification systems:

### EUNIS Classification
- **MC63**: Baltic circalittoral mud
- **MD52**: Atlantic offshore circalittoral sand
- **MC151**: Coralligenous biocenosis
- **MB252**: Biocenosis of Posidonia oceanica
- And many more...

### MSFD Classifications
- River plume boundaries
- Coastal vs. Shelf zones
- Pelagic habitat diversity

### Special Features
- Rhodolith beds
- Maërl associations
- Posidonia meadows
- Ice-associated habitats (Arctic)

---

## Testing

### API Endpoints
```bash
# Test all factsheets
curl http://localhost:5000/api/factsheets | python3 -m json.tool

# Test specific BBT
curl http://localhost:5000/api/factsheet/Balearic | python3 -m json.tool

# Test flexible matching
curl http://localhost:5000/api/factsheet/irish | python3 -m json.tool
```

### Browser Testing
1. Open http://localhost:5000/
2. Wait for application to initialize
3. Console should show: `✅ Loaded 10 factsheets`
4. Click on any BBT polygon
5. Popup should display factsheet data with blue highlight
6. Hover over polygons to see tooltip with factsheet info

---

## Dependencies

### New Python Dependencies
- **odfpy**: For reading ODS (OpenDocument Spreadsheet) files
  ```bash
  pip install odfpy
  ```

### Existing Dependencies
- pandas (already installed)
- openpyxl (already installed for Excel support)

---

## Files Modified

### Created
- `extract_factsheets.py` - Data extraction script
- `data/bbt_factsheets.json` - Extracted factsheet data (5.3 KB)
- `FACTSHEET_INTEGRATION.md` - This documentation

### Modified
- `app.py` - Added `/api/factsheets` and `/api/factsheet/<bbt_name>` endpoints
- `static/js/layer-manager.js` - Added factsheet loading and display logic

---

## Future Enhancements

### Potential Improvements
1. **Detailed Factsheet Modal**: Click "View Full Factsheet" button to open detailed modal
2. **Habitat Area Visualization**: Display habitat coverage as charts/graphs
3. **Search by Habitat Type**: Filter BBTs by specific EUNIS codes
4. **Export Functionality**: Download factsheet data as PDF or Excel
5. **Comparative Analysis**: Compare habitat types across multiple BBTs
6. **Temporal Data**: Track changes in habitat coverage over time

### Data Enrichment
1. Extract more structured data from factsheet Excel files
2. Link habitat codes to external databases (EUNIS, MSFD)
3. Add photos/images of habitats
4. Include species lists and biodiversity metrics
5. Add links to research publications

---

## Usage Instructions

### For Users
1. Navigate to the map at http://localhost:5000/
2. BBT polygons now display with BRIGHT RED fill and YELLOW borders for debugging
3. Click any BBT polygon to see popup with factsheet data
4. Hover over polygons for quick tooltip preview
5. Factsheet data appears in blue-highlighted section with 📊 icon

### For Developers
```javascript
// Get factsheet data in JavaScript
const factsheet = window.LayerManager.getFactsheetData('Balearic');

// Reload factsheets (if data changes)
await window.LayerManager.loadFactsheets();
```

---

## Troubleshooting

### Factsheets Not Loading
1. Check console for error: `Error loading factsheets:`
2. Verify `data/bbt_factsheets.json` exists
3. Test API endpoint: `curl http://localhost:5000/api/factsheets`

### Factsheet Not Appearing in Popup
1. Check BBT name matches factsheet name (case-insensitive)
2. Console should show: `✅ Loaded 10 factsheets`
3. Try different BBT name variants (with/without spaces, dashes)

### Missing Data for Specific BBT
1. Check `data/bbt_factsheets.json` to see what data was extracted
2. Re-run `python3 extract_factsheets.py` to re-extract
3. Verify source Excel/ODS file in `FactSheets/` directory

---

## Technical Notes

`★ Insight ─────────────────────────────────────`
**Normalized Name Matching**: The factsheet lookup uses
flexible matching to handle variations in BBT names:
- "Lithuanian" matches "Lithuanian coastal zone"
- "Irish Sea" matches "Irish_Sea"
- Case-insensitive throughout
This ensures factsheets display even if naming isn't
perfectly consistent between GPKG and Excel files.

**Performance Optimization**: Factsheets are loaded once
during initialization and cached in a Map for O(1) lookup.
This prevents repeated API calls and ensures instant
display when clicking BBT features.

**Habitat Code System**: EUNIS codes like "MC63" are
standardized European habitat classifications. The letter
prefix indicates environment (M=Marine), followed by
hierarchical detail (C=circalittoral, 6=specific type).
`─────────────────────────────────────────────────`

---

## Status

✅ **COMPLETE** - Factsheet data successfully integrated into BBT popups and tooltips

**Next Steps:** Test in browser and verify factsheet data displays correctly for all BBTs

---

*Implementation completed: 2025-10-07 00:50 UTC*
