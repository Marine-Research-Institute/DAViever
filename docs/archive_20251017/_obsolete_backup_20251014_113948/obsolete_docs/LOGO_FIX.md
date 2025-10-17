# Subpath URL Fix - Complete Documentation

## Problems
The application had multiple issues when deployed at a subpath (`/BBTS`):

### 1. Logo Not Loading (404)
```
GET http://laguna.ku.lt/logo/marbefes_02.png 404 (Not Found)
```

### 2. API Calls Failing (404)
```
GET http://laguna.ku.lt/api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects 404 (Not Found)
```

## Root Cause
The application is deployed at a **subpath** (`/BBTS`) using Flask's `APPLICATION_ROOT` configuration. Both the logo URL and all JavaScript API calls used hardcoded absolute paths that didn't account for the subpath.

**Result**:
- Logo: Browser requested `/logo/marbefes_02.png` instead of `/BBTS/logo/marbefes_02.png`
- API: JavaScript requested `/api/vector/layer/...` instead of `/BBTS/api/vector/layer/...`

## Solution

### Changes Made

#### 1. Update Flask Route Handler (`app.py:323-336`)
Added `APPLICATION_ROOT` to the template context:

```python
@app.route("/")
def index():
    """Main page with map viewer"""
    all_layers = get_all_layers()
    return render_template(
        'index.html',
        layers=all_layers["wms_layers"],
        helcom_layers=all_layers["helcom_layers"],
        vector_layers=all_layers["vector_layers"],
        vector_support=all_layers["vector_support"],
        WMS_BASE_URL=WMS_BASE_URL,
        HELCOM_WMS_BASE_URL=HELCOM_WMS_BASE_URL,
        APPLICATION_ROOT=app.config.get('APPLICATION_ROOT', ''),  # ← Added
    )
```

#### 2. Add API Base URL Constant (`templates/index.html:539-540`)
Added JavaScript constant at the beginning of the script section:

```javascript
// Application configuration
const API_BASE_URL = '{{ APPLICATION_ROOT }}';
```

#### 3. Update Template Logo URL (`templates/index.html:386`)
Changed from hardcoded path to subpath-aware path:

**Before:**
```html
<img src="/logo/marbefes_02.png" alt="MARBEFES Logo" class="logo">
```

**After:**
```html
<img src="{{ APPLICATION_ROOT }}/logo/marbefes_02.png" alt="MARBEFES Logo" class="logo">
```

#### 4. Update All API Fetch Calls (4 locations)
Changed all JavaScript API calls to use the API_BASE_URL constant:

**Locations updated:**
- Line 593: BBT features loading
- Line 1319: Vector layer loading with timeout
- Line 1454: Background layer preloading
- Line 2143: Direct BBT zoom feature loading

**Before:**
```javascript
fetch(`/api/vector/layer/${encodeURIComponent(layerName)}`)
```

**After:**
```javascript
fetch(`${API_BASE_URL}/api/vector/layer/${encodeURIComponent(layerName)}`)
```

## How It Works

### Development (Local)
- `APPLICATION_ROOT = ''` (empty string)
- `API_BASE_URL` JavaScript constant: `''`
- Logo URL: `/logo/marbefes_02.png`
- API URLs: `/api/vector/layer/...`
- Works correctly on `http://localhost:5000`

### Production (Deployed at subpath)
- `APPLICATION_ROOT = '/BBTS'` (from environment variable)
- `API_BASE_URL` JavaScript constant: `'/BBTS'`
- Logo URL: `/BBTS/logo/marbefes_02.png`
- API URLs: `/BBTS/api/vector/layer/...`
- Works correctly on `http://laguna.ku.lt/BBTS`

## Deployment Instructions

### Option 1: Automated Deployment
Run the deployment script:
```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
./deploy_logo_fix.sh
```

The script will:
1. Create a timestamped backup of current files
2. Copy updated files to the production server
3. Restart the service
4. Show service status

### Option 2: Manual Deployment
```bash
# 1. Backup current files on server
ssh razinka@laguna.ku.lt
cd /var/www/marbefes-bbt
cp app.py app.py.backup
cp templates/index.html templates/index.html.backup

# 2. Copy updated files
# (From local machine)
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
scp app.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp templates/index.html razinka@laguna.ku.lt:/var/www/marbefes-bbt/templates/

# 3. Restart service
ssh razinka@laguna.ku.lt
sudo systemctl restart marbefes-bbt
sudo systemctl status marbefes-bbt
```

## Verification

After deployment, verify the fix:

### 1. Check Logo Loads
Visit: `http://laguna.ku.lt/BBTS`
- ✓ The MARBEFES logo should be visible in the header

### 2. Check Logo URL
```bash
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
```
Expected: `HTTP/1.1 200 OK`

### 3. Check BBT Navigation Works
Open browser console at `http://laguna.ku.lt/BBTS` and verify:
- ✓ No 404 errors for `/api/vector/layer/` requests
- ✓ Message: "✅ BBT features loaded successfully"
- ✓ BBT navigation dropdown populated with features

### 4. Test API Endpoints
```bash
# Test vector layer API
curl -I http://laguna.ku.lt/BBTS/api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects
```
Expected: `HTTP/1.1 200 OK`

### 5. Check Service Status
```bash
ssh razinka@laguna.ku.lt
sudo systemctl status marbefes-bbt
```
Expected: `Active: active (running)`

### 6. Check Application Logs
```bash
ssh razinka@laguna.ku.lt
tail -f /var/www/marbefes-bbt/logs/emodnet_viewer.log
```
Look for: No 404 errors for logo or API requests

## Summary of Changes

This fix comprehensively addresses all subpath-related URL issues:

1. **Backend (app.py)**
   - Passes `APPLICATION_ROOT` to template context

2. **Frontend HTML (templates/index.html)**
   - Logo uses `{{ APPLICATION_ROOT }}/logo/...`

3. **Frontend JavaScript (templates/index.html)**
   - Defines `API_BASE_URL` constant from `{{ APPLICATION_ROOT }}`
   - All 4 API fetch calls now use `${API_BASE_URL}/api/...`

## Technical Notes
- The logo file exists at `/var/www/marbefes-bbt/LOGO/marbefes_02.png`
- Flask route `@app.route("/logo/<filename>")` serves files from the `LOGO/` directory
- Flask routes are subpath-aware automatically via `APPLICATION_ROOT` config
- Templates and JavaScript needed explicit prefix handling
- Using Jinja2 template variables ensures consistency between backend config and frontend URLs

## Files Modified
- `app.py` - Added APPLICATION_ROOT to template context (line 335)
- `templates/index.html` - Multiple updates:
  - Line 386: Logo src attribute with APPLICATION_ROOT
  - Line 539-540: Added API_BASE_URL constant
  - Line 593: Updated BBT features API call
  - Line 1319: Updated vector layer loading API call
  - Line 1454: Updated background preloading API call
  - Line 2143: Updated direct zoom API call
- `deploy_logo_fix.sh` - Deployment automation script (new)
- `LOGO_FIX.md` - This comprehensive documentation (updated)
