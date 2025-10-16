"""
MarineSABRES Demonstration Area Tool - Marine Research Data Viewer
Marine Systems Approaches for Biodiversity Resilience and Ecosystem Sustainability
"""

# Standard library imports
import os
import sys
import json
from pathlib import Path
from xml.etree import ElementTree as ET

# Version information
try:
    from __version__ import __version__, get_version_string
except ImportError:
    __version__ = "1.3.0-dev"
    def get_version_string():
        return f"MarineSABRES DA Tool v{__version__}"

# Third-party imports
from flask import Flask, render_template, jsonify, request, send_from_directory
from flask_caching import Cache
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import requests

# Add src and config directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "config"))

# Local imports
from config import get_config, EMODNET_LAYERS
from emodnet_viewer.utils.logging_config import setup_logging, get_logger

# Initialize Flask app and configuration
app = Flask(__name__)
config = get_config()
app.config.from_object(config)

# Setup logging
setup_logging(config.LOG_LEVEL, config.LOG_FILE)
logger = get_logger(__name__)

# Initialize Flask-Caching with comprehensive configuration
cache_config = {
    'CACHE_TYPE': config.CACHE_TYPE,
    'CACHE_DEFAULT_TIMEOUT': config.CACHE_DEFAULT_TIMEOUT,
}

# Add Redis-specific configuration if using Redis
if config.CACHE_TYPE == 'redis':
    if config.CACHE_REDIS_URL:
        cache_config['CACHE_REDIS_URL'] = config.CACHE_REDIS_URL
    else:
        cache_config['CACHE_REDIS_HOST'] = config.CACHE_REDIS_HOST
        cache_config['CACHE_REDIS_PORT'] = config.CACHE_REDIS_PORT
        cache_config['CACHE_REDIS_DB'] = config.CACHE_REDIS_DB
        if config.CACHE_REDIS_PASSWORD:
            cache_config['CACHE_REDIS_PASSWORD'] = config.CACHE_REDIS_PASSWORD

# Add filesystem cache configuration if using filesystem
elif config.CACHE_TYPE == 'filesystem':
    cache_config['CACHE_DIR'] = config.CACHE_DIR
    cache_config['CACHE_THRESHOLD'] = config.CACHE_THRESHOLD

cache = Cache(app, config=cache_config)
logger.info(f"Cache initialized with type: {config.CACHE_TYPE}")

# Initialize Flask-Limiter for API rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://",
    strategy="fixed-window"
)

# Initialize requests session with connection pooling for WMS requests
# Connection pooling provides 20-40% performance improvement for repeated WMS calls
wms_session = requests.Session()
# Configure connection pool size (max connections to keep alive)
adapter = requests.adapters.HTTPAdapter(
    pool_connections=10,  # Number of connection pools to cache
    pool_maxsize=20,      # Max connections per pool
    max_retries=0,        # No retries for faster page loads
    pool_block=False      # Don't block if pool is full
)
wms_session.mount('http://', adapter)
wms_session.mount('https://', adapter)


# Security Headers Middleware
@app.after_request
def set_security_headers(response):
    """Add security headers to all responses"""
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'

    # HSTS only in production (requires HTTPS)
    if not app.config['DEBUG']:
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'

    return response


# WMS Service Configuration
WMS_BASE_URL = config.WMS_BASE_URL
WMS_VERSION = config.WMS_VERSION
WMS_TIMEOUT = config.WMS_TIMEOUT
WMS_CACHE_TIMEOUT = config.WMS_CACHE_TIMEOUT

# EMODnet Human Activities WMS Service Configuration
HUMAN_ACTIVITIES_WMS_BASE_URL = config.HUMAN_ACTIVITIES_WMS_BASE_URL
HUMAN_ACTIVITIES_WMS_VERSION = config.HUMAN_ACTIVITIES_WMS_VERSION

# Layer Filtering Configuration
CORE_EUROPEAN_LAYER_COUNT = config.CORE_EUROPEAN_LAYER_COUNT
EUROPEAN_LAYER_TERMS = ['eusm2021', 'eusm2019', 'europe', 'substrate', 'confidence', 'annexiMaps', 'ospar']
CARIBBEAN_EXCLUDE_TERMS = ['carib', 'caribbean']

# MarineSABRES research sites configuration is handled in JavaScript (research-sites.js)


# Layer filter functions (named for clarity and debugging)
def emodnet_layer_filter(layer):
    """Filter EMODnet layers - exclude workspace-prefixed names"""
    return ":" not in layer["name"]


def human_activities_layer_filter(layer):
    """Filter EMODnet Human Activities layers - only include layers with underscores"""
    return "_" in layer["name"]


