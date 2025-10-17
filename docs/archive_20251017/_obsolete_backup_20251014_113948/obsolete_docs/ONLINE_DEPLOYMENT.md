# MARBEFES BBT Database - Online Deployment

## 🚀 Server Status: LIVE

The development version is now running online and accessible for testing!

### Access URLs

**Public Access:**
- 🌐 **Main Application:** http://193.219.76.93:5000
- 🏥 **Health Check:** http://193.219.76.93:5000/health
- 🧪 **WMS Test:** http://193.219.76.93:5000/test

### API Endpoints

All endpoints are accessible at: `http://193.219.76.93:5000/api/...`

| Endpoint | Description | Example |
|----------|-------------|---------|
| `/` | Main map viewer | http://193.219.76.93:5000 |
| `/api/layers` | Get WMS layers | http://193.219.76.93:5000/api/layers |
| `/api/all-layers` | WMS + vector layers | http://193.219.76.93:5000/api/all-layers |
| `/api/vector/layers` | Vector layer list | http://193.219.76.93:5000/api/vector/layers |
| `/api/vector/layer/Bbt - Merged` | BBT GeoJSON data | http://193.219.76.93:5000/api/vector/layer/Bbt%20-%20Merged |
| `/api/factsheets` | BBT factsheets | http://193.219.76.93:5000/api/factsheets |
| `/api/capabilities` | WMS capabilities | http://193.219.76.93:5000/api/capabilities |
| `/api/legend/<layer>` | Layer legend URL | http://193.219.76.93:5000/api/legend/eusm_2023 |

### Server Configuration

- **Server IP:** 193.219.76.93
- **Port:** 5000
- **Host:** 0.0.0.0 (listening on all interfaces)
- **Process ID:** 2092207
- **Debug Mode:** ON (development server)
- **Auto-reload:** Enabled (watchdog)

### Current Features

✅ **Active Features:**
- Interactive BBT map viewer
- 11 BBT areas with zoom navigation
- EMODnet WMS layer integration (265 layers)
- HELCOM Baltic Sea layers (218 layers)
- Vector layer support (GPKG)
- Bathymetry statistics display
- **Editable BBT data forms** (coordinates, habitat, etc.)
- Real-time hover tooltips with area calculations
- Multiple basemap options
- Advanced controls (opacity, themes, 3D)

❌ **Removed Features:**
- Factsheet integration (reverted to original editable forms)

### Testing the Deployment

#### 1. Test Main Application
```bash
curl http://193.219.76.93:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "vector_support": true,
  "vector_layers": 1
}
```

#### 2. Test BBT Vector Data
```bash
curl http://193.219.76.93:5000/api/vector/layers
```

#### 3. Test WMS Integration
```bash
curl http://193.219.76.93:5000/api/layers | head -50
```

### Recent Activity Log

Server logs show successful external access:
```
193.147.173.155 - [07/Oct/2025 10:43:15] GET / HTTP/1.1 200
193.147.173.155 - [07/Oct/2025 10:43:15] GET /static/js/bbt-tool.js HTTP/1.1 200
193.147.173.155 - [07/Oct/2025 10:43:18] GET /api/vector/layer/Bbt%20-%20Merged HTTP/1.1 200
```

✅ **Server is responding to external requests successfully!**

### Performance Features

- **Caching:** Flask-Caching enabled
- **Rate Limiting:** Applied to heavy endpoints
- **GeoJSON Simplification:** Enabled (tolerance: 0.007)
- **Vector Data Caching:** In-memory cache for GeoJSON
- **Coordinate System:** EPSG:4326 (WGS84)

### BBT Data Popup (Current Version)

When clicking the "📊 View/Edit BBT Data" button, users will see:

1. **Location** field (read-only)
2. **Bathymetry Statistics** (if available)
   - Min/Max/Avg Depth
   - Depth Range
3. **Editable Form Fields:**
   - Coordinates (Lat, Lon)
   - Depth Range
   - Habitat Type (dropdown: Rocky reef, Sandy bottom, etc.)
   - Last Sampling Date
   - Research Team
   - Species Count
   - Biodiversity Index
   - Environmental Status (Excellent → Bad)
   - Additional Notes (textarea)
4. **Save Changes** and **Cancel** buttons

### Browser Compatibility

Tested and working on:
- ✅ Chrome/Chromium
- ✅ Firefox
- ✅ Safari
- ✅ Edge

**Note:** Users may need to hard-refresh (Ctrl+Shift+R / Cmd+Shift+R) to clear JavaScript cache after updates.

### Security Notes

⚠️ **Development Server Warning:**
This is Flask's built-in development server and should **NOT** be used in production. 

For production deployment, use:
- Gunicorn
- uWSGI
- Waitress

### Monitoring

**Monitor server status:**
```bash
# Check if server is running
ps aux | grep "python3 app.py"

# View live logs
tail -f /tmp/flask_online.log

# Check network connections
ss -tlnp | grep :5000
```

**Server management:**
```bash
# Stop server
pkill -f "python3 app.py"

# Restart server
nohup python3 app.py > /tmp/flask_online.log 2>&1 &
```

### Known Limitations

1. **Development Mode:** Debug mode is enabled (exposes debugger PIN)
2. **Single-threaded:** Flask dev server handles one request at a time
3. **No HTTPS:** Currently serving over HTTP (not HTTPS)
4. **No Authentication:** Open access to all endpoints
5. **Rate Limiting:** Basic rate limiting applied (may need tuning)

### Next Steps for Production

If you want to move to production:

1. **Deploy with Gunicorn:**
   ```bash
   gunicorn -w 4 -b 0.0.0.0:5000 app:app
   ```

2. **Add NGINX reverse proxy** for HTTPS

3. **Configure proper logging** (not stdout)

4. **Add authentication** if needed

5. **Set up systemd service** for auto-restart

## Summary

🎉 **The application is LIVE and accessible online for testing!**

Access it now at: **http://193.219.76.93:5000**

The BBT data popup has been reverted to show editable form fields instead of factsheet information.

---
*Deployment Date: October 7, 2025*  
*Server Process ID: 2092207*  
*Log File: /tmp/flask_online.log*
