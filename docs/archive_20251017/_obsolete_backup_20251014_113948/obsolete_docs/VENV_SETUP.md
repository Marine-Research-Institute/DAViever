# MARBEFES BBT Database - Virtual Environment Setup Guide

## Quick Start

This guide provides step-by-step instructions for setting up and running the MARBEFES BBT Database application using a Python virtual environment.

### Prerequisites

- **Python 3.9+** installed on your system
- **Internet connection** for downloading dependencies and accessing WMS services
- **Git** (optional, for cloning the repository)

### One-Command Setup

```bash
# Make setup script executable and run it
chmod +x setup_environment.sh && ./setup_environment.sh
```

### Manual Setup (Alternative)

If you prefer to set up manually:

```bash
# 1. Create virtual environment
python3 -m venv venv

# 2. Activate virtual environment
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# 3. Install dependencies
pip install -r requirements-venv.txt

# 4. Create necessary directories
mkdir -p data/vector logs static templates

# 5. Run the application
python run_flask.py
```

## Running the Application

### Option 1: Using the Start Script (Recommended)

```bash
./start_server.sh
```

This script will:
- ✅ Activate the virtual environment
- ✅ Check dependencies
- ✅ Create necessary directories
- ✅ Load environment variables
- ✅ Start the Flask development server

### Option 2: Manual Startup

```bash
# Activate virtual environment
source venv/bin/activate

# Run the application
python run_flask.py
```

### Option 3: Direct Flask Command

```bash
# Activate virtual environment
source venv/bin/activate

# Set environment variables
export FLASK_APP=app.py
export FLASK_ENV=development
export FLASK_DEBUG=1

# Run Flask
flask run --host=0.0.0.0 --port=5000
```

## Accessing the Application

Once started, the application will be available at:
- **Main Interface:** http://localhost:5000
- **API Endpoints:** http://localhost:5000/api/
- **Test Page:** http://localhost:5000/test

## Managing the Server

### Start the Server
```bash
./start_server.sh
```

### Stop the Server
```bash
./stop_server.sh
```

### Check Server Status
```bash
# Check if Flask is running
pgrep -f "python.*app\.py\|python.*run_flask\.py"

# Check what's using port 5000
lsof -i :5000
```

## Configuration

### Environment Variables

The application uses a `.env` file for configuration. Key variables include:

```bash
# Flask Configuration
FLASK_APP=app.py
FLASK_ENV=development
FLASK_DEBUG=1
HOST=0.0.0.0
PORT=5000

# WMS Services
WMS_BASE_URL=https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
HELCOM_WMS_BASE_URL=https://maps.helcom.fi/arcgis/services/MADS/Pressures/MapServer/WMSServer
WMS_TIMEOUT=30

# Data Directories
VECTOR_DATA_DIR=data/vector

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/app.log
```

### Customizing the Port

If port 5000 is already in use:

```bash
# Option 1: Set environment variable
export PORT=5001
./start_server.sh

# Option 2: Edit .env file
echo "PORT=5001" >> .env

# Option 3: Direct command
PORT=5001 python run_flask.py
```

## Project Structure

```
EMODNET_PyDeck/
├── venv/                     # Virtual environment (created by setup)
├── app.py                    # Main Flask application
├── run_flask.py              # Flask runner script
├── config.py                 # Configuration classes
├── .env                      # Environment variables
├── requirements-venv.txt     # Python dependencies
├── setup_environment.sh      # Environment setup script
├── start_server.sh           # Server startup script
├── stop_server.sh            # Server stop script
├── data/
│   └── vector/              # GPKG data files (place your data here)
├── logs/                    # Application logs
├── src/                     # Source code modules
│   └── emodnet_viewer/
├── templates/               # Flask templates
├── static/                  # Static files (CSS, JS, images)
└── docs/                    # Documentation
```

## Dependencies

The virtual environment includes:

### Core Dependencies
- **Flask 3.1.2+** - Web framework
- **Requests 2.32.0+** - HTTP client for WMS services
- **Werkzeug 3.0.0+** - WSGI utilities

### Geospatial Dependencies
- **GeoPandas 1.1.1+** - Geospatial data processing
- **Fiona 1.10.1+** - GPKG file reading
- **PyProj 3.7.1+** - Coordinate system transformations
- **Shapely 2.0.0+** - Geometric operations

