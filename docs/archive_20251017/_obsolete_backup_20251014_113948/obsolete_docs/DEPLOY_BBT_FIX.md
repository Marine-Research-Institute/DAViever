# Deploy BBT Display Fix to laguna.ku.lt

**Issue Fixed:** BBT vector layers not displaying due to pandas 2.2.3 + pyogrio 0.11.1 incompatibility

**Solution:** Downgraded pandas to 2.0.3

---

## Quick Deployment

Run these commands to deploy the BBT fix:

### Step 1: Deploy Files

```bash
# From project directory
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck

# Deploy application files
rsync -avz --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='.git' --exclude='cache' --exclude='logs' \
  --exclude='*.md' --exclude='test_*.html' --exclude='_archive' \
  ./ razinka@laguna.ku.lt:/var/www/marbefes-bbt/
```

### Step 2: Update Dependencies

```bash
# SSH to server and update pandas
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  pip install pandas==2.0.3 && \
  pip install -r requirements.txt"
```

### Step 3: Restart Application

```bash
# Stop existing process
ssh razinka@laguna.ku.lt "pkill -f 'gunicorn.*app:app'"

# Start application
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  nohup venv/bin/gunicorn -c gunicorn_config.py app:app \
  > logs/gunicorn.log 2>&1 &"
```

### Step 4: Verify BBT Loading

```bash
# Check BBT vector layers are loading
curl http://laguna.ku.lt:5000/api/vector/layers | jq

# Should return:
# {
#   "layers": [
#     {
#       "layer_name": "merged",
#       "display_name": "Bbt - Merged",
#       "feature_count": 11,
#       ...
#     }
#   ],
#   "count": 1
# }
```

### Step 5: Test in Browser

Open: http://laguna.ku.lt:5000

Verify:
- ✅ BBT navigation buttons visible in sidebar
- ✅ Click on "Archipelago" → zooms to that area
- ✅ BBT polygons display on map (11 features)
- ✅ Hover over BBT areas → shows tooltips with area calculations
- ✅ All 11 BBT areas accessible:
  - Archipelago
  - Balearic
  - Bay of Gdansk
  - Gulf of Biscay
  - Heraklion
  - Hornsund
  - Irish Sea
  - Kongsfjord
  - Lithuanian coastal zone
  - North Sea
  - Sardinia

---

## What Was Fixed

### Root Cause
```
TypeError: Cannot convert numpy.ndarray to numpy.ndarray
```

This error occurred when:
- pandas 2.2.3 (upgraded in v1.2.0)
- pyogrio 0.11.1 (optional GPKG reader)
- Attempted to read BBT.gpkg file

### Solution Applied

1. **Downgraded pandas**: 2.2.3 → 2.0.3
2. **Enhanced error handling** in `src/emodnet_viewer/utils/vector_loader.py`
3. **Added fiona fallback** with numpy type conversion
4. **Updated requirements.txt** with compatibility note

### Files Modified
- `requirements.txt` - pandas version pinned to 2.0.3
- `src/emodnet_viewer/utils/vector_loader.py` - Better error handling

### Testing Results
```
=== Full Application Test ===

Vector Support: True
Loaded layers: 1

✓ Bbt - Merged
  Features: 11
  Type: MultiPolygon

Testing GeoJSON generation...
✓ GeoJSON generated: 11 features
  Metadata: Bbt - Merged
```

---

## Alternative: Manual Testing Locally

If you want to test before deploying:

```bash
# Ensure pandas 2.0.3
pip install pandas==2.0.3

# Test BBT loading
python -c "
from app import vector_loader
print(f'Loaded layers: {len(vector_loader.loaded_layers)}')
for layer in vector_loader.loaded_layers:
    print(f'  - {layer.display_name} ({layer.feature_count} features)')
"

# Start locally
python app.py
# Open http://localhost:5000
```

---

## Troubleshooting

### Issue: BBT Still Not Displaying

1. **Check pandas version on server:**
```bash
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  python -c 'import pandas; print(pandas.__version__)'"
# Should output: 2.0.3
```

2. **Check vector layers loaded:**
```bash
curl http://laguna.ku.lt:5000/api/vector/layers | jq '.count'
# Should output: 1
```

3. **Check application logs:**
```bash
ssh razinka@laguna.ku.lt "tail -50 /var/www/marbefes-bbt/logs/gunicorn.log" | grep vector
# Should see: "Loaded 1 vector layers from GPKG files"
```

4. **Check BBT.gpkg file exists:**
```bash
ssh razinka@laguna.ku.lt "ls -lh /var/www/marbefes-bbt/data/vector/BBT.gpkg"
# Should show ~2MB file
```

### Issue: Pandas Won't Downgrade

```bash
# Force reinstall
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  pip install pandas==2.0.3 --force-reinstall --no-deps && \
  pip install -r requirements.txt"
```

### Issue: Application Won't Start

```bash
# Check for errors
ssh razinka@laguna.ku.lt "cd /var/www/marbefes-bbt && \
  source venv/bin/activate && \
  python -c 'from app import app; print(\"OK\")'"
```

---

## Verification Checklist

After deployment:

- [ ] pandas 2.0.3 installed on server
- [ ] Application starts without errors
- [ ] Vector layers API returns 1 layer
- [ ] BBT.gpkg loaded successfully (11 features)
- [ ] BBT navigation buttons visible
- [ ] Clicking BBT button zooms to area
- [ ] BBT polygons display on map
- [ ] Hover tooltips work
- [ ] All 11 BBT areas accessible

---

## Summary

**Problem:** BBT not displaying (pandas 2.2.3 incompatibility)
**Solution:** Downgrade to pandas 2.0.3
**Files Changed:** requirements.txt, vector_loader.py
**Testing:** ✓ All 11 BBT features load and display
**Status:** Ready to deploy

---

**Deployed:** Run the commands above
**Version:** 1.2.0 + BBT Fix
**Date:** October 13, 2025
