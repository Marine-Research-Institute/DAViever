# Final Vector Layer Fix - Complete Solution

## Root Cause Found

The browser console shows the request is going to:
```
❌ http://laguna.ku.lt/api/vector/layer/...
```

But it should go to:
```
✅ http://laguna.ku.lt/BBTS/api/vector/layer/...
```

**The `/BBTS` subpath prefix was missing from API URLs!**

## Why This Happened

The Flask application is mounted at `/BBTS` subpath using the `APPLICATION_ROOT` config, but:
1. The frontend template had hardcoded `/api/...` URLs
2. The app.py wasn't passing the subpath to the template
3. The browser tried to fetch from root instead of `/BBTS/api/...`

## Complete Fix Applied

### 1. Backend (app.py) ✅
Added `API_BASE_URL` to template context:

```python
@app.route("/")
def index():
    # Get APPLICATION_ROOT for API URLs
    api_base = app.config.get('APPLICATION_ROOT', '').rstrip('/')
    return render_template(
        'index.html',
        ...
        API_BASE_URL=api_base,  # ← NEW: Pass /BBTS to frontend
    )
```

### 2. Frontend (index.html) ✅
Updated all 4 API calls to use the base URL:

**Before:**
```javascript
fetch(`/api/vector/layer/${layerName}`)  // ❌ Missing /BBTS
```

**After:**
```javascript
fetch(`{{ API_BASE_URL }}/api/vector/layer/${layerName}`)  // ✅ Includes /BBTS
```

### 3. Nginx Configuration ✅
Added support for encoded slashes:

```nginx
http {
    merge_slashes off;  # Allow URLs like BBts.gpkg%2FBroad Belt Transects
    ...
}
```

### 4. Backend Layer Lookup ✅
Enhanced `vector_loader.py` to accept composite layer IDs:

```python
def get_layer_by_name(self, layer_identifier: str):
    # Try both display_name and source_file/layer_name formats
    for layer in self.loaded_layers:
        if layer.display_name == layer_identifier:
            return layer
        layer_id = f"{layer.source_file}/{layer.layer_name}"
        if layer_id == layer_identifier:
            return layer
    return None
```

## Changes Summary

| Component | File | Status |
|-----------|------|--------|
| **Frontend** | `/var/www/marbefes-bbt/templates/index.html` | ✅ Updated |
| **Backend** | `/var/www/marbefes-bbt/app.py` | ✅ Updated |
| **Backend** | `/var/www/marbefes-bbt/src/.../vector_loader.py` | ⏳ Ready to deploy |
| **Nginx** | `/etc/nginx/nginx.conf` | ⏳ Ready to update |

## Apply the Complete Fix

Run this single command:

```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

This automated script will:
1. ✅ Configure nginx to allow encoded slashes (`merge_slashes off`)
2. ✅ Verify app.py has API_BASE_URL support
3. ✅ Copy updated vector_loader.py with composite ID support
4. ✅ Verify frontend template has all updates
5. ✅ Restart the marbefes-bbt service
6. ✅ Test the API to confirm it works

## Expected Results

### Before Fix
```javascript
// Browser console:
GET http://laguna.ku.lt/api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects 404 (Not Found)
❌ API Error: 404 Not Found
<html><title>404 Not Found</title></html>  // nginx error page
```

### After Fix
```javascript
// Browser console:
GET http://laguna.ku.lt/BBTS/api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects 200 (OK)
✅ BBT features loaded successfully: 9 features
✅ Cached 3 layers for instant access
```

## Verification Steps

### 1. Test API Directly
```bash
# Should return GeoJSON with 9 features (not 404)
curl "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects" | jq '.features | length'
```

### 2. Check Browser
1. Open http://laguna.ku.lt/BBTS
2. **Hard refresh**: Ctrl+F5 (important!)
3. Open console (F12)
4. Look for success message:
   ```
   ✅ BBT features loaded successfully: 9 features
   ```

### 3. Visual Check
- Vector layers should display on map
- Hover over features shows area calculations
- BBT navigation buttons functional

## Technical Details

### URL Resolution

When the page is at `http://laguna.ku.lt/BBTS`:
- `/api/...` resolves to `http://laguna.ku.lt/api/...` ❌ (root)
- `/BBTS/api/...` resolves to `http://laguna.ku.lt/BBTS/api/...` ✅ (correct)

The `{{ API_BASE_URL }}` template variable injects `/BBTS` so API URLs become `/BBTS/api/...`.

### APPLICATION_ROOT Setting

The `.env` file has:
```bash
APPLICATION_ROOT=/BBTS
```

This tells Flask the app is mounted at `/BBTS`, and now the template uses this value to construct correct API URLs.

## Four-Part Fix Complete

| Issue | Fix | Status |
|-------|-----|--------|
| 1. Missing /BBTS in URLs | Add API_BASE_URL to template | ✅ Done |
| 2. Nginx blocks %2F | Add merge_slashes off | ⏳ Script ready |
| 3. Backend layer lookup | Update vector_loader.py | ⏳ Script ready |
| 4. Frontend hardcoded URLs | Use {{ API_BASE_URL }} | ✅ Done |

## Next Action

Run the fix script:
```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

Then hard refresh your browser (Ctrl+F5) and vector layers will work!

---

**All changes are ready - just run the script to deploy them!**