def parse_wms_capabilities(xml_content, filter_fn=None):
    """
    Parse WMS GetCapabilities XML response with optional filtering

    Args:
        xml_content: XML content as bytes or string
        filter_fn: Optional function to filter layers (takes layer dict, returns bool)

    Returns:
        List of layer dictionaries
    """
    try:
        root = ET.fromstring(xml_content)

        # Optimized namespace handling - strip once during element access
        def strip_ns(tag):
            """Strip namespace from tag"""
            return tag.split('}')[1] if '}' in tag else tag

        wms_layers = []
        # Use namespace-aware iteration
        for layer in root.iter():
            if strip_ns(layer.tag) == 'Layer':
                name_elem = layer.find('.//{*}Name')
                title_elem = layer.find('.//{*}Title')
                abstract_elem = layer.find('.//{*}Abstract')

                if name_elem is not None and name_elem.text:
                    layer_name = name_elem.text.strip()

                    # Skip empty layer names
                    if not layer_name:
                        continue

                    layer_dict = {
                        "name": layer_name,
                        "title": (
                            title_elem.text
                            if title_elem is not None and title_elem.text
                            else layer_name
                        ),
                        "description": (
                            abstract_elem.text if abstract_elem is not None else ""
                        ),
                    }

                    # Apply filter if provided
                    if filter_fn is None or filter_fn(layer_dict):
                        wms_layers.append(layer_dict)

        logger.info(f"Parsed {len(wms_layers)} layers from WMS capabilities")
        return wms_layers

    except ET.ParseError as e:
        logger.error(f"XML parsing error in WMS capabilities: {e}")
        return []
    except Exception as e:
        logger.error(f"Unexpected error parsing WMS capabilities: {e}")
        return []


def prioritize_european_layers(wms_layers):
    """Prioritize European layers and combine with defaults using single-pass algorithm"""
    if not wms_layers:
        logger.warning("No WMS layers found, using fallback layers")
        return EMODNET_LAYERS

    # Single-pass categorization of WMS layers
    preferred_layers = []
    other_layers = []

    for wms_layer in wms_layers:
        name_lower = wms_layer['name'].lower()
        title_lower = (wms_layer.get('title') or '').lower()

        # Skip Caribbean layers entirely
        if any(term in name_lower or term in title_lower for term in CARIBBEAN_EXCLUDE_TERMS):
            continue

        # Categorize as European or other
        if any(term in name_lower or term in title_lower for term in EUROPEAN_LAYER_TERMS):
            preferred_layers.append(wms_layer)
        else:
            other_layers.append(wms_layer)

    # Build final layer list with deduplication
    core_european_layers = EMODNET_LAYERS[:CORE_EUROPEAN_LAYER_COUNT] if len(EMODNET_LAYERS) >= CORE_EUROPEAN_LAYER_COUNT else EMODNET_LAYERS
    final_layers = []
    added_names = set()

    # Priority order: Core European → Discovered European → Other WMS
    for layer_list in [core_european_layers, preferred_layers, other_layers]:
        for layer in layer_list:
            if layer['name'] not in added_names:
                final_layers.append(layer)
                added_names.add(layer['name'])

    logger.info(f"Prioritized {len(final_layers)} layers (European first)")
    return final_layers


@cache.cached(timeout=WMS_CACHE_TIMEOUT, key_prefix='wms_layers')
def get_available_layers():
    """
    Fetch available WMS layers with caching

    Returns:
        List of layer dictionaries
    """
    try:
        logger.info(f"Fetching WMS capabilities from {WMS_BASE_URL}")

        # Use connection-pooled session for better performance
        params = {"service": "WMS", "version": WMS_VERSION, "request": "GetCapabilities"}
        response = wms_session.get(WMS_BASE_URL, params=params, timeout=WMS_TIMEOUT)

        if response.status_code == 200:
            # Use named filter function for EMODnet layers
            wms_layers = parse_wms_capabilities(response.content, filter_fn=emodnet_layer_filter)
            final_layers = prioritize_european_layers(wms_layers)

            logger.info(f"Successfully fetched {len(final_layers)} WMS layers")
            return final_layers
        else:
            logger.warning(f"WMS request failed with status {response.status_code}, using fallback layers")
            return EMODNET_LAYERS

    except requests.RequestException as e:
        logger.warning(f"Network error fetching WMS layers (using fallback): {e}")
        return EMODNET_LAYERS
    except ET.ParseError as e:
        logger.error(f"XML parsing error in WMS response (using fallback): {e}")
        return EMODNET_LAYERS
    except Exception as e:
        logger.error(f"Unexpected error fetching layers (using fallback): {e}", exc_info=True)
        return EMODNET_LAYERS