### Optional Dependencies
- **python-dotenv 1.0.0+** - Environment variable loading
- **gunicorn 21.0.0+** - Production WSGI server

## Data Management

### Adding Vector Data

1. **Place GPKG files** in the `data/vector/` directory
2. **Restart the application** to load new data
3. **Access via API** at `/api/vector/layers`

### Sample Data Structure

```
data/vector/
├── BBts.gpkg                # Main BBT dataset
├── additional_layers.gpkg   # Additional datasets
└── README.md               # Data documentation
```

## Troubleshooting

### Common Issues

#### 1. Port Already in Use
```bash
# Find what's using the port
lsof -i :5000

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=5001 ./start_server.sh
```

#### 2. Import Errors
```bash
# Check if virtual environment is activated
which python
# Should show: /path/to/project/venv/bin/python

# Reinstall dependencies
pip install -r requirements-venv.txt
```

#### 3. GeoPandas Issues
```bash
# On Ubuntu/Debian, install system dependencies
sudo apt-get install gdal-bin libgdal-dev libgeos-dev libproj-dev

# On macOS with Homebrew
brew install gdal geos proj

# Reinstall GeoPandas
pip uninstall geopandas fiona pyproj shapely
pip install -r requirements-venv.txt
```

#### 4. Permission Errors
```bash
# Make scripts executable
chmod +x setup_environment.sh start_server.sh stop_server.sh run_flask.py

# Fix directory permissions
chmod -R 755 venv/ data/ logs/
```

### Debug Mode

To run with detailed debugging:

```bash
# Enable debug logging
export FLASK_DEBUG=1
export LOG_LEVEL=DEBUG

# Run application
python run_flask.py
```

### Testing the Setup

```bash
# Test virtual environment
source venv/bin/activate
python -c "import flask, requests, geopandas; print('All imports successful')"

# Test Flask application
python -c "from app import app; print('Flask app imported successfully')"

# Test web server
curl http://localhost:5000/test
```

## Development Workflow

### Daily Development

```bash
# 1. Activate environment
source venv/bin/activate

# 2. Start development server
./start_server.sh

# 3. Make changes to code

# 4. Stop server when done
./stop_server.sh
```

### Adding Dependencies

```bash
# Activate virtual environment
source venv/bin/activate

# Install new package
pip install package_name

# Update requirements
pip freeze > requirements-venv.txt
```

### Updating the Environment

```bash
# Pull latest changes
git pull

# Update dependencies
source venv/bin/activate
pip install -r requirements-venv.txt

# Restart server
./stop_server.sh
./start_server.sh
```

## Production Deployment

### Using Gunicorn

```bash
# Activate virtual environment
source venv/bin/activate

# Install Gunicorn (if not already installed)
pip install gunicorn

# Run with Gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

### Environment Variables for Production

```bash
# Update .env for production
echo "FLASK_ENV=production" >> .env
echo "FLASK_DEBUG=0" >> .env
echo "SECRET_KEY=$(openssl rand -base64 32)" >> .env
```

### Docker Alternative

If you prefer Docker over virtual environments, see the main deployment documentation:
- [Docker Setup Guide](docs/DEPLOYMENT.md#docker-deployment)

## Support and Documentation

### Additional Resources

- **Main Documentation:** [README.md](README.md)
- **User Guide:** [docs/USER_GUIDE.md](docs/USER_GUIDE.md)
- **API Documentation:** [docs/API.md](docs/API.md)
- **Developer Guide:** [docs/DEVELOPER.md](docs/DEVELOPER.md)
- **Deployment Guide:** [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

### Getting Help

1. **Check the logs:** `tail -f logs/app.log`
2. **Review error messages** in the terminal
3. **Consult the troubleshooting section** above
4. **Check the main documentation** for detailed information

### Project Information

- **Project:** MARBEFES - Marine Biodiversity and Ecosystem Functioning
- **Grant:** Horizon Europe Grant Agreement No. 101060937
- **Website:** [marbefes.eu](https://marbefes.eu)
- **CORDIS:** [Project Page](https://cordis.europa.eu/project/id/101060937)

---

**Quick Command Reference:**

```bash
# Setup (first time only)
./setup_environment.sh

# Start server
./start_server.sh

# Stop server
./stop_server.sh

# Activate environment manually
source venv/bin/activate

# Check server status
pgrep -f python | xargs ps -p
```