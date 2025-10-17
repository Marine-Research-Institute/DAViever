# ✅ Deployment Ready - Subpath URL Fix

## Verification Complete

All changes have been verified and are ready for deployment to production.

### Changes Verified ✅

#### 1. app.py (Line 335)
```python
APPLICATION_ROOT=app.config.get('APPLICATION_ROOT', ''),
```
✅ Passes APPLICATION_ROOT to template context

#### 2. templates/index.html (Line 386)
```html
<img src="{{ APPLICATION_ROOT }}/logo/marbefes_02.png" alt="MARBEFES Logo" class="logo">
```
✅ Logo URL uses APPLICATION_ROOT variable

#### 3. templates/index.html (Line 540)
```javascript
const API_BASE_URL = '{{ APPLICATION_ROOT }}';
```
✅ JavaScript constant defined for API calls

#### 4. templates/index.html (4 locations)
All API fetch calls updated to use API_BASE_URL:
- ✅ Line 593: BBT features loading
- ✅ Line 1319: Vector layer loading
- ✅ Line 1454: Background preloading
- ✅ Line 2143: Direct zoom loading

---

## Deploy Now

### Option 1: Automated (Recommended)

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
./deploy_subpath_fix.sh
```

The script will:
1. ✅ Verify local files
2. ✅ Test SSH connection
3. ✅ Create timestamped backup
4. ✅ Copy updated files
5. ✅ Restart service
6. ✅ Run verification tests
7. ✅ Display results

---

### Option 2: Manual (3 Commands)

```bash
# 1. Copy files
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
scp app.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp templates/index.html razinka@laguna.ku.lt:/var/www/marbefes-bbt/templates/

# 2. SSH and restart
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"

# 3. Verify (optional)
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
```

---

## What Will Be Fixed

### Before Deployment ❌
```
GET http://laguna.ku.lt/logo/marbefes_02.png 404 (Not Found)
GET http://laguna.ku.lt/api/vector/layer/... 404 (Not Found)
```

### After Deployment ✅
```
GET http://laguna.ku.lt/BBTS/logo/marbefes_02.png 200 (OK)
GET http://laguna.ku.lt/BBTS/api/vector/layer/... 200 (OK)
```

**Results:**
- ✅ Logo displays in header
- ✅ BBT navigation works
- ✅ Vector layers load
- ✅ No 404 errors

---

## Verification After Deployment

### Browser Check
1. Open: http://laguna.ku.lt/BBTS
2. Verify logo appears
3. Open DevTools (F12) → Console
4. Verify no 404 errors
5. Test BBT navigation dropdown
6. Select a BBT feature and verify it loads

### Command Line Check
```bash
# Logo
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
# Expected: HTTP/1.1 200 OK

# API
curl -I http://laguna.ku.lt/BBTS/api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects
# Expected: HTTP/1.1 200 OK
```

---

## Backup & Rollback

### Backup Location
Automatic backup created at:
```
/var/www/marbefes-bbt/backups/subpath_fix_YYYYMMDD_HHMMSS/
```

### Rollback Commands (if needed)
```bash
ssh razinka@laguna.ku.lt
cd /var/www/marbefes-bbt
ls -lt backups/  # Find latest backup
cp backups/subpath_fix_*/app.py .
cp backups/subpath_fix_*/index.html templates/
sudo systemctl restart marbefes-bbt
```

---

## Files & Documentation

### Deployment Scripts
- `deploy_subpath_fix.sh` - **Automated deployment (USE THIS)**
- `verify_fix.sh` - Pre-deployment verification
- `deploy_logo_fix.sh` - Legacy script (less robust)

### Documentation
- `DEPLOYMENT_READY.md` - **This file (quick start)**
- `LOGO_FIX.md` - Complete technical documentation
- `DEPLOY_NOW.md` - Simple deployment guide
- `QUICK_DEPLOY.txt` - Quick reference card

---

## Support

**Application**
- URL: http://laguna.ku.lt/BBTS
- Server: razinka@laguna.ku.lt
- Directory: /var/www/marbefes-bbt
- Service: marbefes-bbt

**Logs**
```bash
ssh razinka@laguna.ku.lt
tail -f /var/www/marbefes-bbt/logs/emodnet_viewer.log
```

**Service Status**
```bash
ssh razinka@laguna.ku.lt
sudo systemctl status marbefes-bbt
```

---

## 🚀 Ready to Deploy!

**Run:**
```bash
./deploy_subpath_fix.sh
```

**Or manually:**
```bash
scp app.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp templates/index.html razinka@laguna.ku.lt:/var/www/marbefes-bbt/templates/
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"
```

---

## Technical Summary

**Problem:** Application deployed at `/BBTS` subpath, but URLs were hardcoded as absolute paths

**Solution:** Made all URLs subpath-aware using Flask's `APPLICATION_ROOT` configuration

**Impact:**
- Fixed logo loading (HTML template)
- Fixed API calls (JavaScript)
- Both local development and production work correctly

**Approach:**
- Backend: Pass APPLICATION_ROOT to templates
- HTML: Use `{{ APPLICATION_ROOT }}` for static assets
- JavaScript: Use `API_BASE_URL` constant for dynamic API calls

This ensures the application works at any deployment path without code changes.