@cache.cached(timeout=WMS_CACHE_TIMEOUT, key_prefix='human_activities_layers')
def get_human_activities_layers():
    """Fetch available layers from EMODnet Human Activities WMS GetCapabilities with caching"""
    try:
        logger.info(f"Fetching EMODnet Human Activities capabilities from {HUMAN_ACTIVITIES_WMS_BASE_URL}")

        params = {"service": "WMS", "version": HUMAN_ACTIVITIES_WMS_VERSION, "request": "GetCapabilities"}
        response = wms_session.get(HUMAN_ACTIVITIES_WMS_BASE_URL, params=params, timeout=WMS_TIMEOUT)

        if response.status_code == 200:
            # Use named filter function for Human Activities layers
            layers = parse_wms_capabilities(response.content, filter_fn=human_activities_layer_filter)

            logger.info(f"Successfully fetched {len(layers)} EMODnet Human Activities layers")
            return layers
        else:
            logger.warning(f"EMODnet Human Activities request failed with status {response.status_code}")
            return []

    except requests.RequestException as e:
        logger.warning(f"Network error fetching EMODnet Human Activities layers: {e}")
        return []
    except ET.ParseError as e:
        logger.error(f"XML parsing error in EMODnet Human Activities response: {e}")
        return []
    except Exception as e:
        logger.error(f"Unexpected error fetching EMODnet Human Activities layers: {e}", exc_info=True)
        return []


def get_all_layers():
    """Get both WMS and EMODnet Human Activities layers"""
    wms_layers = get_available_layers()
    human_activities_layers = get_human_activities_layers()

    combined_layers = {
        "wms_layers": wms_layers,
        "human_activities_layers": human_activities_layers,
    }

    return combined_layers


# Layer name validation
def validate_layer_name(layer_name: str) -> bool:
    """
    Validate layer name to prevent injection attacks

    Args:
        layer_name: Layer name to validate

    Returns:
        bool: True if valid, False otherwise
    """
    import re

    if not layer_name or len(layer_name) > 255:
        return False

    # Only allow alphanumeric, underscore, hyphen, colon, and dot
    # These are the only characters used in legitimate WMS layer names
    return bool(re.match(r'^[a-zA-Z0-9_\-:.]+$', layer_name))


# Flask route handlers

@app.route("/")
def index():
    """Main page with map viewer"""
    all_layers = get_all_layers()
    app_root = app.config.get('APPLICATION_ROOT', '')
    api_base_url = f"{app_root}/api" if app_root else "/api"

    return render_template(
        'index.html',
        layers=all_layers["wms_layers"],
        human_activities_layers=all_layers["human_activities_layers"],
        vector_layers=[],
        WMS_BASE_URL=WMS_BASE_URL,
        HUMAN_ACTIVITIES_WMS_BASE_URL=HUMAN_ACTIVITIES_WMS_BASE_URL,
        APPLICATION_ROOT=app_root,
        API_BASE_URL=api_base_url,
    )


@app.route("/health")
@limiter.exempt  # Health checks should not be rate limited
def health_check():
    """
    Health check endpoint for monitoring and load balancers

    Returns:
        JSON with health status and component availability
    """
    health_status = {
        "status": "healthy",
        "timestamp": None,  # Will be set below
        "version": __version__,
        "components": {}
    }

    # Get current timestamp (using timezone-aware datetime for Python 3.12+ compatibility)
    from datetime import datetime, timezone
    health_status["timestamp"] = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

    # Check WMS connectivity
    wms_healthy = False
    wms_error = None
    try:
        test_response = wms_session.get(WMS_BASE_URL, params={"service": "WMS", "request": "GetCapabilities"}, timeout=3)
        wms_healthy = test_response.status_code == 200
        if not wms_healthy:
            wms_error = f"HTTP {test_response.status_code}"
    except Exception as e:
        wms_error = str(e)

    health_status["components"]["wms_service"] = {
        "url": WMS_BASE_URL,
        "status": "operational" if wms_healthy else "degraded",
        "error": wms_error
    }

    # Check EMODnet Human Activities WMS connectivity
    human_activities_healthy = False
    human_activities_error = None
    try:
        test_response = wms_session.get(HUMAN_ACTIVITIES_WMS_BASE_URL, params={"service": "WMS", "request": "GetCapabilities"}, timeout=3)
        human_activities_healthy = test_response.status_code == 200
        if not human_activities_healthy:
            human_activities_error = f"HTTP {test_response.status_code}"
    except Exception as e:
        human_activities_error = str(e)

    health_status["components"]["human_activities_wms_service"] = {
        "url": HUMAN_ACTIVITIES_WMS_BASE_URL,
        "status": "operational" if human_activities_healthy else "degraded",
        "error": human_activities_error
    }

    # Check cache
    health_status["components"]["cache"] = {
        "type": config.CACHE_TYPE,
        "status": "operational"
    }

    # Overall status determination
    critical_services = [wms_healthy or human_activities_healthy]  # At least one WMS should work
    if not all(critical_services):
        health_status["status"] = "degraded"
        return jsonify(health_status), 503

    return jsonify(health_status), 200


