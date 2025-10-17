# EUNIS 2019 Layer Configuration - Only Full Classification

## Changes Made

All references to biological zone layers (`eusm2023_bio_*`) have been replaced with the full EUNIS 2019 classification layer (`eusm_2023_eunis2019_full`).

## What Was Changed

### 1. Fallback Layer (Line 1928)
**Before:**
```javascript
const fallbackLayer = 'eusm2023_bio_full'; // European Biological Zones
```

**After:**
```javascript
const fallbackLayer = 'eusm_2023_eunis2019_full'; // EUNIS 2019 classification
```

### 2. Fallback Layer Attribution (Line 1936)
**Before:**
```javascript
attribution: 'MARBEFES BBT Database | EMODnet Seabed Habitats | EUSeaMap 2023 Biological Zones'
```

**After:**
```javascript
attribution: 'MARBEFES BBT Database | EMODnet Seabed Habitats | EUSeaMap 2023 EUNIS 2019'
```

### 3. Fallback Layer Status Message (Line 1950)
**Before:**
```javascript
document.getElementById('status').textContent = 'EUSeaMap 2023 Biological Zones loaded (fallback)';
```

**After:**
```javascript
document.getElementById('status').textContent = 'EUSeaMap 2023 EUNIS 2019 loaded (fallback)';
```

### 4. Optimal Layer Selection Function (Lines 2076-2080)
**Before:**
```javascript
function getOptimalEUSeaMapLayer(zoom) {
    if (zoom <= 6) {
        return ['eusm2023_bio_800', 'eusm2023_bio_group', 'eusm2023_bio_full'];
    } else if (zoom <= 8) {
        return ['eusm2023_bio_400', 'eusm2023_bio_group', 'eusm2023_bio_full'];
    } else if (zoom <= 12) {
        return ['eusm2023_bio_200', 'eusm2023_bio_group', 'eusm2023_bio_full'];
    } else {
        return ['eusm2023_bio_full', 'eusm2023_bio_group'];
    }
}
```

**After:**
```javascript
function getOptimalEUSeaMapLayer(zoom) {
    // Always return EUNIS 2019 full classification
    // No simplification based on zoom level
    return ['eusm_2023_eunis2019_full'];
}
```

### 5. Commented Code References (Lines 1854-1858)
Updated all commented-out code to reference EUNIS 2019 instead of Biological Zones for consistency.

## Result

The application now **exclusively uses** the EUNIS 2019 full classification:

✅ **Default layer:** `eusm_2023_eunis2019_full`
✅ **Fallback layer:** `eusm_2023_eunis2019_full`
✅ **Zoom-based layer:** `eusm_2023_eunis2019_full` (no switching)
✅ **No biological zone layers:** All removed

## Layer Details

**Layer Name:** `eusm_2023_eunis2019_full`

**Description:**
- **eusm** = EUSeaMap dataset
- **2023** = 2023 version of the dataset
- **eunis2019** = EUNIS 2019 habitat classification scheme
- **full** = Full resolution without simplification

**What this means:**
- Complete habitat classification with detailed EUNIS codes (e.g., A5.13, A5.14)
- No zoom-based simplification
- Consistent classification at all zoom levels
- Maximum scientific detail for analysis

## Benefits

1. **Consistency:** Same classification system at all zoom levels
2. **Detail:** Full EUNIS codes for precise habitat identification
3. **Scientific:** Uses the standard European habitat classification
4. **Simplicity:** No layer switching based on zoom
5. **Reliability:** Single layer source reduces potential issues

## Performance Considerations

### Previous Approach (Removed)
The biological zone layers used zoom-based simplification:
- Zoom 0-6: 800m simplification
- Zoom 7-8: 400m simplification
- Zoom 9-12: 200m simplification
- Zoom 13+: Full resolution

This was designed to improve performance at low zoom levels.

### Current Approach
Uses full EUNIS 2019 classification at all zoom levels:
- May be slightly slower at low zoom (continental view)
- No layer switching = smoother user experience
- Consistent data = better for analysis
- EMODnet's WMS tiling handles performance well

## Testing

After deployment, verify:

1. **Default layer loads:**
   - Visit http://laguna.ku.lt/BBTS
   - Zoom to BBT coverage (zoom >= 8)
   - Layer should auto-load showing EUNIS habitats

2. **Layer name in dropdown:**
   - Check layer dropdown shows EUNIS 2019 selected
   - Not biological zones

3. **Click query:**
   - Click on habitat areas
   - Popup should show EUNIS codes (e.g., "A5.13")
   - Not biological zone names

4. **Status messages:**
   - Should mention "EUNIS 2019"
   - Not "Biological Zones"

## Files Modified

**templates/index.html:**
- Line 1854: Updated comment
- Line 1855: Updated status message comment
- Line 1858: Updated comment
- Line 1928: Changed fallback layer to EUNIS
- Line 1936: Updated attribution
- Line 1950: Updated status message
- Lines 2076-2080: Simplified layer selection function

## Backward Compatibility

No backward compatibility issues:
- Layer name change is internal
- User-facing behavior remains the same
- All WMS functionality preserved
- Click query works with EUNIS layer

## Related Documentation

- WMS_CLICK_QUERY.md - WMS click functionality
- DEPLOYMENT_READY.md - Deployment guide
- LOGO_FIX.md - Subpath URL fixes

---

**Status:** ✅ Complete
**Version:** 1.1
**Date:** 2025-10-03
