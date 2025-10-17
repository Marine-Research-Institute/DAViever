# 🚨 PRODUCTION FIX - Service Down (502 Bad Gateway)

**Status**: CRITICAL - Service crash-looping
**URL**: http://laguna.ku.lt/BBTS/
**Error**: Numpy binary incompatibility
**Fix Time**: 2-3 minutes

---

## IMMEDIATE FIX - Run These Commands:

### Complete Fix (Copy All 4 Steps):

```bash
# Step 1: Stop the failing service
sudo systemctl stop marbefes-bbt

# Step 2: Fix Python dependencies
cd /var/www/marbefes-bbt
source venv/bin/activate
pip uninstall -y numpy pandas geopandas
pip install --no-cache-dir numpy
pip install --no-cache-dir pandas  
pip install --no-cache-dir geopandas
python3 -c "import numpy; import pandas; import geopandas; print('✓ SUCCESS')"
deactivate

# Step 3: Start service
sudo systemctl start marbefes-bbt

# Step 4: Verify (wait 3 seconds first)
sleep 3
sudo systemctl status marbefes-bbt
curl -I http://laguna.ku.lt/BBTS/
```

**Expected Result**: HTTP 200 OK ✓

---

## What Happened?

**Error**: `ValueError: numpy.dtype size changed, may indicate binary incompatibility`

**Cause**: Numpy updated but pandas C extensions weren't recompiled

**Fix**: Reinstall numpy → pandas → geopandas in correct order

---

**Time to fix**: 2-3 minutes | **Risk**: Low (safe reinstall)
