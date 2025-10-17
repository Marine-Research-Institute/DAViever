# Quick Deployment Guide

## What's Fixed
✅ Logo not loading (404 error)
✅ API calls failing (404 errors)
✅ BBT navigation not working

All URLs are now subpath-aware (`/BBTS` prefix)

---

## Deploy to Production

### Step 1: Copy Files to Server
```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# Copy updated files (enter password when prompted)
scp app.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp templates/index.html razinka@laguna.ku.lt:/var/www/marbefes-bbt/templates/
```

### Step 2: Restart Service
```bash
# SSH to server
ssh razinka@laguna.ku.lt

# Restart the service
sudo systemctl restart marbefes-bbt

# Check status
sudo systemctl status marbefes-bbt
```

### Step 3: Verify It Works
Open in browser: `http://laguna.ku.lt/BBTS`

**Check:**
- ✓ MARBEFES logo appears in header
- ✓ No console errors
- ✓ BBT navigation dropdown works
- ✓ Can select and view BBT features

---

## Quick Verification Commands

```bash
# Test logo
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png
# Expected: HTTP/1.1 200 OK

# Test API
curl -I http://laguna.ku.lt/BBTS/api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects
# Expected: HTTP/1.1 200 OK
```

---

## What Was Changed

**File: app.py (line 335)**
- Added `APPLICATION_ROOT` to template

**File: templates/index.html**
- Line 386: Logo URL now uses `{{ APPLICATION_ROOT }}`
- Line 540: Added `API_BASE_URL` JavaScript constant
- Lines 593, 1319, 1454, 2143: All API calls use `API_BASE_URL`

---

## Need Help?
See complete documentation in: `LOGO_FIX.md`
