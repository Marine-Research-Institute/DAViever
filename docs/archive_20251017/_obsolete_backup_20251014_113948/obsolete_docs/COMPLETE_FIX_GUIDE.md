# Complete Vector Layer Fix Guide

## Problem Diagnosis

Based on the browser console errors, the issue is **THREE-PART**:

### 1. Nginx is Blocking Encoded Slashes ❌
```
Failed to load resource: the server responded with a status of 404 (Not Found)
api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects:1
```

The `%2F` is an encoded `/` character. By default, nginx blocks URLs with encoded slashes for security reasons.

### 2. Backend Not Finding Layers by Composite ID ❌
The backend `get_layer_by_name()` function only searches by `display_name`, not the `source_file/layer_name` format.

### 3. Frontend Using Correct Format ✅
The frontend is now correctly using `BBts.gpkg/Broad Belt Transects` format (verified by console logs showing `%2F`).

## Root Cause Analysis

```
Browser → nginx → Flask Backend
   ✅        ❌        ❌
```

1. **Browser**: Correctly sends `/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects`
2. **Nginx**: Blocks the request because of `%2F` (encoded slash)
3. **Flask**: Never receives the request (nginx returns 404 first)

## Complete Solution

### Fix Script (Automated)

Run **ONE command** to fix everything:

```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

This script handles:
1. ✅ **Nginx**: Adds `merge_slashes off` to allow encoded slashes
2. ✅ **Backend**: Copies updated `vector_loader.py` with enhanced layer lookup
3. ✅ **Service**: Restarts marbefes-bbt service
4. ✅ **Verification**: Tests the API to confirm it works

### What Each Fix Does

#### 1. Nginx Configuration Fix
**File**: `/etc/nginx/nginx.conf`

**Change**:
```nginx
http {
    merge_slashes off;  # ADD THIS LINE
    # ... rest of config
}
```

**Why**: By default, nginx merges consecutive slashes (`//`) into one and blocks encoded slashes (`%2F`). The `merge_slashes off` directive tells nginx to preserve URLs exactly as sent, allowing paths like `BBts.gpkg/Broad Belt Transects`.

#### 2. Backend Layer Lookup Fix
**File**: `/var/www/marbefes-bbt/src/emodnet_viewer/utils/vector_loader.py`

**Before**:
```python
def get_layer_by_name(self, display_name: str) -> Optional[VectorLayer]:
    for layer in self.loaded_layers:
        if layer.display_name == display_name:  # Only checks display_name
            return layer
    return None
```

