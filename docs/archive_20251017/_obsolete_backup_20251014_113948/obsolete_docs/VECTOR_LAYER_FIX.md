# Vector Layer Fix - Layer ID Mismatch

## 🐛 Problem Identified

The frontend uses **`display_name`** to call the API, but the API expects **`source_file/layer_name`**.

### Current (Broken) Behavior
```javascript
// Frontend sends:
'/api/vector/layer/' + encodeURIComponent('Bbts - Broad Belt Transects')
// Result: /api/vector/layer/Bbts%20-%20Broad%20Belt%20Transects
// Backend can't find layer with this ID → 404
```

### API Response Structure
```json
{
  "display_name": "Bbts - Broad Belt Transects",
  "source_file": "BBts.gpkg",
  "layer_name": "Broad Belt Transects"
}
```

### Required Layer ID Format
```
BBts.gpkg/Broad Belt Transects
```

## ✅ Solution Options

### Option 1: Fix Frontend (Recommended - No Server Restart)

Update `/var/www/marbefes-bbt/templates/index.html` to construct proper layer IDs:

**Find and replace:**
```javascript
// OLD (line ~590, 1877, 2658, etc.):
loadVectorLayer(layer.display_name)
'/api/vector/layer/' + encodeURIComponent('Bbts - Broad Belt Transects')

// NEW:
loadVectorLayer(`${layer.source_file}/${layer.layer_name}`)
'/api/vector/layer/' + encodeURIComponent(`BBts.gpkg/Broad Belt Transects`)
```

**Specific changes needed:**

1. **Line 590** - Hardcoded BBT load:
```javascript
// OLD:
const apiUrl = '/api/vector/layer/' + encodeURIComponent('Bbts - Broad Belt Transects');

// NEW:
const apiUrl = '/api/vector/layer/' + encodeURIComponent('BBts.gpkg/Broad Belt Transects');
```

2. **Line 757** - Select layer:
```javascript
// OLD:
selectVectorLayerAsBase('Bbts - Broad Belt Transects');

// NEW:
selectVectorLayerAsBase('BBts.gpkg/Broad Belt Transects');
```

3. **Line 1877** - Background preload:
```javascript
// OLD:
setTimeout(() => loadVectorLayer(layer.display_name), Math.random() * 1000);

// NEW:
setTimeout(() => loadVectorLayer(`${layer.source_file}/${layer.layer_name}`), Math.random() * 1000);
```

4. **Line 2134** - Current layer:
```javascript
// OLD:
currentLayer = 'Bbts - Broad Belt Transects';

// NEW:
currentLayer = 'BBts.gpkg/Broad Belt Transects';
```

5. **Line 2140** - Fetch call:
```javascript
// OLD:
fetch(`/api/vector/layer/${encodeURIComponent('Bbts - Broad Belt Transects')}`)

// NEW:
fetch(`/api/vector/layer/${encodeURIComponent('BBts.gpkg/Broad Belt Transects')}`)
```

6. **Lines 2166, 2175** - Load functions:
```javascript
// OLD:
loadVectorLayerWithoutAutoZoom('Bbts - Broad Belt Transects', geojson);
loadVectorLayerFast('Bbts - Broad Belt Transects');

// NEW:
loadVectorLayerWithoutAutoZoom('BBts.gpkg/Broad Belt Transects', geojson);
loadVectorLayerFast('BBts.gpkg/Broad Belt Transects');
```

7. **Line 2658** - BBT layer load:
```javascript
// OLD:
loadVectorLayerFast(bbtLayer.display_name);

// NEW:
loadVectorLayerFast(`${bbtLayer.source_file}/${bbtLayer.layer_name}`);
```

### Option 2: Add layer_id to API Response

Modify the backend to include `layer_id` in the API response, then update frontend to use it.

**Backend change** (requires sudo/restart):
In the function that creates layer summaries, add:
```python
layer_dict = {
    ...existing fields...,
    "layer_id": f"{source_file}/{layer_name}",  # ADD THIS
}
```

**Frontend change**:
```javascript
loadVectorLayer(layer.layer_id)  // Use the new field
```

## 🔧 Quick Fix Script

Create this file as `/var/www/marbefes-bbt/fix_vector_ids.sh`:

```bash
#!/bin/bash
cd /var/www/marbefes-bbt/templates

# Backup
cp index.html index.html.backup

# Fix all hardcoded references
sed -i "s/'Bbts - Broad Belt Transects'/'BBts.gpkg\/Broad Belt Transects'/g" index.html

# Fix dynamic references
sed -i 's/loadVectorLayer(layer\.display_name)/loadVectorLayer(`${layer.source_file}\/${layer.layer_name}`)/g' index.html
sed -i 's/loadVectorLayerFast(bbtLayer\.display_name)/loadVectorLayerFast(`${bbtLayer.source_file}\/${bbtLayer.layer_name}`)/g' index.html

echo "✓ Fixed! Reload the page in your browser."
```

Then run:
```bash
sudo chmod +x /var/www/marbefes-bbt/fix_vector_ids.sh
sudo /var/www/marbefes-bbt/fix_vector_ids.sh
```

**No server restart needed!** Just refresh your browser.

## 📋 Verification

After applying the fix:

1. **Clear browser cache** (Ctrl+F5)
2. **Open browser console** (F12)
3. **Check API calls**:
```javascript
// Should see:
"📡 Fetching from URL: /api/vector/layer/BBts.gpkg%2FBroad%20Belt%20Transects"
"✅ BBT features loaded successfully: 9 features"
```

4. **Test manually**:
```bash
# This should return GeoJSON (not 404):
curl "http://localhost/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects" | jq '.features | length'
```

## 🎯 Expected Result

After fix:
- ✅ Vector layers load successfully
- ✅ BBT features display on map
- ✅ Hover tooltips show feature info
- ✅ Area calculations work

## 📊 Layer IDs Reference

| Display Name | Correct Layer ID |
|--------------|------------------|
| Bbts - Merged | `BBts.gpkg/merged` |
| Bbts - Broad Belt Transects | `BBts.gpkg/Broad Belt Transects` |
| Checkedbbt - Merged | `CheckedBBT.gpkg/merged` |

## ⚡ Alternative: JavaScript Console Fix

For immediate testing without file edits, run this in browser console:

```javascript
// Test correct API call
fetch('/BBTS/api/vector/layer/BBts.gpkg/Broad%20Belt%20Transects')
  .then(r => r.json())
  .then(data => console.log('Features:', data.features.length));
```

If this returns features (not 404), the fix will work!
