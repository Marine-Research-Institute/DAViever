# MarineSABRES Demonstration Area Tool

## Marine Systems Approaches for Biodiversity Resilience and Ecosystem Sustainability

A Flask-based web application for visualizing EMODnet (European Marine Observation and Data Network) Seabed Habitats and Human Activities WMS (Web Map Service) layers for three MarineSABRES research sites. The application provides an interactive map viewer that displays seabed habitat datasets and human pressure layers from EMODnet infrastructure.

**Project Information:**
- **Grant:** Horizon Europe Grant Agreement No. 101093169
- **Research Sites:** Tuscan Archipelago, Arctic Northeast Atlantic, Macaronesia
- **Version:** 1.3.0-dev

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Contributing](#contributing)

## Features

### Interactive Mapping
- **Leaflet-based Interface**: Modern, responsive mapping with multiple basemap options
- **Multi-layer Support**: Simultaneous display of EMODnet WMS overlays
- **Dynamic Controls**: Real-time opacity adjustment and layer switching
- **Responsive Design**: Optimized for desktop browsers with sidebar/map layout

### EMODnet Integration
- **Seabed Habitats WMS**: Direct integration with EMODnet Seabed Habitats service (~265 layers)
- **Human Activities WMS**: Integration with EMODnet Human Activities service (48 pressure layers)
- **Automatic Fallback**: Graceful degradation when services are unavailable
- **Legend Support**: Dynamic legend display for active layers
- **GetCapabilities Parsing**: Automatic discovery of available WMS layers

### Research Site Navigation
- **Quick Navigation**: One-click zoom to three MarineSABRES research sites
- **Tuscan Archipelago**: Seagrass conservation and tourism
- **Arctic Northeast Atlantic**: Climate change and commercial fisheries
- **Macaronesia**: Biodiversity conservation and ecotourism
- **Smart Zoom**: Automatic layer loading and optimal view extent

### Comprehensive API
- **RESTful Endpoints**: JSON APIs for all data access
- **Layer Management**: Programmatic access to WMS layers
- **Health Monitoring**: Health check endpoint for production deployment
- **Cross-Origin Support**: CORS-enabled for external integrations

## Quick Start

### Prerequisites
- Python 3.10+ (required for Flask-Limiter 4.0.0)
- pip package manager
- Web browser (Chrome/Firefox recommended)

### Installation

1. **Clone the repository:**
```bash
git clone <repository-url>
cd DAViewer
```

2. **Set up virtual environment:**
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows
```

3. **Install dependencies:**
```bash
# Production dependencies
pip install -r requirements.txt

# Development dependencies (optional)
pip install -r requirements-dev.txt
```

4. **Run the application:**
```bash
python app.py
```

5. **Open your browser:**
Navigate to [http://localhost:5002](http://localhost:5002)

## Usage

### Web Interface

The main interface provides several key areas:

#### **Sidebar Controls**
- **Research Site Navigation**: Direct access to Tuscan, Arctic, and Macaronesia sites
- **Layer Selection**: EMODnet Seabed Habitats and Human Activities layers
- **Opacity Control**: Real-time transparency adjustment
- **Basemap Selection**: Choose from OpenStreetMap, Satellite, Ocean, or Light Gray
- **Legend Display**: Dynamic legend for active WMS layers

#### **Map Interaction**
- **Pan and Zoom**: Standard mouse/touch controls
- **Layer Toggling**: Show/hide different data layers
- **Feature Info**: Click on map for WMS feature information
- **Research Site Buttons**: Fly to predefined research locations

#### **Data Layers**

**EMODnet Seabed Habitats Layers (WMS):**
- EUSeaMap 2021 - Comprehensive habitat map
- Benthic habitat classifications
- OSPAR threatened habitat types
- Seabed substrate classifications
- Habitat prediction confidence levels
- EU Habitats Directive Annex I habitats

**EMODnet Human Activities Layers (WMS):**
- Shipping routes and density
- Fishing areas and intensity
- Offshore installations
- Aquaculture sites
- Cable and pipeline routes
- Aggregate extraction areas

### Command Line Usage

**Basic startup:**
```bash
python app.py
```

**Using different environments:**
```bash
# Development mode
FLASK_ENV=development FLASK_DEBUG=1 python app.py

# Custom host and port
FLASK_HOST=0.0.0.0 FLASK_RUN_PORT=5002 python app.py
```

**Testing endpoints:**
```bash
# Health check
curl http://localhost:5002/health

# WMS connectivity test
curl http://localhost:5002/test

# API endpoints
curl http://localhost:5002/api/layers
curl http://localhost:5002/api/all-layers
```

## API Documentation

### Base URL
```
http://localhost:5002/api
```

### Endpoints

#### **WMS Layers**
```http
GET /api/layers
```
Returns available EMODnet Seabed Habitats WMS layers.

**Response:**
```json
[
  {
    "name": "all_eusm2021",
    "title": "EUSeaMap 2021",
    "description": "Comprehensive European seabed habitat map"
  }
]
```

#### **All Layers**
```http
GET /api/all-layers
```
Returns combined EMODnet Seabed Habitats and Human Activities layers.

**Response:**
```json
{
  "wms_layers": [...],
  "human_activities_layers": [...]
}
```

#### **WMS Capabilities**
```http
GET /api/capabilities
```
Proxies WMS GetCapabilities request.

**Response:** XML capabilities document

#### **Legend**
```http
GET /api/legend/<layer_name>
```
Returns legend URL for a specific layer (with input validation).

**Response:**
```json
{
  "legend_url": "https://ows.emodnet-seabedhabitats.eu/geoserver/..."
}
```

#### **Health Check**
```http
GET /health
```
Returns application health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-18T12:00:00Z",
  "version": "1.3.0-dev"
}
```

## Development

### Project Structure

```
DAViewer/
├── app.py                          # Main Flask application
├── __version__.py                  # Version tracking
├── templates/
│   └── index.html                 # Main web interface template
├── static/
│   ├── css/
│   │   └── styles.css            # Application styles
│   └── js/
│       ├── config.js             # Client configuration
│       ├── map-init.js           # Map initialization
│       ├── layer-manager.js      # Layer management
│       └── research-sites.js     # Research site navigation
├── src/
│   └── emodnet_viewer/
│       └── utils/
│           └── logging_config.py  # Logging configuration
├── config/
│   └── config.py                 # Configuration settings
├── gunicorn.conf.py              # Gunicorn production config
├── nginx-da.conf                 # Nginx reverse proxy config
├── deploy_to_da.sh               # Deployment script
├── requirements.txt              # Production dependencies
├── requirements-dev.txt          # Development dependencies
└── CLAUDE.md                     # AI assistant instructions
```

### Development Setup

1. **Install development dependencies:**
```bash
pip install -r requirements-dev.txt
```

2. **Run tests:**
```bash
pytest tests/
```

3. **Code quality:**
```bash
# Format code
black .
isort .

# Lint code
flake8 .
mypy .
```

4. **Run development server:**
```bash
# With hot reload
FLASK_ENV=development python app.py

# With debugging
FLASK_DEBUG=1 python app.py
```

### Architecture

#### **Flask Application (`app.py`)**
- **Modular Design**: Clean separation of routes, utilities, and configuration
- **Template Rendering**: Uses standard Flask templates with modular JavaScript
- **Error Handling**: Graceful fallbacks for service unavailability
- **WMS Integration**: Automatic GetCapabilities parsing for layer discovery
- **Security**: Input validation on all layer name parameters

#### **Frontend (`templates/index.html`)**
- **Leaflet Mapping**: Modern JavaScript mapping library (v1.9.4)
- **Modular JavaScript**: Separate modules for config, map init, layer management, research sites
- **Responsive CSS**: Mobile-friendly design patterns
- **No Build Process**: Uses CDN resources for simplicity

#### **WMS Integration**
- **EMODnet Seabed Habitats**: https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
- **EMODnet Human Activities**: https://ows.emodnet-humanactivities.eu/wms
- **XML Namespace Processing**: Handles both namespaced and non-namespaced responses
- **Layer Filtering**: Client-side filtering and search capabilities
- **Caching**: Efficient layer list caching

## Configuration

### Environment Variables

```bash
# Flask settings
FLASK_ENV=development          # development/production
FLASK_DEBUG=1                 # Enable debug mode
FLASK_HOST=0.0.0.0            # Bind address
FLASK_RUN_PORT=5002           # Application port
APPLICATION_ROOT=/DA          # Subpath deployment (optional)

# Application settings
LOG_LEVEL=INFO               # Logging level
```

### WMS Services

**EMODnet Seabed Habitats:**
- Base URL: `https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms`
- Version: 1.3.0 for capabilities, 1.1.0 for map requests
- Timeout: 10 seconds
- Supports: GetMap, GetCapabilities, GetLegendGraphic

**EMODnet Human Activities:**
- Base URL: `https://ows.emodnet-humanactivities.eu/wms`
- Version: 1.3.0
- Supports: GetMap, GetCapabilities, GetLegendGraphic

## Deployment

### Production Deployment

#### **Using Gunicorn**
```bash
# Install production server
pip install gunicorn

# Run with Gunicorn
gunicorn -w 4 -b 127.0.0.1:5002 app:app

# With configuration file
gunicorn -c gunicorn.conf.py app:app
```

#### **Using Systemd**
Create `/etc/systemd/system/flaskapp.service`:
```ini
[Unit]
Description=MarineSABRES DA Viewer
After=network.target

[Service]
User=razinka
WorkingDirectory=/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer
Environment="PATH=/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/venv/bin"
ExecStart=/home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/venv/bin/gunicorn -c gunicorn.conf.py app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Start service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable flaskapp
sudo systemctl start flaskapp
```

#### **Nginx Configuration**

For subpath deployment at `/DA/`:

```nginx
# Static files served directly by nginx
location /DA/static/ {
    alias /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViewer/static/;
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Proxy to Flask application
location /DA/ {
    rewrite ^/DA(/.*)$ $1 break;
    proxy_pass http://127.0.0.1:5002;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Prefix /DA;
    proxy_set_header X-Script-Name /DA;
}
```

#### **Deployment Script**
```bash
./deploy_to_da.sh
```

This script:
1. Stops the current Gunicorn process
2. Activates virtual environment
3. Updates dependencies
4. Starts Gunicorn with production config
5. Verifies deployment

## Dependencies

### Core Dependencies (Production)
- Flask==3.1.2 - Web framework
- Flask-Caching==2.3.1 - Caching layer
- Flask-Limiter==4.0.0 - API rate limiting (requires Python >=3.10)
- requests==2.32.5 - HTTP client for WMS requests
- Werkzeug>=3.1.0 - WSGI utilities
- gunicorn>=23.0.0 - Production WSGI server
- redis>=6.4.0 - Distributed caching (optional)

### Development Dependencies
- pytest==8.4.2 - Testing framework
- black==25.9.0 - Code formatter
- flake8==7.3.0 - Code linter
- mypy==1.18.2 - Static type checker
- isort==7.0.0 - Import sorter

See `requirements.txt` and `requirements-dev.txt` for complete lists.

## Troubleshooting

### Common Issues

**1. Port Already in Use**
```bash
# Find process using port 5002
lsof -i :5002

# Kill process
kill -9 <PID>

# Or use different port
FLASK_RUN_PORT=5003 python app.py
```

**2. WMS Service Unavailable**
- Check internet connectivity
- Verify WMS URLs are accessible (test with curl)
- Review firewall settings
- Application provides fallback to predefined layer list

**3. Static Files Not Loading (Subpath Deployment)**
- Verify nginx configuration includes static file location block
- Check STATIC_PREFIX is set correctly in app.py
- Clear browser cache (static files use cache busting with version parameters)
- Restart nginx after configuration changes

**4. Health Endpoint 404**
- Ensure APPLICATION_ROOT environment variable is set correctly
- Check nginx proxy_set_header X-Forwarded-Prefix is configured
- Verify health check URL includes subpath (e.g., /DA/health not /health)

## Version History

### v1.3.0-dev (Current)
- Code cleanup: Removed MARBEFES BBT functionality
- Dependencies reduced: 13 → 7 core packages
- Security: Comprehensive input validation for layer names
- Focus: Standardized to MarineSABRES research sites
- Simplification: WMS-only data sources
- Framework updates: Flask 3.1.2, Gunicorn 23.0.0, Flask-Limiter 4.0.0

### v1.2.0
- Added EMODnet Human Activities WMS integration
- Implemented research site navigation
- Enhanced legend display functionality

### v1.1.0
- Framework updates: Flask 3.1.2, GeoPandas 1.1.1
- Security improvements and CVE fixes
- Enhanced error handling and logging

### v1.0.0
- Initial release with EMODnet WMS integration
- Interactive Leaflet-based mapping interface
- RESTful API for layer access

## Contributing

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch:**
   ```bash
   git checkout -b feature/new-feature
   ```
3. **Make changes and test:**
   ```bash
   pytest
   black .
   flake8 .
   ```
4. **Commit changes:**
   ```bash
   git commit -m "feat: Add new feature description"
   ```
5. **Push and create pull request**

### Code Standards

- **Python**: Follow PEP 8 style guide
- **JavaScript**: Use ES6+ features where supported
- **Documentation**: Update docs for new features
- **Testing**: Maintain test coverage
- **Commit Messages**: Use conventional commits format

## License

This project is part of the MarineSABRES project funded by Horizon Europe Grant Agreement No. 101093169.

---

**Contact Information:**
For questions about this application or the MarineSABRES project, please refer to the project coordination team.
