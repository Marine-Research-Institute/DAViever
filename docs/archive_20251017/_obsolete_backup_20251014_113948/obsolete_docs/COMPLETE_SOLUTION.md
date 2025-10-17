# Complete Vector Layer Fix - Root Cause & Solution

## Root Cause Analysis

### Issue Chain Discovered

The error `GET http://laguna.ku.lt/api/vector/layer/...` reveals a **5-part problem**:

1. **Missing `/BBTS` prefix** in API URLs ❌
2. **Config missing `APPLICATION_ROOT`** ❌
3. **Template using empty `{{ API_BASE_URL }}`** ❌
4. **Nginx blocking encoded slashes** ❌
5. **Backend not recognizing composite layer IDs** ❌

### Why URLs Were Wrong

```
Expected: http://laguna.ku.lt/BBTS/api/vector/layer/...
Actual:   http://laguna.ku.lt/api/vector/layer/...
                               ↑ Missing /BBTS subpath!
```

**The problem cascade:**
1. `.env` has `APPLICATION_ROOT=/BBTS` ✅
2. `config.py` **doesn't read** APPLICATION_ROOT ❌
3. Flask app.config['APPLICATION_ROOT'] = None
4. app.py passes empty string to template
5. Template renders `/api/...` without `/BBTS` prefix
6. Browser requests wrong URL → 404

## Complete Solution (5 Fixes)

### Fix 1: Add APPLICATION_ROOT to config.py ✅

**File:** `/home/razinka/.../EMODNET_PyDeck/config/config.py`

```python
class Config:
    # Flask settings
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    DEBUG = False
    TESTING = False
    APPLICATION_ROOT = os.getenv('APPLICATION_ROOT', '')  # ← ADDED THIS
```

**Why:** The config class must read the APPLICATION_ROOT environment variable so Flask can use it.

### Fix 2: Pass API_BASE_URL to template ✅

**File:** `/var/www/marbefes-bbt/app.py`

```python
@app.route("/")
def index():
    all_layers = get_all_layers()
    # Get APPLICATION_ROOT for API URLs
    api_base = app.config.get('APPLICATION_ROOT', '').rstrip('/')  # ← ADDED THIS
    return render_template(
        'index.html',
        ...
        API_BASE_URL=api_base,  # ← ADDED THIS
    )
```

**Why:** Template needs the subpath to construct correct API URLs.

### Fix 3: Use API_BASE_URL in template ✅

**File:** `/var/www/marbefes-bbt/templates/index.html`

**Before (4 locations):**
```javascript
fetch(`/api/vector/layer/${layerName}`)  // ❌ Wrong
```

**After:**
```javascript
fetch(`{{ API_BASE_URL }}/api/vector/layer/${layerName}`)  // ✅ Correct
```

**Why:** Injects `/BBTS` prefix so URLs become `/BBTS/api/...`.

### Fix 4: Configure nginx for encoded slashes ⏳

**File:** `/etc/nginx/nginx.conf`

```nginx
http {
    merge_slashes off;  # ← ADD THIS
    ...
}
```

**Why:** Allows URLs with `%2F` (encoded `/`) like `BBts.gpkg%2FBroad%20Belt%20Transects`.

### Fix 5: Update backend layer lookup ⏳

**File:** `/var/www/marbefes-bbt/src/.../vector_loader.py`

```python
def get_layer_by_name(self, layer_identifier: str):
    for layer in self.loaded_layers:
        # Try display_name (backward compatibility)
        if layer.display_name == layer_identifier:
            return layer
        # Try source_file/layer_name format (new robust format)
        layer_id = f"{layer.source_file}/{layer.layer_name}"
        if layer_id == layer_identifier:
            return layer
    return None
```

**Why:** Backend must understand composite IDs like `BBts.gpkg/Broad Belt Transects`.

## Files Modified

| Component | File | Status |
|-----------|------|--------|
| **Config** | `config/config.py` | ✅ Updated in source |
| **Backend** | `app.py` | ✅ Updated in deployment |
| **Frontend** | `templates/index.html` | ✅ Updated in deployment |
| **Backend** | `src/.../vector_loader.py` | ✅ Updated in source |
| **Nginx** | `/etc/nginx/nginx.conf` | ⏳ Ready to update |

## Apply All Fixes

