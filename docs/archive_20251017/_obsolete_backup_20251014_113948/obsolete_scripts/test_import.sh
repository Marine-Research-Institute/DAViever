#!/bin/bash
################################################################################
# Test Python Imports - Find the Real Error
################################################################################

PROD_DIR="/var/www/marbefes-bbt"

echo "================================"
echo "Testing Python Imports as www-data user"
echo "================================"
echo ""

cd "$PROD_DIR"

sudo -u www-data "$PROD_DIR/venv/bin/python" << 'PYEOF'
import sys
import os

# Set up paths exactly as the app does
sys.path.insert(0, '/var/www/marbefes-bbt')
sys.path.insert(0, os.path.join('/var/www/marbefes-bbt', "src"))
sys.path.insert(0, os.path.join('/var/www/marbefes-bbt', "config"))

print("Python paths:")
for p in sys.path[:5]:
    print(f"  {p}")
print()

# Test each import step by step
print("Step 1: Import app module...")
try:
    import app
    print("✓ app module imported")
except Exception as e:
    print(f"✗ FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("Step 2: Import wsgi_subpath module...")
try:
    import wsgi_subpath
    print("✓ wsgi_subpath module imported")
except Exception as e:
    print(f"✗ FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("Step 3: Get application object...")
try:
    from wsgi_subpath import application
    print(f"✓ application object loaded: {type(application)}")
except Exception as e:
    print(f"✗ FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("Step 4: Test if application is callable...")
try:
    # Test if it's a valid WSGI app
    print(f"  Callable: {callable(application)}")
    print(f"  Type: {type(application).__name__}")
    print("✓ Application looks valid!")
except Exception as e:
    print(f"✗ FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("=" * 50)
print("✓ ALL IMPORTS SUCCESSFUL!")
print("=" * 50)
print()
print("If imports work, the issue might be:")
print("1. Gunicorn configuration problem")
print("2. Permission issue with log files")
print("3. Port already in use")
print()
print("Next step: Run 'sudo ./test_gunicorn.sh' to test Gunicorn")
PYEOF

echo ""
echo "================================"
echo "Import test complete!"
echo "================================"