**After**:
```python
def get_layer_by_name(self, layer_identifier: str) -> Optional[VectorLayer]:
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

**Why**: The frontend now sends composite IDs like `BBts.gpkg/Broad Belt Transects`. The backend needs to understand this format and match it against the combination of `source_file` and `layer_name` fields.

#### 3. Frontend Updates (Already Applied) ✅
**File**: `/var/www/marbefes-bbt/templates/index.html`

These changes were already made in the previous step - all hardcoded `display_name` references changed to `source_file/layer_name` format.

## Verification

### After Running the Fix Script

#### 1. Check Nginx Config
```bash
grep -A2 "http {" /etc/nginx/nginx.conf | grep merge_slashes
# Should show: merge_slashes off;
```

#### 2. Check Service Status
```bash
systemctl status marbefes-bbt
# Should show: Active: active (running)
```

#### 3. Test API Directly
```bash
curl "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects" | jq '.features | length'
# Should return: 9 (not 404)
```

#### 4. Test in Browser
1. Open http://laguna.ku.lt/BBTS
2. **Hard refresh**: Ctrl+F5 (clears cache)
3. Open console (F12)
4. Look for **SUCCESS messages**:
   ```
   ✅ BBT features loaded successfully: 9 features
   ✅ Cached 3 layers for instant access
   ```

#### 5. Visual Check
- Vector layers should display on map
- Hover over features shows tooltips with area calculations
- BBT navigation buttons work

## Expected Results

### Before Fix
```javascript
console: "📡 Fetching from URL: /api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects"
console: "📥 API Response status: 404"
console: "❌ API Error: 404 Not Found"
// HTML error page from nginx
```

### After Fix
```javascript
console: "📡 Fetching from URL: /api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects"
console: "📥 API Response status: 200"
console: "✅ BBT features loaded successfully: 9 features"
// GeoJSON with actual features
```

## Layer IDs Reference

| Display Name | Layer ID (use in API) | Features |
|--------------|----------------------|----------|
| Bbts - Merged | `BBts.gpkg/merged` | 6 |
| Bbts - Broad Belt Transects | `BBts.gpkg/Broad Belt Transects` | 9 |
| Checkedbbt - Merged | `CheckedBBT.gpkg/merged` | 11 |

## Troubleshooting

### Still Getting 404 After Fix?

1. **Check nginx was actually updated**:
   ```bash
   grep "merge_slashes" /etc/nginx/nginx.conf
   ```
   If not present, nginx wasn't updated properly.

2. **Check service restarted**:
   ```bash
   systemctl status marbefes-bbt
   # Look at start time - should be recent
   ```

3. **Check backend has the updated file**:
   ```bash
   ls -la /var/www/marbefes-bbt/src/emodnet_viewer/utils/vector_loader.py
   # Should exist and have recent modification time
   ```

4. **Check browser cache**:
   - Press Ctrl+F5 (hard refresh)
   - Or clear cache completely
   - Or try in incognito/private window

### Alternative: Manual Fix

If the automated script fails, you can apply fixes manually:

#### Step 1: Nginx
```bash
sudo nano /etc/nginx/nginx.conf
# Find the "http {" line
# Add "merge_slashes off;" right after it
# Save and exit
sudo nginx -t  # Test config
sudo systemctl reload nginx
```

#### Step 2: Backend
```bash
sudo mkdir -p /var/www/marbefes-bbt/src/emodnet_viewer/utils
sudo cp /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/src/emodnet_viewer/utils/vector_loader.py \
        /var/www/marbefes-bbt/src/emodnet_viewer/utils/
sudo chown -R www-data:www-data /var/www/marbefes-bbt/src
sudo systemctl restart marbefes-bbt
```

## Technical Deep Dive

### Why Encoded Slashes?

URLs use `/` as path separators. When a layer ID like `BBts.gpkg/Broad Belt Transects` is used in a URL path, the `/` must be encoded as `%2F` to distinguish it from path separators:

```
Desired:  /api/vector/layer/BBts.gpkg/Broad Belt Transects
Reality:  /api/vector/layer/BBts.gpkg%2FBroad Belt Transects
```

Without encoding, the server would interpret it as:
```
/api/vector/layer/BBts.gpkg/Broad Belt Transects
                          ↑ thinks this is a path separator
```

### Why Nginx Blocks This?

Nginx's default `merge_slashes on` is a security feature to prevent:
- Directory traversal attacks (`/../../../etc/passwd`)
- Inconsistent URL handling
- Cache poisoning

In our case, we **need** those slashes, so we disable merging.

### Why Not Use Display Names?

Display names like `"Bbts - Broad Belt Transects"` are:
- ❌ Non-unique (could have duplicates)
- ❌ User-facing (could change for localization)
- ❌ No connection to actual file structure

Composite IDs like `"BBts.gpkg/Broad Belt Transects"` are:
- ✅ Guaranteed unique (file + layer within file)
- ✅ Stable (matches actual data structure)
- ✅ Self-documenting (you know where data comes from)

## Summary

| Component | Status | Action |
|-----------|--------|--------|
| Frontend | ✅ Fixed | Already updated in previous step |
| Nginx | ⏳ Needs fix | Run apply_vector_fix.sh |
| Backend | ⏳ Needs fix | Run apply_vector_fix.sh |

**Next Action**: Run the automated fix script to apply nginx and backend updates.

```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

After this, all vector layers will work correctly!
