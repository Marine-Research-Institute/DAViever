# EMODnet Viewer Development Guide

This document provides comprehensive instructions for developing and testing the EMODnet Seabed Habitats Viewer application with full vector layer support and interactive features.

## 🆕 Latest Features (Current Version)

### Vector Layer Support with Hover Tooltips
- **GPKG File Support**: Automatic discovery and loading of GeoPackage files from `data/vector/`
- **Interactive Hover Tooltips**: Real-time area calculations and feature information display
- **Multi-Layer Support**: Both WMS raster layers and vector polygon layers
- **Geodesic Calculations**: Accurate area measurements using Leaflet GeometryUtil
- **Dynamic Styling**: Automatic style assignment based on geometry types

### Current Implementation Status
- ✅ Vector layer loading from GPKG files
- ✅ REST API endpoints for vector data (`/api/vector/*`)
- ✅ Interactive hover tooltips with area calculations
- ✅ Seamless WMS + Vector layer integration
- ✅ GeoPandas-based data processing pipeline
- ✅ Comprehensive error handling and fallbacks

## 🚀 Quick Start

### 1. Environment Setup
```bash
# Clone the repository and navigate to project root
cd EMODNET_PyDeck

# Install development dependencies (includes geospatial libraries)
pip install -r requirements-dev.txt

# Copy environment configuration
cp .env.example .env

# Edit .env file with your specific settings (optional)

# Create sample vector data for testing
python scripts/create_sample_data.py
```

### 2. Run Development Server
```bash
# Using the enhanced development server (recommended)
python scripts/dev_server.py

# Or using Make
make dev

# Or using the original Flask server
python app.py
```

### 3. Verify Installation
```bash
# Check application health
make health

# Run diagnostic tests
make diagnostic

# Run quick tests
make test-unit
```

## 📁 Project Structure

The development framework organizes the project as follows:

```
EMODNET_PyDeck/
├── app.py                     # Original Flask application
├── config/
│   └── config.py              # Configuration management
├── src/emodnet_viewer/
│   └── utils/
│       ├── logging_config.py  # Logging utilities
│       ├── monitoring.py      # Health monitoring
│       └── vector_loader.py   # Vector data loading (GPKG support)
├── data/
│   └── vector/                # Vector data directory (GPKG files)
├── tests/
│   ├── conftest.py           # Pytest configuration
│   ├── unit/                 # Unit tests
│   └── integration/          # Integration tests
├── scripts/
│   ├── dev_server.py         # Enhanced development server
│   ├── run_tests.py          # Test runner
│   └── wms_diagnostic.py     # WMS diagnostic tool
├── requirements.txt          # Production dependencies
├── requirements-dev.txt      # Development dependencies
├── Makefile                  # Development commands
├── pytest.ini               # Test configuration
├── pyproject.toml           # Project metadata and tool config
└── .flake8                  # Linting configuration
```

## 🗺️ Vector Layer Development

### Vector Layer Architecture

The application now supports rich vector layer functionality alongside WMS services:

```python
# Vector layer loading pipeline
GPKG Files → GeoPandas → VectorLayerLoader → GeoJSON API → Leaflet Visualization
```

### Key Components

1. **VectorLayerLoader** (`src/emodnet_viewer/utils/vector_loader.py`)
   - Automatic GPKG file discovery in `data/vector/`
   - Layer metadata extraction (bounds, geometry types, feature counts)
   - GeoJSON conversion with CRS standardization (EPSG:4326)
   - Default styling based on geometry types

2. **Vector API Endpoints** (added to `app.py`)
   ```
   /api/vector/layers              # List all vector layers
   /api/vector/layer/<name>        # Get GeoJSON for specific layer
   /api/vector/bounds              # Get combined bounds of all layers
   /api/all-layers                 # Combined WMS + vector layers
   ```

3. **Interactive Features** (JavaScript in `app.py`)
   - Hover tooltips with area calculations
   - Dynamic feature information display
   - Mouse cursor following tooltips
   - Seamless layer switching between WMS and vector

### Hover Tooltip System

```javascript
// Core tooltip functions implemented:
calculateFeatureArea(feature)     // Geodesic area calculation
createTooltip(content, x, y)      // Tooltip DOM creation
updateTooltip(x, y)              // Real-time position updates
removeTooltip()                  // Cleanup and memory management
```

**Tooltip Features:**
- Real-time area calculation using Leaflet GeometryUtil
- Feature property display (Name, ID, custom attributes)
- Cursor-following positioning with edge detection
- Automatic cleanup on layer changes

### Vector Data Requirements

```bash
# Supported format
data/vector/*.gpkg

# File structure example
data/vector/
├── BBts.gpkg                    # Broad Belt Transects
├── marine_areas.gpkg            # Marine protected areas
└── monitoring_stations.gpkg     # Point data
```

**GPKG File Requirements:**
- Must be in or convertible to EPSG:4326 (WGS84)
- Supports Polygon, MultiPolygon, Point, LineString geometries
- Feature properties become tooltip content
- Multiple layers per GPKG file supported

## 🛠️ Development Tools

### Enhanced Development Server

The enhanced development server provides:

- **Auto-reload** on file changes
- **Enhanced logging** with configurable levels
- **Health check endpoint** at `/health`
- **Performance monitoring**
- **Configuration management**

```bash
# Basic usage
python scripts/dev_server.py

# Custom host and port
python scripts/dev_server.py --host 0.0.0.0 --port 8080

# Different log levels
python scripts/dev_server.py --log-level DEBUG

# Disable auto-reload
python scripts/dev_server.py --no-reload
```

### Test Framework

Comprehensive test suite with multiple test types:

