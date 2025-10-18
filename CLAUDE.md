# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MarineSABRES Demonstration Area Tool** - A Flask-based web application for visualizing EMODnet (European Marine Observation and Data Network) Seabed Habitats and Human Activities WMS (Web Map Service) layers for three MarineSABRES research sites. The application provides an interactive map viewer that displays seabed habitat datasets and human pressure layers from EMODnet infrastructure.

**Project:** Marine Systems Approaches for Biodiversity Resilience and Ecosystem Sustainability
**Grant:** Horizon Europe Grant Agreement No. 101093169
**Research Sites:** Tuscan Archipelago, Arctic Northeast Atlantic, Macaronesia

## Key Architecture

### Application Structure
- **app.py** - Main Flask application
- **templates/index.html** - Interactive map interface
- **static/js/** - Modular JavaScript (map-init, layer-manager, research-sites, etc.)
- **config/config.py** - Configuration management
- **src/emodnet_viewer/utils/logging_config.py** - Logging utilities

### Core Components
1. **WMS Integration** (`app.py`)
   - Connects to EMODnet Seabed Habitats WMS at `https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms`
   - Connects to EMODnet Human Activities WMS at `https://ows.emodnet-humanactivities.eu/wms`
   - Parses GetCapabilities XML responses to discover available layers (265+ habitat layers, 48 human activity layers)
   - Fallback to predefined layer list if service is unavailable

2. **Interactive Map Interface** (`templates/index.html`)
   - Leaflet-based mapping interface with multiple basemap options
   - Layer selection sidebar with EMODnet habitat and human activity layers
   - Research site navigation (Tuscan, Arctic, Macaronesia)
   - Dynamic opacity control and legend display
   - Responsive design optimized for desktop browsers

3. **API Endpoints**
   - `/api/layers` - Returns available WMS layers as JSON
   - `/api/all-layers` - Returns combined WMS + Human Activities layers
   - `/api/capabilities` - Proxies WMS GetCapabilities requests
   - `/api/legend/<layer_name>` - Provides legend URLs for layers (with input validation)
   - `/health` - Health check endpoint for monitoring

### Data Flow
- Application queries EMODnet WMS GetCapabilities on startup
- Parses XML to extract layer names, titles, and descriptions
- Serves interactive interface that makes client-side WMS requests
- Legend images are fetched directly from WMS GetLegendGraphic requests

## Version Information

**Current Version:** 1.3.0-dev (Development)
**Production Version:** 1.3.0 (TBD)
**Last Updated:** October 18, 2025

### Recent Improvements (v1.3.0-dev)
- **Code Cleanup**: Removed MARBEFES BBT factsheet functionality and vector data processing
- **Dependencies**: Reduced from 13 to 7 core packages (removed geopandas, fiona, pyproj, numpy, pyogrio)
- **Security**: Added comprehensive input validation for layer names to prevent injection attacks
- **Project Focus**: Standardized naming and focused exclusively on 3 MarineSABRES research sites
- **Simplification**: Simplified to WMS-only data sources for easier maintenance
- **Version Management**: Centralized version tracking in `__version__.py`
- **Framework Updates (Oct 2025)**:
  - Flask-Limiter: 3.8.0 → 4.0.0 (requires Python >=3.10)
  - Gunicorn: 21.2.0 → 23.0.0
  - requests: 2.32.3 → 2.32.5
  - redis: 5.0.0 → 6.4.0
  - black: 25.1.0 → 25.9.0 (2025 stable style)
- **Bug Fixes**: Fixed health endpoint 404 error in subpath deployment, disabled factsheet loading, improved console logging

### Previous Updates (Version 1.1.0)

### Major Updates Applied
- **Flask**: 2.3.3 → 3.1.2 (security updates, better performance)
- **GeoPandas**: 0.14.0 → 1.1.1 (major version with enhanced features) - Later removed in v1.3.0
- **Testing Framework**: Pytest 7.4.2 → 8.4.2 (improved compatibility)
- **Code Quality**: Black 23.7.0 → 25.9.0, Flake8 6.0.0 → 7.3.0
- **Python Support**: Minimum version raised from 3.8 → 3.10 (required for Flask-Limiter 4.0.0)

### Security Improvements
- Updated Flask to address CVE-2024 vulnerabilities
- Enhanced dependency versions for better security posture
- Added explicit Werkzeug dependency for security
- Updated requests library for latest security patches (2.32.5)
- Comprehensive input validation on all layer name parameters

## Development Commands

### Running the Application

**Development:**
```bash
# Default (localhost only, port 5002)
python app.py

# Custom host and port
FLASK_HOST=0.0.0.0 FLASK_RUN_PORT=5002 python app.py
```

**Production:**
```bash
# Using Gunicorn (recommended)
gunicorn -c gunicorn.conf.py app:app

# Or using systemd service
sudo systemctl start flaskapp

# Or using deployment script
./deploy_to_da.sh
```

- Development server runs on port 5002 by default
- Accessible at http://localhost:5002 or http://laguna.ku.lt/DA/
- Debug mode enabled by default in development
- Port can be configured via `FLASK_RUN_PORT` environment variable
- Production deployment at /DA/ subpath using nginx reverse proxy

### Dependencies
This application requires:
- Flask 3.1.2 (web framework) - Latest stable (Aug 2025)
- Flask-Caching 2.3.1 (caching layer) - Latest stable (Feb 2025)
- Flask-Limiter 4.0.0 (API rate limiting) - Latest stable (Sep 2025, requires Python >=3.10)
- requests 2.32.5 (HTTP client for WMS requests) - Latest stable (Aug 2025)
- Werkzeug 3.1.0+ (WSGI utilities) - Explicit security dependency
- gunicorn 23.0.0+ (production WSGI server) - Latest stable (Oct 2025)
- redis 6.4.0+ (optional: distributed caching) - Latest stable (2025)

Install dependencies:
```bash
# For production
pip install -r requirements.txt

# For development (includes testing and code quality tools)
pip install -r requirements-dev.txt

# Or using the project configuration
pip install -e .[dev]
```

### Testing Endpoints
- Main interface: http://localhost:5002 or http://laguna.ku.lt/DA/
- Health check: http://localhost:5002/health or http://laguna.ku.lt/DA/health
- WMS connectivity test: http://localhost:5002/test
- API endpoints: http://localhost:5002/api/layers or http://laguna.ku.lt/DA/api/layers
- Human Activities layers: http://localhost:5002/api/all-layers

## EMODnet Integration Details

### Default Layer Configuration
The application includes predefined layers from EMODnet (`app.py:17-48`):
- `all_eusm2021` - EUSeaMap 2021 comprehensive habitat map
- `be_eusm2021` - Benthic habitat classifications
- `ospar_threatened` - OSPAR threatened habitat types
- `substrate` - Seabed substrate classifications
- `confidence` - Habitat prediction confidence levels
- `annexiMaps_all` - EU Habitats Directive Annex I habitats

### WMS Service Integration

**EMODnet Seabed Habitats:**
- Base URL: `https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms`
- Uses WMS version 1.3.0 for capabilities, 1.1.0 for map requests
- Provides ~265 habitat and substrate classification layers

**EMODnet Human Activities:**
- Base URL: `https://ows.emodnet-humanactivities.eu/wms`
- Uses WMS version 1.3.0
- Provides 48 human pressure layers (shipping routes, fishing areas, etc.)

**Common Features:**
- Supports GetMap, GetCapabilities, and GetLegendGraphic operations
- Handles XML namespace processing for capabilities parsing
- Layer filtering and caching for performance

### Error Handling
- Graceful fallback to predefined layers if WMS service is unavailable
- Client-side loading indicators and error states
- 10-second timeout on external WMS requests

## Development Notes

### Frontend Architecture
- No build process required - uses CDN resources (Leaflet 1.9.4)
- Inline CSS and JavaScript within the HTML template
- Responsive design with sidebar/map layout

### Styling Approach
- Custom CSS with gradient backgrounds and modern UI elements
- Hover effects and transitions for interactive elements
- Mobile-responsive design considerations

## Important Notes

- **Project Scope**: This is a MarineSABRES project focused on 3 research sites, not a MARBEFES BBT project
- **Data Sources**: Uses EMODnet WMS services only; no local vector data processing
- **Security**: Input validation implemented on all layer name parameters to prevent injection attacks
- **Logging**: Uses custom logging module (emodnet_viewer.utils.logging_config)

When modifying this application, ensure WMS integration remains functional with the EMODnet infrastructure and maintain security best practices for user input validation.