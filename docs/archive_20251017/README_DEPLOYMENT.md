# MARBEFES BBT - Subpath URL Fix Deployment Package

## Quick Start (3 Steps)

```bash
# 1. Navigate to project directory
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# 2. Run automated deployment
./deploy_subpath_fix.sh

# 3. Verify in browser
# Open: http://laguna.ku.lt/BBTS
# Check: Logo visible, BBT navigation works, no console errors
```

---

## What's Included

### Deployment Scripts
| Script | Purpose | When to Use |
|--------|---------|-------------|
| **deploy_subpath_fix.sh** | **Automated deployment** | **Primary method - use this** |
| verify_fix.sh | Pre-deployment checks | Before deploying |
| deploy_logo_fix.sh | Legacy deployment | If main script fails |

### Documentation
| File | Description | Audience |
|------|-------------|----------|
| **DEPLOYMENT_READY.md** | **Quick deployment guide** | **Start here** |
| LOGO_FIX.md | Complete technical docs | Developers |
| DEPLOY_NOW.md | Simple manual steps | Quick reference |
| QUICK_DEPLOY.txt | Command cheat sheet | Terminal reference |
| README_DEPLOYMENT.md | This file | Overview |

---

## Problems Fixed

### ❌ Before
```
Logo:    GET http://laguna.ku.lt/logo/marbefes_02.png → 404
API:     GET http://laguna.ku.lt/api/vector/layer/... → 404
Result:  No logo, BBT navigation broken, layers won't load
```

### ✅ After
```
Logo:    GET http://laguna.ku.lt/BBTS/logo/marbefes_02.png → 200
API:     GET http://laguna.ku.lt/BBTS/api/vector/layer/... → 200
Result:  Logo displays, BBT navigation works, layers load correctly
```

---

## Deployment Methods

### Method 1: Automated (Recommended)
```bash
./deploy_subpath_fix.sh
```

**Features:**
- ✅ Automatic backup creation
- ✅ File verification
- ✅ SSH connectivity test
- ✅ Service restart
- ✅ Post-deployment verification
- ✅ Colored output with clear status
- ✅ Rollback instructions

**Time:** ~30 seconds

---

### Method 2: Manual
```bash
# Copy files
scp app.py razinka@laguna.ku.lt:/var/www/marbefes-bbt/
scp templates/index.html razinka@laguna.ku.lt:/var/www/marbefes-bbt/templates/

# Restart
ssh razinka@laguna.ku.lt "sudo systemctl restart marbefes-bbt"
```

**Time:** ~15 seconds

---

## Files Modified

### app.py
**Line 335:** Added APPLICATION_ROOT to template context
```python
APPLICATION_ROOT=app.config.get('APPLICATION_ROOT', ''),
```

### templates/index.html
**Line 386:** Logo URL with APPLICATION_ROOT
```html
<img src="{{ APPLICATION_ROOT }}/logo/marbefes_02.png">
```

**Line 540:** JavaScript API base URL constant
```javascript
const API_BASE_URL = '{{ APPLICATION_ROOT }}';
```

**Lines 593, 1319, 1454, 2143:** API calls with API_BASE_URL
```javascript
fetch(`${API_BASE_URL}/api/vector/layer/${layerName}`)
```

---

## Verification

### Browser
1. Open http://laguna.ku.lt/BBTS
2. Check logo in header
3. Open console (F12)
4. Verify no 404 errors
5. Test BBT navigation

### Command Line
```bash
# Logo
curl -I http://laguna.ku.lt/BBTS/logo/marbefes_02.png

# API
curl -I http://laguna.ku.lt/BBTS/api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects
```

Both should return `HTTP/1.1 200 OK`

---

## Troubleshooting

### SSH Authentication Error
**Error:** `Permission denied (publickey,password)`

**Solution:**
- Script will prompt for password
- Or set up passwordless SSH
- Or use manual deployment method

### Service Won't Start
**Check status:**
```bash
ssh razinka@laguna.ku.lt
sudo systemctl status marbefes-bbt
sudo journalctl -u marbefes-bbt -n 50
```

