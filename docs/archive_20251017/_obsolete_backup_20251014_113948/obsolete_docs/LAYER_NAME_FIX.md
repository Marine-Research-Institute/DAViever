# BBT Layer Name Fix - COMPLETE ✅

## Issue Identified
After consolidating GPKG files, the BBT layer name changed from:
- **Old:** `"Bbt - Bbt Areas"` (referenced in JavaScript)
- **New:** `"Bbt - Merged"` (actual layer name in consolidated file)

## Error Encountered
```
GET /api/vector/layer/Bbt%20-%20Bbt%20Areas HTTP/1.1" 404
Error: Layer 'Bbt - Bbt Areas' not found
```

## Fix Applied
Updated all 8 references in `static/js/bbt-tool.js`:

### Lines Updated:
1. Line 156 - `loadBBTFeatures()` API URL
2. Line 359 - `zoomToBBTArea()` layer selection
3. Line 392 - Current layer state assignment
4. Line 414 - Layer loaded check condition
5. Line 427 - Load layer without auto-zoom call
6. Line 454 - Fetch API URL in zoom function
7. Line 481 - Load layer call in zoom handler
8. Line 492 - Fallback layer loading

### Changes Made:
```javascript
// BEFORE (all 8 locations):
'Bbt - Bbt Areas'

// AFTER (all 8 locations):
'Bbt - Merged'
```

## Verification
✅ All references updated successfully
✅ API endpoint tested: `/api/vector/layer/Bbt%20-%20Merged`
✅ Returns 11 features correctly
✅ First feature confirmed: "Archipelago"

## Root Cause
The consolidation process merged all layers from the GPKG file into a single layer called "merged", which the vector loader then displays as "Bbt - Merged" (combining the filename prefix "Bbt" with the layer name "merged").

## Status
**COMPLETE** - BBT tool should now load correctly without 404 errors.

---
*Fixed: 2025-10-06 23:50 UTC*
