#!/bin/bash
#
# Calculate bathymetry statistics for BBT areas
#
# This script calculates min, max, and average depth for each BBT area
# using EMODnet Bathymetry data via WMS GetFeatureInfo requests.
#
# Usage:
#   ./calculate_bathymetry.sh [--verbose] [--samples N]
#
# Options:
#   --verbose    Enable verbose logging
#   --samples N  Number of sample points per dimension (default: 25)
#
# Output:
#   data/bbt_bathymetry_stats.json
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🌊  BBT Bathymetry Statistics Calculator${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: python3 not found${NC}"
    exit 1
fi

# Check dependencies
echo -e "${YELLOW}📦 Checking dependencies...${NC}"
python3 -c "import geopandas, numpy, requests" 2>/dev/null || {
    echo -e "${RED}❌ Missing dependencies. Please install:${NC}"
    echo "   pip install geopandas numpy requests"
    exit 1
}
echo -e "${GREEN}✓ Dependencies OK${NC}"
echo ""

# Check if BBT data exists
if [ ! -f "data/vector/BBT.gpkg" ]; then
    echo -e "${RED}❌ Error: BBT data not found at data/vector/BBT.gpkg${NC}"
    exit 1
fi

# Run the Python script
echo -e "${YELLOW}🚀 Starting bathymetry calculation...${NC}"
echo -e "${YELLOW}⏱️  This may take several minutes (multiple API requests per BBT)${NC}"
echo ""

python3 scripts/calculate_bathymetry.py "$@"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Bathymetry calculation completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📁 Output file: data/bbt_bathymetry_stats.json${NC}"

    # Show file size
    if [ -f "data/bbt_bathymetry_stats.json" ]; then
        FILE_SIZE=$(du -h data/bbt_bathymetry_stats.json | cut -f1)
        echo -e "${BLUE}📊 File size: ${FILE_SIZE}${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Bathymetry calculation failed${NC}"
    exit $EXIT_CODE
fi
