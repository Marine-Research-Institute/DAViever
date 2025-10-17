# Vector Layer Fix - Complete Solution

## Problem Summary

The vector layers were failing to load with "404 Not Found" errors because of a **layer ID mismatch** between frontend and backend:

- **Frontend** was using `display_name` format: `"Bbts - Broad Belt Transects"`
- **Backend** expected `source_file/layer_name` format: `"BBts.gpkg/Broad Belt Transects"`

## Changes Made

### 1. Frontend Updates (index.html) ✅ COMPLETED

Updated `/var/www/marbefes-bbt/templates/index.html` to use the correct layer ID format in 7 locations:

| Line | Old Code | New Code |
|------|----------|----------|
| 590 | `'Bbts - Broad Belt Transects'` | `'BBts.gpkg/Broad Belt Transects'` |
| 757 | `'Bbts - Broad Belt Transects'` | `'BBts.gpkg/Broad Belt Transects'` |
| 1877 | `loadVectorLayer(layer.display_name)` | ``loadVectorLayer(`${layer.source_file}/${layer.layer_name}`)`` |
| 2134 | `'Bbts - Broad Belt Transects'` | `'BBts.gpkg/Broad Belt Transects'` |
| 2140 | `'Bbts - Broad Belt Transects'` | `'BBts.gpkg/Broad Belt Transects'` |
| 2166 | `'Bbts - Broad Belt Transects'` | `'BBts.gpkg/Broad Belt Transects'` |
| 2175 | `'Bbts - Broad Belt Transects'` | `'BBts.gpkg/Broad Belt Transects'` |
| 2658 | `loadVectorLayerFast(bbtLayer.display_name)` | ``loadVectorLayerFast(`${bbtLayer.source_file}/${bbtLayer.layer_name}`)`` |
| 2662 | `loadVectorLayerFast(vectorLayers[0].display_name)` | ``loadVectorLayerFast(`${vectorLayers[0].source_file}/${vectorLayers[0].layer_name}`)`` |

**Result:** Frontend now sends correct API requests like:
```
/api/vector/layer/BBts.gpkg/Broad Belt Transects
```

### 2. Backend Updates (vector_loader.py) ✅ READY TO DEPLOY

Updated `/home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/src/emodnet_viewer/utils/vector_loader.py`:

**Before (line 307-312):**
```python
def get_layer_by_name(self, display_name: str) -> Optional[VectorLayer]:
    """Get a loaded layer by its display name"""
    for layer in self.loaded_layers:
        if layer.display_name == display_name:
            return layer
    return None
```

**After:**
```python
def get_layer_by_name(self, layer_identifier: str) -> Optional[VectorLayer]:
    """Get a loaded layer by its display name or source_file/layer_name identifier"""
    for layer in self.loaded_layers:
        # Try display_name first (backward compatibility)
        if layer.display_name == layer_identifier:
            return layer
        # Try source_file/layer_name format (new robust format)
        layer_id = f"{layer.source_file}/{layer.layer_name}"
        if layer_id == layer_identifier:
            return layer
    return None
```

**Result:** Backend now accepts both formats for backward compatibility.

## How to Apply the Fix

Run the automated fix script:

```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

This script will:
1. ✅ Copy updated `vector_loader.py` to `/var/www/marbefes-bbt/src/emodnet_viewer/utils/`
2. ✅ Copy necessary `__init__.py` files
3. ✅ Set proper ownership (www-data:www-data)
4. ✅ Verify frontend updates are in place
5. ✅ Restart the marbefes-bbt service
6. ✅ Test the API to confirm it works

## Verification Steps

After running the script:

### 1. Check Service Status
```bash
systemctl status marbefes-bbt
```
Should show: `Active: active (running)`

### 2. Test API Manually
```bash
# Should return 9 features (not 404)
curl "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects" | jq '.features | length'
```

### 3. Test in Browser
1. Open http://laguna.ku.lt/BBTS
2. Clear browser cache (Ctrl+F5)
3. Open browser console (F12)
4. Look for these success messages:
   ```
   📡 Fetching from URL: /api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects
   ✅ BBT features loaded successfully: 9 features
   ```

### 4. Visual Verification
- Vector layers should now display on the map
- Hover tooltips should show feature information
- Area calculations should work

## Layer IDs Reference

After the fix, these are the correct layer IDs:

| Display Name | Correct Layer ID | Features | Type |
|--------------|------------------|----------|------|
| Bbts - Merged | `BBts.gpkg/merged` | 6 | MultiPolygon |
| Bbts - Broad Belt Transects | `BBts.gpkg/Broad Belt Transects` | 9 | MultiPolygon |
| Checkedbbt - Merged | `CheckedBBT.gpkg/merged` | 11 | MultiPolygon |

## Technical Details

### Why This Fix Works

1. **Frontend Consistency**: All layer references now use the same `source_file/layer_name` format that the API returns in metadata
2. **Backend Flexibility**: The lookup function tries both formats, ensuring backward compatibility
3. **No Breaking Changes**: Old display names still work if used directly
4. **Future-Proof**: New layers automatically work with the consistent ID format

### Files Modified

- ✅ `/var/www/marbefes-bbt/templates/index.html` (frontend fixes applied)
- ⏳ `/var/www/marbefes-bbt/src/emodnet_viewer/utils/vector_loader.py` (needs to be copied from source)

### Source Files Updated

- ✅ `/home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/src/emodnet_viewer/utils/vector_loader.py`

## Rollback (if needed)

If something goes wrong:

```bash
# Restore from automatic backup (created by create_vector_fix.sh)
sudo cp /var/www/marbefes-bbt/templates/index.html.backup.* /var/www/marbefes-bbt/templates/index.html

# Restart service
sudo systemctl restart marbefes-bbt
```

## What's Next

After applying this fix:
1. ✅ Vector layers will load correctly
2. ✅ All 3 GPKG layers accessible
3. ✅ Hover tooltips functional
4. ✅ Area calculations working

The application will be **fully operational** with both WMS and vector layer support!

---

**Status**: Frontend ✅ Updated | Backend ⏳ Ready to Deploy

**Action Required**: Run `sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh`
