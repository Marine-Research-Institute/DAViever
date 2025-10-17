# Update Vector Data in Production

## Issue Identified

The production deployment at **http://laguna.ku.lt/BBTS/** is missing the latest BBT vector data updates.

### Current Status:
- **Development**: 11 BBT areas (including "Irish Sea")
- **Production**: Missing latest data (showing older version)

### BBT Areas in Latest Data:
1. Archipelago
2. Balearic
3. Bay of Gdansk
4. Gulf of Biscay
5. Heraklion
6. Hornsund
7. Kongsfjord
8. Lithuanian coast
9. Sardinia
10. North Sea
11. **Irish Sea** (NEW - missing in production)

---

## Quick Update Commands

Run these commands to update the production vector data:

```bash
# Step 1: Backup current production data
sudo cp /var/www/marbefes-bbt/data/vector/BBT.gpkg \
        /var/www/marbefes-bbt/data/vector/BBT.gpkg.backup.$(date +%Y%m%d_%H%M%S)

# Step 2: Copy new GPKG file to production
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
sudo cp data/vector/BBT.gpkg /var/www/marbefes-bbt/data/vector/BBT.gpkg

# Step 3: Set correct permissions
sudo chown www-data:www-data /var/www/marbefes-bbt/data/vector/BBT.gpkg
sudo chmod 644 /var/www/marbefes-bbt/data/vector/BBT.gpkg

# Step 4: Restart the service
sudo systemctl restart marbefes-bbt

# Step 5: Verify the service is running
sudo systemctl status marbefes-bbt
```

---

## Verification

After running the commands above, verify the update:

### 1. Check API Response
```bash
curl http://laguna.ku.lt/BBTS/api/vector/layers | python3 -m json.tool
```

Expected output:
```json
{
    "count": 1,
    "layers": [
        {
            "display_name": "Bbt - Bbt Areas",
            "feature_count": 11,
            ...
        }
    ]
}
```

### 2. Check in Browser
1. Open: **http://laguna.ku.lt/BBTS/**
2. Look at the "BBT Quick Navigation" section in the left sidebar
3. Verify all 11 BBT areas are listed, including "Irish Sea"

### 3. Check Service Logs
```bash
# View real-time logs
sudo journalctl -u marbefes-bbt -f

# Check application logs
sudo tail -f /var/www/marbefes-bbt/logs/emodnet_viewer.log
```

Look for log lines like:
```
INFO - Loaded vector layer: Bbt - Bbt Areas (11 features)
INFO - Loaded 1 vector layers from GPKG files
```

---

## Alternative: Use Automated Script

An automated script is available: `update_vector_data.sh`

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck
sudo bash update_vector_data.sh
```

This script will:
- ✓ Backup existing GPKG file
- ✓ Copy new file to production
- ✓ Set correct permissions
- ✓ Verify file integrity
- ✓ Restart service
- ✓ Confirm service is running

---

## File Information

### Source File (Development)
- **Location**: `data/vector/BBT.gpkg`
- **Size**: ~2.0 MB
- **Last Modified**: October 3, 2025
- **MD5 Checksum**: `4b292f9523da9150e17d2c29c4021156`
- **Features**: 11 MultiPolygon features

### Production File
- **Location**: `/var/www/marbefes-bbt/data/vector/BBT.gpkg`
- **Owner**: www-data:www-data
- **Permissions**: 644 (rw-r--r--)

---

## Troubleshooting

### Service Won't Start
```bash
# Check service status
sudo systemctl status marbefes-bbt -l

# View recent logs
sudo journalctl -u marbefes-bbt -n 50

# Check for GPKG file errors
python3 -c "import fiona; print(fiona.listlayers('/var/www/marbefes-bbt/data/vector/BBT.gpkg'))"
```

### Permission Errors
```bash
# Fix ownership
sudo chown -R www-data:www-data /var/www/marbefes-bbt/data/

# Fix permissions
sudo chmod 755 /var/www/marbefes-bbt/data/vector/
sudo chmod 644 /var/www/marbefes-bbt/data/vector/*.gpkg
```

### Verify GPKG Integrity
```bash
# Check file with Python
python3 << EOF
import fiona
import geopandas as gpd

gpkg_path = '/var/www/marbefes-bbt/data/vector/BBT.gpkg'

# List layers
layers = fiona.listlayers(gpkg_path)
print(f"Layers: {layers}")

# Check features
gdf = gpd.read_file(gpkg_path, layer=layers[0])
print(f"Features: {len(gdf)}")
print(f"BBT Areas: {gdf['Name'].tolist() if 'Name' in gdf.columns else 'No Name column'}")
EOF
```

---

## Summary

The issue is that the production vector data (`BBT.gpkg`) needs to be updated with the latest version that includes all 11 BBT areas.

**To fix**: Copy the development `data/vector/BBT.gpkg` file to `/var/www/marbefes-bbt/data/vector/BBT.gpkg` and restart the service.

**Estimated time**: < 1 minute

---

**Created**: 2025-10-05
**Priority**: Medium
**Impact**: Missing "Irish Sea" BBT area in production navigation