**Check logs:**
```bash
tail -100 /var/www/marbefes-bbt/logs/emodnet_viewer.log
```

### Still Getting 404 Errors

**Check APPLICATION_ROOT is set:**
```bash
ssh razinka@laguna.ku.lt
cd /var/www/marbefes-bbt
grep APPLICATION_ROOT config/config.py
# Should show: APPLICATION_ROOT = os.getenv('APPLICATION_ROOT', '')
```

**Check environment variable:**
```bash
cat /etc/systemd/system/marbefes-bbt.service
# Should contain: Environment="APPLICATION_ROOT=/BBTS"
```

### Rollback
```bash
ssh razinka@laguna.ku.lt
cd /var/www/marbefes-bbt
ls -lt backups/  # Find latest
cp backups/subpath_fix_*/app.py .
cp backups/subpath_fix_*/index.html templates/
sudo systemctl restart marbefes-bbt
```

---

## Technical Details

### How It Works

**Development (local):**
- `APPLICATION_ROOT = ''` (empty)
- URLs: `/logo/...`, `/api/...`
- Works at root path

**Production (server):**
- `APPLICATION_ROOT = '/BBTS'` (from env)
- URLs: `/BBTS/logo/...`, `/BBTS/api/...`
- Works at subpath

**Implementation:**
1. Backend passes `APPLICATION_ROOT` to template
2. Jinja2 renders it into HTML and JavaScript
3. JavaScript uses it as a constant for API calls
4. All URLs are dynamically prefixed

### Why This Approach?

**Alternatives considered:**
- ❌ Hardcode `/BBTS` everywhere → Breaks local development
- ❌ Use Flask url_for() → Doesn't work in JavaScript
- ❌ Relative URLs → Breaks in different contexts
- ✅ Dynamic prefix via template variables → Works everywhere

**Benefits:**
- ✅ Single source of truth (config)
- ✅ Works in all environments
- ✅ No code changes needed per environment
- ✅ Maintains separation of concerns

---

## Project Structure

```
EMODNET_PyDeck/
├── app.py                      # Main Flask app (MODIFIED)
├── templates/
│   └── index.html              # Main template (MODIFIED)
├── config/
│   └── config.py               # Config with APPLICATION_ROOT
│
├── deploy_subpath_fix.sh       # Main deployment script ⭐
├── verify_fix.sh               # Verification script
├── deploy_logo_fix.sh          # Legacy deployment
│
├── DEPLOYMENT_READY.md         # Quick start guide ⭐
├── LOGO_FIX.md                 # Technical documentation
├── DEPLOY_NOW.md               # Manual deployment
├── QUICK_DEPLOY.txt            # Command reference
└── README_DEPLOYMENT.md        # This file
```

---

## Support & Resources

**Production Server:**
- URL: http://laguna.ku.lt/BBTS
- SSH: razinka@laguna.ku.lt
- Path: /var/www/marbefes-bbt
- Service: marbefes-bbt

**Local Development:**
- URL: http://localhost:5000
- No subpath prefix needed

**Logs:**
```bash
ssh razinka@laguna.ku.lt
tail -f /var/www/marbefes-bbt/logs/emodnet_viewer.log
```

**Service Management:**
```bash
sudo systemctl status marbefes-bbt
sudo systemctl restart marbefes-bbt
sudo systemctl stop marbefes-bbt
sudo systemctl start marbefes-bbt
```

---

## Next Steps After Deployment

1. ✅ Verify logo displays
2. ✅ Test BBT navigation
3. ✅ Check vector layer loading
4. ✅ Verify no console errors
5. ✅ Test all map features
6. 📝 Document any remaining issues

---

## Ready to Deploy?

**Run the automated script:**
```bash
./deploy_subpath_fix.sh
```

**Or follow the manual steps in:**
- DEPLOYMENT_READY.md (recommended starting point)
- DEPLOY_NOW.md (quick manual guide)
- QUICK_DEPLOY.txt (command reference)

---

**Last Updated:** 2025-10-03
**Version:** 1.0
**Status:** ✅ Ready for Production Deployment