```bash
# Run all tests
make test

# Run specific test types
make test-unit           # Unit tests only
make test-integration    # Integration tests only
make test-coverage       # Tests with coverage report

# Generate detailed test report
make test-report
```

### Code Quality Tools

Integrated linting, formatting, and security checks:

```bash
# Run all quality checks
make quality

# Individual tools
make lint          # Code linting with flake8
make format        # Auto-format with black and isort
make type-check    # Type checking with mypy
make security      # Security analysis with bandit

# Quick pre-commit check
make quick-check
```

### WMS Diagnostic Tool

Comprehensive WMS service testing:

```bash
# Full diagnostic suite
python scripts/wms_diagnostic.py --verbose

# Test specific components
python scripts/wms_diagnostic.py --connectivity-only
python scripts/wms_diagnostic.py --capabilities-only
python scripts/wms_diagnostic.py --layers-only

# Export results
python scripts/wms_diagnostic.py --output diagnostic-report.json

# Test specific layer
python scripts/wms_diagnostic.py --layer all_eusm2021
```

## 🧪 Testing Strategy

### Test Categories

1. **Unit Tests** (`tests/unit/`)
   - Configuration management
   - WMS service functions
   - Utility functions
   - Individual component logic

2. **Integration Tests** (`tests/integration/`)
   - API endpoints
   - Flask application behavior
   - External service interactions

3. **Test Fixtures** (`tests/conftest.py`)
   - Mock WMS responses
   - Sample data
   - Test utilities

### Writing Tests

```python
# Example unit test
def test_config_loading():
    """Test configuration loading"""
    config = get_config()
    assert config.WMS_BASE_URL.startswith('http')
    assert config.WMS_TIMEOUT > 0

# Example integration test
def test_api_layers_endpoint(client):
    """Test /api/layers endpoint"""
    response = client.get('/api/layers')
    assert response.status_code == 200
    assert response.content_type == 'application/json'
```

### Test Markers

Use pytest markers to categorize tests:

```python
@pytest.mark.unit
def test_unit_function():
    pass

@pytest.mark.integration
def test_api_endpoint():
    pass

@pytest.mark.network
def test_external_service():
    pass
```

## 📊 Monitoring and Logging

### Logging Configuration

The application uses structured logging with multiple levels:

```python
from src.emodnet_viewer.utils.logging_config import get_logger

logger = get_logger('component_name')
logger.info("Information message")
logger.warning("Warning message")
logger.error("Error message")
```

### Health Monitoring

Access health information via:

- **Health endpoint**: `GET /health`
- **System metrics**: CPU, memory, disk usage
- **WMS connectivity**: Response times, status
- **Application metrics**: Uptime, request counts

### Performance Monitoring

```python
from src.emodnet_viewer.utils.logging_config import PerformanceLogger

with PerformanceLogger("operation_name"):
    # Your code here
    pass
```

## 🔧 Configuration Management

### Environment Variables

Configure the application using environment variables:

```bash
# Flask configuration
FLASK_ENV=development
FLASK_DEBUG=True

# WMS service
WMS_BASE_URL=https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms
WMS_TIMEOUT=10

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/emodnet_viewer.log
```

### Configuration Classes

Different configurations for different environments:

- **DevelopmentConfig**: Debug mode, verbose logging
- **ProductionConfig**: Optimized for production
- **TestingConfig**: Isolated test environment

## 🚢 Deployment Preparation

### Pre-deployment Checklist

```bash
# Run full quality check
make quality

# Generate test report
make test-report

# Check WMS connectivity
make diagnostic

# Test production configuration
FLASK_ENV=production make dev-production
```

### Build and Package

```bash
# Clean build artifacts
make clean

# Install production dependencies
make install

# Test production server
make run
```

## 🐛 Troubleshooting

### Common Issues

1. **WMS Service Unavailable**
   ```bash
   # Diagnose WMS connectivity
   python scripts/wms_diagnostic.py --verbose
   ```

2. **Test Failures**
   ```bash
   # Run tests with detailed output
   python scripts/run_tests.py --all --verbose
   ```

3. **Import Errors**
   ```bash
   # Check Python path and dependencies
   make env-check
   ```

4. **Performance Issues**
   ```bash
   # Monitor system resources
   make perf-test
   ```

### Debug Mode

Enable debug mode for detailed error information:

```bash
# Environment variable
export FLASK_DEBUG=True

# Development server with debug logging
python scripts/dev_server.py --log-level DEBUG
```

## 📚 Additional Resources

### Useful Make Commands

```bash
make help           # Show all available commands
make setup          # Set up development environment
make check          # Quick development check
make pre-commit     # Pre-commit quality checks
make clean          # Clean build artifacts
```

### Development Workflow

1. **Start Development**
   ```bash
   make setup          # Initial setup
   make dev           # Start development server
   ```

2. **Make Changes**
   - Edit code (auto-reload active)
   - Write tests for new functionality
   - Check logs for issues

3. **Quality Check**
   ```bash
   make pre-commit    # Quick quality check
   make quality       # Full quality suite
   ```

4. **Test and Deploy**
   ```bash
   make test-coverage  # Full test suite
   make diagnostic     # Verify WMS connectivity
   ```

### VS Code Integration

For optimal VS Code experience:

1. Install Python extension
2. Set interpreter to project virtual environment
3. Configure pytest as test runner
4. Enable format on save with black
5. Use flake8 for linting

### Git Hooks (Optional)

Set up pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

This ensures code quality checks run automatically before commits.

## 🤝 Contributing

When contributing to the project:

1. Follow the established code style
2. Write tests for new functionality
3. Update documentation as needed
4. Run quality checks before committing
5. Use meaningful commit messages

The development framework ensures consistent code quality and makes it easy to maintain the application over time.