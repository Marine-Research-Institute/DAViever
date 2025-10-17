#!/bin/bash
cd /var/www/marbefes-bbt/templates

echo "🔧 Fixing vector layer IDs..."

# Backup
cp index.html index.html.backup.$(date +%Y%m%d_%H%M%S)
echo "✓ Backup created"

# Fix all hardcoded 'Bbts - Broad Belt Transects' references
sed -i "s/'Bbts - Broad Belt Transects'/'BBts.gpkg\/Broad Belt Transects'/g" index.html
echo "✓ Fixed hardcoded BBT references"

# Fix dynamic layer.display_name usage
sed -i 's/loadVectorLayer(layer\.display_name)/loadVectorLayer(`${layer.source_file}\/${layer.layer_name}`)/g' index.html
sed -i 's/loadVectorLayerFast(bbtLayer\.display_name)/loadVectorLayerFast(`${bbtLayer.source_file}\/${bbtLayer.layer_name}`)/g' index.html
sed -i 's/loadVectorLayerFast(vectorLayers\[0\]\.display_name)/loadVectorLayerFast(`${vectorLayers[0].source_file}\/${vectorLayers[0].layer_name}`)/g' index.html
echo "✓ Fixed dynamic layer loading"

echo ""
echo "✅ Vector layer fix applied!"
echo ""
echo "📋 Changes made:"
grep -n "BBts.gpkg" index.html | head -5
echo ""
echo "🌐 No server restart needed - just refresh your browser (Ctrl+F5)"
