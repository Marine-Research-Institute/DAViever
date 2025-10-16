#!/usr/bin/env python3
"""
MarineSABRES DA Tool - Flask Application Runner
A dedicated script to run the Flask application with proper configuration.
"""

import os
import sys
from pathlib import Path

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("Warning: python-dotenv not installed. Using system environment variables only.")

# Add src directory to path for imports
project_root = Path(__file__).parent
src_path = project_root / "src"
sys.path.insert(0, str(src_path))

def check_dependencies():
    """Check if all required dependencies are available."""
    missing_deps = []

    try:
        import flask
        print(f"✓ Flask {flask.__version__} available")
    except ImportError:
        missing_deps.append("Flask")

    try:
        import requests
        print(f"✓ Requests {requests.__version__} available")
    except ImportError:
        missing_deps.append("requests")

    try:
        import geopandas
        print(f"✓ GeoPandas {geopandas.__version__} available")
    except ImportError:
        print("⚠ GeoPandas not available - vector support will be disabled")

    try:
        import fiona
        print(f"✓ Fiona {fiona.__version__} available")
    except ImportError:
        print("⚠ Fiona not available - vector support will be disabled")

    if missing_deps:
        print(f"\n❌ Missing required dependencies: {', '.join(missing_deps)}")
        print("Please install them using: pip install -r requirements-venv.txt")
        return False

    return True

def setup_directories():
    """Create necessary directories if they don't exist."""
    directories = [
        "data/vector",
        "logs",
        "static",
        "templates"
    ]

    for directory in directories:
        dir_path = project_root / directory
        dir_path.mkdir(parents=True, exist_ok=True)
        print(f"✓ Directory ready: {directory}")

def main():
    """Main application runner."""
    print("=" * 60)
    print("MarineSABRES DA Tool - Flask Application Runner")
    print("=" * 60)
    print()

    # Check dependencies
    print("🔍 Checking dependencies...")
    if not check_dependencies():
        sys.exit(1)
    print()

    # Setup directories
    print("📁 Setting up directories...")
    setup_directories()
    print()

    # Import and configure the Flask app
    try:
        from app import app
        print("✓ Flask application imported successfully")
    except ImportError as e:
        print(f"❌ Failed to import Flask application: {e}")
        sys.exit(1)

    # Configure Flask app from environment
    app.config.update(
        DEBUG=os.getenv('FLASK_DEBUG', 'True').lower() in ('true', '1', 'yes'),
        SECRET_KEY=os.getenv('SECRET_KEY', 'dev-key-change-in-production'),
        ENV=os.getenv('FLASK_ENV', 'development')
    )

    # Get server configuration
    host = os.getenv('HOST', '127.0.0.1')
    port = int(os.getenv('PORT', '5000'))
    debug = app.config['DEBUG']

    print("🚀 Starting Flask development server...")
    print(f"   Host: {host}")
    print(f"   Port: {port}")
    print(f"   Debug: {debug}")
    print(f"   URL: http://{host}:{port}")
    print()
    print("Available endpoints:")
    print("   /              - Main interactive map viewer")
    print("   /test          - WMS connectivity test")
    print("   /api/layers    - Get WMS layers (JSON)")
    print("   /api/all-layers - Get all layers (JSON)")
    print("   /api/vector/layers - Get vector layers (JSON)")
    print("   /api/capabilities - Get WMS capabilities (XML)")
    print()
    print("Press Ctrl+C to stop the server")
    print("-" * 60)
    print()

    # Run the Flask application
    try:
        app.run(host=host, port=port, debug=debug, threaded=True)
    except KeyboardInterrupt:
        print("\n\n👋 Flask server stopped by user")
    except Exception as e:
        print(f"\n❌ Flask server error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()