# Environment Variables Documentation

Complete reference for all environment variables used in the MARBEFES BBT Database application.

## Quick Start

Create a `.env` file in the project root:

```bash
# Development
cp .env.example .env

# Production
# Use deploy_production.sh which generates .env with secure defaults
```

---

## Core Application Settings

### `FLASK_ENV`
- **Type:** String
- **Values:** `development`, `production`, `testing`
- **Default:** `development`
- **Description:** Determines which configuration class to load
- **Impact:**
  - `development`: Debug mode enabled, verbose logging
  - `production`: Security validations, minimal logging, SECRET_KEY required
  - `testing`: Mock WMS, in-memory cache

**Example:**
```bash
FLASK_ENV=production
```

### `SECRET_KEY`
- **Type:** String (hex)
- **Default:** `dev-secret-key-change-in-production`
- **Required:** **YES** (in production)
- **Description:** Flask session encryption key
- **Security:** Application will **raise ValueError** if default key is used in production

**Generate secure key:**
```bash
openssl rand -hex 32
```

**Example:**
```bash
SECRET_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

### `DEBUG`
- **Type:** Boolean
- **Default:** `False` (production), `True` (development)
- **Description:** Flask debug mode
- **Warning:** Never enable in production

---

## Server Configuration

### `FLASK_HOST`
- **Type:** String (IP address)
- **Default:** `0.0.0.0`
- **Description:** Server bind address
- **Values:**
  - `0.0.0.0` - Listen on all interfaces
  - `127.0.0.1` - Local only

**Example:**
```bash
FLASK_HOST=127.0.0.1  # Production (behind nginx)
```

### `FLASK_RUN_PORT` / `PORT`
- **Type:** Integer
- **Default:** `5000`
- **Description:** Server port
- **Gunicorn:** Uses `PORT` variable

**Example:**
```bash
PORT=5000
```

### `APPLICATION_ROOT`
- **Type:** String (URL path)
- **Default:** `` (empty - root path)
- **Description:** Subpath for mounting application
- **Use Case:** Deploy to `/BBTS` instead of `/`

**Example:**
```bash
APPLICATION_ROOT=/BBTS
```

**Impact:**
- API endpoints become `/BBTS/api/layers`
- Static files at `/BBTS/static/`
- JavaScript `API_BASE_URL` automatically adjusted

---

## WMS Service Configuration

### `WMS_BASE_URL`
- **Type:** String (URL)
- **Default:** `https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms`
- **Description:** EMODnet WMS service endpoint

**Example:**
```bash
WMS_BASE_URL=https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
```

### `WMS_VERSION`
- **Type:** String
- **Default:** `1.3.0`
- **Description:** WMS protocol version

### `WMS_TIMEOUT`
- **Type:** Integer (seconds)
- **Default:** `10`
- **Description:** HTTP timeout for WMS requests
- **Recommendation:** 10-30 seconds depending on network

---

## Cache Configuration

### `CACHE_TYPE`
- **Type:** String
- **Default:** `simple`
- **Values:** `simple`, `redis`, `memcached`, `filesystem`
- **Description:** Flask-Caching backend type

**Example:**
```bash
CACHE_TYPE=simple  # In-memory cache
```

### `CACHE_DEFAULT_TIMEOUT`
- **Type:** Integer (seconds)
- **Default:** `3600` (1 hour)
- **Description:** Default cache TTL for all cached data

### `WMS_CACHE_TIMEOUT`
- **Type:** Integer (seconds)
- **Default:** `300` (5 minutes)
- **Description:** Specific cache TTL for WMS GetCapabilities responses
- **Optimization:** Reduces external API calls to EMODnet

**Performance Impact:**
```
Without cache: 273 layers fetched every page load (~2-3s)
With cache:    273 layers cached for 5 minutes (~10ms)
```

---

## Layer Configuration

### `CORE_EUROPEAN_LAYER_COUNT`
- **Type:** Integer
- **Default:** `6`
- **Description:** Number of priority European layers to show first
- **Impact:** Layer ordering in sidebar

**Example:**
```bash
CORE_EUROPEAN_LAYER_COUNT=6
```

### `MAX_LAYERS_DISPLAY`
- **Type:** Integer
- **Default:** `20`
- **Description:** Maximum layers to display in UI

---

## Vector Data Configuration

### `ENABLE_VECTOR_SUPPORT`
- **Type:** Boolean
- **Default:** `True`
- **Description:** Enable/disable vector layer support
- **Requires:** GeoPandas, Fiona, pyproj installed

**Example:**
```bash
ENABLE_VECTOR_SUPPORT=True
```

### `VECTOR_DATA_DIR`
- **Type:** String (path)
- **Default:** `data`
- **Description:** Base directory for vector data
- **Structure:** GPKG files should be in `{VECTOR_DATA_DIR}/vector/`

**Example:**
```bash
VECTOR_DATA_DIR=data
# GPKG files in: data/vector/*.gpkg
```

### `VECTOR_SIMPLIFY_TOLERANCE`
- **Type:** Float
- **Default:** `0.001`
- **Description:** Geometry simplification tolerance for performance
- **Range:** `0.0001` (high detail) to `0.01` (low detail)

**Performance:**
```
0.001:  Balanced (recommended)
0.0001: High detail, slower rendering
0.01:   Fast rendering, simplified shapes
```

### `VECTOR_MAX_FEATURES`
- **Type:** Integer
- **Default:** `10000`
- **Description:** Maximum features to load per layer
- **Safety:** Prevents memory exhaustion on large datasets

---

## Logging Configuration

### `LOG_LEVEL`
- **Type:** String
- **Values:** `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- **Default:** `INFO` (development), `WARNING` (production)
- **Description:** Minimum log level to record

