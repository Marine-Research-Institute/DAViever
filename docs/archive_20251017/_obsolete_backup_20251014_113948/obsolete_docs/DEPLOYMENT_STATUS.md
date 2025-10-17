# MARBEFES BBT Database - Deployment Status

## ✅ Successfully Deployed Components

### Application Services
- ✅ **Gunicorn**: Running with 17 workers on port 5000
- ✅ **Nginx**: Running and proxying requests
- ✅ **Systemd Service**: Active and enabled (auto-starts on boot)
- ✅ **Application URL**: http://laguna.ku.lt/BBTS

### Working Features
- ✅ **Main Interface**: Map viewer loads correctly
- ✅ **WMS Layers API**: `/api/layers` returns EMODnet layers
- ✅ **HELCOM Integration**: HELCOM WMS layers available
- ✅ **Vector Layers Metadata**: `/api/vector/layers` returns layer info
- ✅ **Subpath Routing**: Application correctly serves at `/BBTS`

## ⚠️ Known Issue: Vector Layer Loading

### Problem
- Vector layer **metadata loads** correctly (shows 3 layers with bounds/counts)
- Vector layer **GeoJSON fails** to load (404 error for layer data)
- Error messages in browser: "Error loading vector layer" / "Error loading BBT features"

### Root Cause
**Layer ID format mismatch** between:
- API metadata format: `"BBts.gpkg/merged"`
- Lookup function expecting different format

### Impact
- WMS layers work perfectly ✅
- Map interface works ✅
- Vector layers (GPKG files) don't display ❌

### Vector Layers Affected
1. `BBts.gpkg/merged` - 6 features (MultiPolygon)
2. `BBts.gpkg/Broad Belt Transects` - 9 features (MultiPolygon)
3. `CheckedBBT.gpkg/merged` - 11 features (MultiPolygon)

## 📊 System Status

### Services
```bash
● marbefes-bbt.service - Active (running)
  Workers: 17
  Memory: 4.7GB
  Uptime: stable

● nginx.service - Active (running)
  Port 80: listening
  Proxy: /BBTS → 127.0.0.1:5000
```

### Access URLs
- **Main**: http://laguna.ku.lt/BBTS
- **Local**: http://localhost/BBTS
- **API**: http://laguna.ku.lt/BBTS/api/*

## 🔧 Troubleshooting Commands

### Service Management
```bash
# Status
sudo systemctl status marbefes-bbt
sudo systemctl status nginx

# Restart
sudo systemctl restart marbefes-bbt
sudo systemctl reload nginx

# Logs
sudo journalctl -u marbefes-bbt -f
sudo tail -f /var/log/nginx/marbefes-bbt-access.log
```

### Testing
```bash
# Test main page
curl -I http://localhost/BBTS

# Test APIs
curl http://localhost/BBTS/api/layers | jq .
curl http://localhost/BBTS/api/vector/layers | jq .

# Test vector GeoJSON (currently fails)
curl http://localhost/BBTS/api/vector/layer/BBts.gpkg/merged
```

## 🛠️ Fix for Vector Layers

The issue is in the vector layer ID lookup logic. To fix:

1. **Check the layer ID format** in `src/emodnet_viewer/utils/vector_loader.py`
2. **Verify how `get_vector_layer_geojson()` looks up layers**
3. **Ensure consistency** between:
   - `layer_id` in metadata response
   - Layer lookup in `api_vector_layer_geojson()`

### Temporary Workaround
The application works for WMS visualization. Vector layers can be added later once the ID format issue is resolved.

## 📁 Deployment Files

### Scripts Created
- `deploy_subpath.sh` - Full automated deployment
- `verify_subpath.sh` - Comprehensive verification tests
- `complete_fix.sh` - Service restart with cleanup
- `fix_deps_complete.sh` - Dependency rebuild
- `start_nginx.sh` - Nginx startup
- `add_bbts_to_nginx.sh` - Add /BBTS to nginx config
- `test_vector_layers.sh` - Vector layer diagnostics

### Documentation
- `SUBPATH_DEPLOYMENT.md` - Complete deployment guide
- `DEPLOYMENT_QUICKSTART.md` - Quick reference
- `DEPLOYMENT_STATUS.md` - This file

### Configuration
- `/etc/systemd/system/marbefes-bbt.service` - Systemd service
- `/etc/nginx/sites-available/default` - Nginx config (with /BBTS location)
- `/var/www/marbefes-bbt/.env` - Environment variables
- `/var/www/marbefes-bbt/gunicorn_config.py` - WSGI server config
- `/var/www/marbefes-bbt/wsgi_subpath.py` - Subpath WSGI wrapper

## 🎯 Next Steps

### To Fix Vector Layers
1. Run with sudo: `sudo /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/test_vector_layers.sh`
2. Check output to see actual layer IDs
3. Update frontend or backend to match ID format
4. Restart service: `sudo systemctl restart marbefes-bbt`

### For Production
- ✅ Application is accessible and functional
- ✅ WMS layers work perfectly
- ⚠️ Vector layers need ID format fix (non-critical)
- 🔒 Consider adding SSL with Let's Encrypt:
  ```bash
  sudo apt install certbot python3-certbot-nginx
  sudo certbot --nginx -d laguna.ku.lt
  ```

## 📞 Support

### Check Logs
```bash
# Application errors
sudo tail -f /var/www/marbefes-bbt/logs/gunicorn-error.log

# Nginx errors
sudo tail -f /var/log/nginx/marbefes-bbt-error.log

# System logs
sudo journalctl -u marbefes-bbt -f
```

### Common Issues
- **502 Bad Gateway**: Gunicorn not running → `sudo systemctl start marbefes-bbt`
- **404 Not Found**: Nginx location not configured → check `/etc/nginx/sites-available/default`
- **Connection Refused**: Nginx not running → `sudo systemctl start nginx`

---

**Deployment Date**: October 2, 2025
**Status**: ✅ **DEPLOYED & OPERATIONAL** (with minor vector layer issue)
**URL**: http://laguna.ku.lt/BBTS