@app.route("/logo/<filename>")
def serve_logo(filename):
    """Serve logo files from LOGO directory"""
    logo_dir = os.path.join(os.path.dirname(__file__), "LOGO")
    return send_from_directory(logo_dir, filename)


@app.route("/api/layers")
def api_layers():
    """API endpoint to get available WMS layers"""
    return jsonify(get_available_layers())


@app.route("/api/all-layers")
def api_all_layers():
    """API endpoint to get all layers (WMS and vector)"""
    return jsonify(get_all_layers())


@app.route("/api/capabilities")
@limiter.limit("30 per minute")  # Moderate limit for external WMS requests
def api_capabilities():
    """API endpoint to get WMS capabilities"""
    params = {"service": "WMS", "version": WMS_VERSION, "request": "GetCapabilities"}
    try:
        response = wms_session.get(WMS_BASE_URL, params=params, timeout=WMS_TIMEOUT)
        return response.content, 200, {"Content-Type": "text/xml"}
    except Exception as e:
        logger.error(f"Error in api_capabilities: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500


@app.route("/api/legend/<path:layer_name>")
@limiter.exempt  # Legend URLs are lightweight and can be unlimited
def api_legend(layer_name):
    """API endpoint to get legend for a specific layer"""
    # Validate layer name to prevent injection
    if not validate_layer_name(layer_name):
        logger.warning(f"Invalid layer name rejected: {layer_name}")
        return jsonify({"error": "Invalid layer name"}), 400

    legend_url = (
        f"{WMS_BASE_URL}?"
        f"service=WMS&version=1.1.0&request=GetLegendGraphic&"
        f"layer={layer_name}&format=image/png"
    )
    return jsonify({"legend_url": legend_url})


@app.route("/test")
def test_page():
    """Simple test page to verify WMS is working"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>WMS Test</title>
    </head>
    <body>
        <h1>EMODnet WMS Test</h1>
        <p>Testing direct WMS GetMap request:</p>
        <img src="https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms?service=WMS&version=1.1.0&request=GetMap&layers=all_eusm2021&bbox=-180,-90,180,90&width=768&height=384&srs=EPSG:4326&format=image/png"
             alt="WMS Test Image" style="max-width: 100%; border: 1px solid black;">
        <p>If you see a map image above, the WMS service is working correctly.</p>
    </body>
    </html>
    """
    return html


if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("MarineSABRES Demonstration Area Tool")
    logger.info("Marine Systems Approaches for Biodiversity Resilience and Ecosystem Sustainability")
    logger.info("=" * 60)
    logger.info("Initializing application...")

    # Vector data loading already initiated at module level
    logger.info("Starting Flask server...")
    logger.info("Open http://localhost:5000 in your browser")
    logger.info("\nAvailable endpoints:")
    logger.info("  /              - Main interactive map viewer")
    logger.info("  /health        - Health check endpoint for monitoring")
    logger.info("  /test          - Test WMS connectivity")
    logger.info("  /api/layers    - Get WMS layers (JSON)")
    logger.info("  /api/all-layers - Get all layers (WMS + Human Activities, JSON)")
    logger.info("  /api/capabilities - Get WMS capabilities (XML, rate limited)")
    logger.info("  /api/legend/<layer> - Get legend URL for a layer")

    logger.info("\nPress Ctrl+C to stop the server")
    logger.info("-" * 60)

    port = int(os.environ.get('FLASK_RUN_PORT', 5001))
    # Default to localhost for security (v1.2.0+) - use FLASK_HOST to override for deployment
    host = os.environ.get('FLASK_HOST', '127.0.0.1')

    # Determine public URL for deployment
    public_url = os.environ.get('PUBLIC_URL', 'http://laguna.ku.lt:5001')

    logger.info(f"\nServer accessible at:")
    logger.info(f"   Local:    http://127.0.0.1:{port}")
    logger.info(f"   Network:  {public_url}")

    app.run(debug=config.DEBUG, host=host, port=port)
