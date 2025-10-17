#!/bin/bash
echo "=== LAYER NAME CONSISTENCY CHECK ==="
echo ""
echo "1. Checking bbt-tool.js for layer references:"
grep -n "Bbt.*Merged\|Bbt.*Areas\|CheckedBBT" /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/static/js/bbt-tool.js | head -10

echo ""
echo "2. Checking app.js for layer references:"
grep -n "Bbt.*Merged\|Bbt.*Areas\|CheckedBBT" /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/static/js/app.js

echo ""
echo "3. Checking index.html BBT buttons:"
grep -n "Lithuanian" /home/razinka/OneDrive/HORIZON_EUROPE/MARBEFES/EMODNET_PyDeck/templates/index.html | grep -v backup

echo ""
echo "4. Checking API response structure:"
curl -s http://localhost:5000/api/vector/layers | python3 -c "import json, sys; d=json.load(sys.stdin); print('Layer display_name:', d['layers'][0]['display_name'] if d['layers'] else 'NONE')"