Run the automated fix script:

```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

This comprehensive script will:
1. ✅ Configure nginx (`merge_slashes off`)
2. ✅ Copy updated `config.py` with APPLICATION_ROOT
3. ✅ Verify `app.py` has API_BASE_URL support
4. ✅ Copy updated `vector_loader.py`
5. ✅ Verify template uses `{{ API_BASE_URL }}`
6. ✅ Restart marbefes-bbt service
7. ✅ Test the API endpoints

## Expected Results

### Before All Fixes
```javascript
// Browser console:
📡 Fetching from URL: /api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects
GET http://laguna.ku.lt/api/vector/layer/... 404 (Not Found)
                          ↑ Missing /BBTS
❌ API Error: 404 Not Found (nginx error page)
```

### After All Fixes
```javascript
// Browser console:
📡 Fetching from URL: /BBTS/api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects
                       ↑ Now includes /BBTS!
GET http://laguna.ku.lt/BBTS/api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects 200 (OK)
✅ BBT features loaded successfully: 9 features
✅ Cached 3 layers for instant access
```

## Verification Steps

### 1. Check Rendered HTML
```bash
curl -s "http://localhost/BBTS/" | grep -o "const apiUrl = '[^']*'" | head -1
# Should output: const apiUrl = '/BBTS/api/vector/layer/'
#                                 ↑ /BBTS prefix present
```

### 2. Test API Directly
```bash
curl "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects" | jq '.features | length'
# Should return: 9 (not 404)
```

### 3. Check Browser
1. Open http://laguna.ku.lt/BBTS
2. **Hard refresh**: Ctrl+Shift+R (clears cache completely)
3. Open console (F12)
4. Look for success messages:
   ```
   ✅ BBT features loaded successfully: 9 features
   ```

## Technical Deep Dive

### Why APPLICATION_ROOT Must Be in Config

Flask's `app.config.from_object(config)` only copies **class attributes** from the config object. If `APPLICATION_ROOT` isn't defined as a class attribute, it won't be in `app.config`.

**Flow:**
```
.env file → os.getenv() → Config.APPLICATION_ROOT → app.config['APPLICATION_ROOT'] → api_base → {{ API_BASE_URL }}
```

**Break point was:** Config.APPLICATION_ROOT didn't exist, so the chain stopped there.

### URL Resolution in Browsers

When the page URL is `http://laguna.ku.lt/BBTS`:

| Code | Resolves To | Correct? |
|------|-------------|----------|
| `/api/...` | `http://laguna.ku.lt/api/...` | ❌ No (root path) |
| `/BBTS/api/...` | `http://laguna.ku.lt/BBTS/api/...` | ✅ Yes (subpath) |
| `api/...` | `http://laguna.ku.lt/BBTS/api/...` | ✅ Yes (relative) |

We use absolute paths with the subpath prefix for clarity and consistency.

### Jinja2 Template Rendering

```python
# Backend passes:
API_BASE_URL='/BBTS'

# Template uses:
'{{ API_BASE_URL }}/api/vector/layer/'

# Renders as:
'/BBTS/api/vector/layer/'
```

### All 5 Fixes Required

Each fix addresses one part of the problem chain:

1. **Config fix** → Flask receives APPLICATION_ROOT
2. **App.py fix** → Template receives api_base variable
3. **Template fix** → Browser gets correct URLs
4. **Nginx fix** → Server accepts encoded slashes
5. **Backend fix** → API recognizes composite layer IDs

**All 5 must be applied for the system to work.**

## Summary

| Component | Issue | Fix |
|-----------|-------|-----|
| Config | APPLICATION_ROOT not defined | Add to Config class |
| App | api_base not passed to template | Add API_BASE_URL parameter |
| Template | URLs missing /BBTS prefix | Use {{ API_BASE_URL }} |
| Nginx | Blocks %2F in URLs | Add merge_slashes off |
| Backend | Doesn't recognize composite IDs | Update get_layer_by_name |

## Next Action

Run this command to apply all 5 fixes:

```bash
sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/apply_vector_fix.sh
```

After the script completes:
1. Hard refresh your browser (Ctrl+Shift+R)
2. Vector layers will load successfully!
3. All 3 GPKG layers will be functional

---

**Status:** All fixes identified and ready to deploy!