**Recommendations:**
```bash
# Development
LOG_LEVEL=DEBUG

# Production
LOG_LEVEL=WARNING

# Troubleshooting
LOG_LEVEL=DEBUG
```

### `LOG_FILE`
- **Type:** String (path)
- **Default:** `logs/emodnet_viewer.log`
- **Description:** Log file location

### `LOG_MAX_BYTES`
- **Type:** Integer (bytes)
- **Default:** `10485760` (10 MB)
- **Description:** Maximum log file size before rotation

### `LOG_BACKUP_COUNT`
- **Type:** Integer
- **Default:** `5`
- **Description:** Number of rotated log files to keep

---

## Security Settings

### `SESSION_COOKIE_SECURE`
- **Type:** Boolean
- **Default:** `True` (production)
- **Description:** Require HTTPS for session cookies
- **Production:** Must be `True` with SSL/TLS

### `SESSION_COOKIE_HTTPONLY`
- **Type:** Boolean
- **Default:** `True` (production)
- **Description:** Prevent JavaScript access to session cookies
- **Security:** XSS protection

### `SESSION_COOKIE_SAMESITE`
- **Type:** String
- **Values:** `Strict`, `Lax`, `None`
- **Default:** `Lax` (production)
- **Description:** CSRF protection level

---

## Gunicorn-Specific Variables

### `WORKERS`
- **Type:** Integer
- **Default:** `(CPU_COUNT * 2) + 1`
- **Description:** Number of Gunicorn worker processes
- **Recommendation:** `2-4` for typical servers

**Calculate:**
```bash
# 4 CPU cores: (4 * 2) + 1 = 9 workers
```

### `TIMEOUT`
- **Type:** Integer (seconds)
- **Default:** `120`
- **Description:** Worker timeout for requests
- **WMS Optimization:** Increased from 30s to handle slow WMS responses

### `MAX_REQUESTS`
- **Type:** Integer
- **Default:** `1000`
- **Description:** Restart worker after N requests
- **Purpose:** Prevent memory leaks

---

## Complete Production Example

```bash
# Production Environment Configuration
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=<generate-with-openssl-rand-hex-32>

# Server
FLASK_HOST=127.0.0.1
PORT=5000
APPLICATION_ROOT=

# WMS
WMS_BASE_URL=https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
WMS_VERSION=1.3.0
WMS_TIMEOUT=10

# Cache - Optimized
CACHE_TYPE=simple
CACHE_DEFAULT_TIMEOUT=3600
WMS_CACHE_TIMEOUT=300

# Layers
CORE_EUROPEAN_LAYER_COUNT=6

# Vector Data
VECTOR_DATA_DIR=data
VECTOR_SIMPLIFY_TOLERANCE=0.001
VECTOR_MAX_FEATURES=10000
ENABLE_VECTOR_SUPPORT=True

# Logging
LOG_LEVEL=WARNING
LOG_FILE=logs/marbefes-bbt.log
LOG_MAX_BYTES=10485760
LOG_BACKUP_COUNT=5

# Security
SESSION_COOKIE_SECURE=True
SESSION_COOKIE_HTTPONLY=True
SESSION_COOKIE_SAMESITE=Lax

# Gunicorn
WORKERS=9
TIMEOUT=120
MAX_REQUESTS=1000
```

---

## Testing Configuration Changes

### Test config loading:
```bash
python3 -c "from config import get_config; c = get_config(); print(f'Environment: {c.__class__.__name__}')"
```

### Verify all variables:
```bash
python3 -c "from config import get_config; c = get_config(); import pprint; pprint.pprint({k:v for k,v in c.__dict__.items() if not k.startswith('_')})"
```

### Test WMS cache:
```bash
curl -w "\nTime: %{time_total}s\n" http://localhost:5000/api/layers
```

---

## Troubleshooting

### Secret Key Error in Production
**Error:** `ValueError: Production ERROR: SECRET_KEY must be set`

**Fix:**
```bash
export SECRET_KEY=$(openssl rand -hex 32)
# or add to .env file
```

### WMS Timeout Issues
**Symptom:** Slow layer loading, timeout errors

**Fix:**
```bash
WMS_TIMEOUT=30  # Increase timeout
WMS_CACHE_TIMEOUT=600  # Cache for 10 minutes
```

### Vector Layers Not Loading
**Symptom:** `Vector support not available`

**Fix:**
```bash
pip install geopandas fiona pyproj
ENABLE_VECTOR_SUPPORT=True
```

---

## Migration from Previous Versions

### Changes in v1.1.0 (October 2025)

**New Variables:**
- `WMS_CACHE_TIMEOUT` - Extracted from hardcoded value
- `CORE_EUROPEAN_LAYER_COUNT` - Extracted from hardcoded value
- `APPLICATION_ROOT` - For subpath deployment support

**Changed Defaults:**
- `LOG_LEVEL`: `INFO` → `WARNING` (production only)
- `CACHE_TYPE`: `SimpleCache` → `simple` (normalized naming)

**Required for Production:**
- `SECRET_KEY` now validated at startup (raises error if default)

---

## Related Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Production deployment guide
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development setup
- [OPTIMIZATION_REPORT_20251004.md](OPTIMIZATION_REPORT_20251004.md) - Recent optimizations

**Last Updated:** October 4, 2025
**Version:** 1.1.0
