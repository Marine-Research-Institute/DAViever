#!/bin/bash
#
# Update bathymetry statistics from CSV file
#
# This script converts CSV bathymetry data to JSON format for the web application.
# Edit data/bbt_bathymetry_manual.csv with your bathymetry data, then run this script.
#
# Usage:
#   ./update_bathymetry_from_csv.sh
#

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🌊  Update BBT Bathymetry from CSV${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if CSV file exists
if [ ! -f "data/bbt_bathymetry_manual.csv" ]; then
    echo -e "${YELLOW}⚠  CSV file not found: data/bbt_bathymetry_manual.csv${NC}"
    echo ""
    echo "Creating template CSV file..."

    cat > data/bbt_bathymetry_manual.csv << 'EOF'
BBT_Name,Min_Depth_m,Max_Depth_m,Avg_Depth_m,Notes
Archipelago,5.2,45.8,25.3,Shallow coastal waters
Balearic,15.5,120.3,67.8,Mediterranean shelf
EOF

    echo -e "${GREEN}✓${NC} Template created at data/bbt_bathymetry_manual.csv"
    echo "  Please edit this file with your bathymetry data and run this script again."
    exit 0
fi

# Run the Python converter
echo -e "${YELLOW}📊 Converting CSV to JSON...${NC}"
python3 scripts/csv_to_bathymetry_json.py

echo ""
echo -e "${GREEN}✅ Bathymetry data updated!${NC}"
echo -e "${BLUE}📁 Output: data/bbt_bathymetry_stats.json${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart the Flask app to load new data"
echo "  2. Or deploy to production: ./deploy_production.sh"
echo ""
