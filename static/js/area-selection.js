/**
 * Area Selection & Analysis Module
 * Enables users to draw areas on the map and analyze them
 *
 * Dependencies:
 * - Leaflet library
 * - Leaflet.draw plugin
 * - window.AppConfig (from config.js)
 * - window.MapInit.getMap() (from map-init.js)
 */

(function(window) {
    'use strict';

    // Private variables
    let map = null;
    let drawControl = null;
    let drawnItems = null;
    let selectedArea = null;
    let currentAnalysisData = null;
    let currentLayerOverlapData = null;
    let isDrawingEnabled = false;

    /**
     * Initialize the area selection module
     * @param {L.Map} mapInstance - Leaflet map instance
     */
    function init(mapInstance) {
        if (!mapInstance) {
            console.error('AreaSelection: Map instance is required');
            return;
        }

        map = mapInstance;

        // Check if Leaflet.draw is available
        if (typeof L.Draw === 'undefined') {
            console.warn('Leaflet.draw not loaded. Area selection will not be available.');
            return;
        }

        // Initialize drawn items layer
        drawnItems = new L.FeatureGroup();
        map.addLayer(drawnItems);

        // Create draw control (but don't add to map yet)
        createDrawControl();

        // Setup event handlers
        setupEventHandlers();

        console.log('✅ AreaSelection initialized');
    }

    /**
     * Create Leaflet.draw control
     */
    function createDrawControl() {
        drawControl = new L.Control.Draw({
            position: 'topright',
            draw: {
                polyline: false,  // Disable line drawing
                polygon: {
                    allowIntersection: false,
                    showArea: true,
                    metric: true,
                    shapeOptions: {
                        color: '#20B2AA',
                        fillColor: '#20B2AA',
                        fillOpacity: 0.2,
                        weight: 3
                    }
                },
                circle: {
                    showRadius: true,
                    metric: true,
                    shapeOptions: {
                        color: '#FF6B6B',
                        fillColor: '#FF6B6B',
                        fillOpacity: 0.2,
                        weight: 3
                    }
                },
                rectangle: {
                    showArea: true,
                    metric: true,
                    shapeOptions: {
                        color: '#4ECDC4',
                        fillColor: '#4ECDC4',
                        fillOpacity: 0.2,
                        weight: 3
                    }
                },
                marker: false,
                circlemarker: false
            },
            edit: {
                featureGroup: drawnItems,
                remove: true
            }
        });
    }

    /**
     * Setup map event handlers for drawing
     */
    function setupEventHandlers() {
        // Area created
        map.on(L.Draw.Event.CREATED, function(event) {
            const layer = event.layer;
            const type = event.layerType;

            console.log(`Area created: ${type}`);

            // Clear previous drawings
            drawnItems.clearLayers();

            // Add new drawing
            drawnItems.addLayer(layer);

            // Store the selected area
            selectedArea = {
                layer: layer,
                type: type,
                geometry: layer.toGeoJSON().geometry
            };

            // Show area info and trigger analysis
            showAreaInfo();
            analyzeArea();
        });

        // Area edited
        map.on(L.Draw.Event.EDITED, function(event) {
            const layers = event.layers;

            layers.eachLayer(function(layer) {
                selectedArea = {
                    layer: layer,
                    type: selectedArea.type,
                    geometry: layer.toGeoJSON().geometry
                };
            });

            console.log('Area edited');
            showAreaInfo();
            analyzeArea();
        });

        // Area deleted
        map.on(L.Draw.Event.DELETED, function(event) {
            console.log('Area deleted');
            clearSelection();
        });
    }

    /**
     * Enable drawing tools
     */
    function enableDrawing() {
        if (!drawControl) {
            console.error('Draw control not initialized');
            return;
        }

        if (!isDrawingEnabled) {
            map.addControl(drawControl);
            isDrawingEnabled = true;

            // Show drawing instructions
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = 'Drawing tools enabled. Select a shape to start.';
                statusEl.className = 'status';
            }

            // Update button state
            updateToggleButton(true);

            console.log('Drawing tools enabled');
        }
    }

    /**
     * Disable drawing tools
     */
    function disableDrawing() {
        if (drawControl && isDrawingEnabled) {
            map.removeControl(drawControl);
            isDrawingEnabled = false;

            // Hide area info
            hideAreaInfo();

            // Update status
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = 'Drawing tools disabled';
                statusEl.className = 'status';
            }

            // Update button state
            updateToggleButton(false);

            console.log('Drawing tools disabled');
        }
    }

    /**
     * Toggle drawing tools on/off
     */
    function toggleDrawing() {
        if (isDrawingEnabled) {
            disableDrawing();
        } else {
            enableDrawing();
        }
    }

    /**
     * Update toggle button state
     */
    function updateToggleButton(enabled) {
        const btn = document.getElementById('toggle-drawing-tools');
        if (btn) {
            if (enabled) {
                btn.textContent = '📐 Disable Drawing Tools';
                btn.classList.add('active');
            } else {
                btn.textContent = '📐 Enable Drawing Tools';
                btn.classList.remove('active');
            }
        }
    }

    /**
     * Show area info panel
     */
    function showAreaInfo() {
        const panel = document.getElementById('area-info-panel');
        if (panel) {
            panel.style.display = 'block';
        }

        // Display loading state
        updateAreaStats('Calculating...', '-', '-');
    }

    /**
     * Hide area info panel
     */
    function hideAreaInfo() {
        const panel = document.getElementById('area-info-panel');
        if (panel) {
            panel.style.display = 'none';
        }
    }

    /**
     * Update area statistics display
     */
    function updateAreaStats(area, perimeter, centroid) {
        const areaEl = document.getElementById('area-size');
        const perimeterEl = document.getElementById('area-perimeter');
        const centroidEl = document.getElementById('area-centroid');

        if (areaEl) areaEl.textContent = area;
        if (perimeterEl) perimeterEl.textContent = perimeter;
        if (centroidEl) centroidEl.textContent = centroid;
    }

    /**
     * Analyze the selected area
     */
    async function analyzeArea() {
        if (!selectedArea) {
            console.error('No area selected');
            return;
        }

        try {
            // Show loading state
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = 'Analyzing area...';
                statusEl.className = 'status loading';
            }

            // Call backend API
            const response = await fetch(`${window.AppConfig.API_BASE_URL}/analyze-area`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    geometry: selectedArea.geometry,
                    include_statistics: true
                })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error || 'Analysis failed');
            }

            const data = await response.json();
            currentAnalysisData = data;

            // Update display
            updateAreaStats(
                `${data.area_km2} km²`,
                `${data.perimeter_km} km`,
                `${data.centroid[1].toFixed(4)}°N, ${data.centroid[0].toFixed(4)}°E`
            );

            // Update status
            if (statusEl) {
                const sitesText = data.research_sites.length > 0
                    ? ` - Overlaps ${data.research_sites.length} research site(s)`
                    : '';
                statusEl.textContent = `Area analyzed: ${data.area_km2} km²${sitesText}`;
                statusEl.className = 'status';
            }

            console.log('✅ Area analysis complete:', data);

            // Show detailed results in console for now
            if (data.research_sites.length > 0) {
                console.log('📍 Overlapping research sites:');
                data.research_sites.forEach(site => {
                    console.log(`  - ${site.name}: ${site.overlap_percentage}% overlap`);
                });
            }

            // Now check layer overlap
            checkLayerOverlap();

        } catch (error) {
            console.error('❌ Area analysis error:', error);

            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = `Analysis error: ${error.message}`;
                statusEl.className = 'status error';
            }
        }
    }

    /**
     * Check for EMODnet layer overlap with selected area
     */
    async function checkLayerOverlap() {
        if (!selectedArea) {
            console.error('No area selected');
            return;
        }

        try {
            // Show loading state
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = 'Checking layer overlap...';
                statusEl.className = 'status loading';
            }

            // Call backend API
            const response = await fetch(`${window.AppConfig.API_BASE_URL}/check-layer-overlap`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    geometry: selectedArea.geometry
                })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error || 'Layer overlap check failed');
            }

            const data = await response.json();
            currentLayerOverlapData = data;

            // Update status
            if (statusEl) {
                const layersText = data.total_overlapping > 0
                    ? ` - ${data.total_overlapping} human activities layer(s) overlap`
                    : ' - No overlapping layers found';
                statusEl.textContent = `Layer overlap check complete${layersText}`;
                statusEl.className = 'status';
            }

            console.log('✅ Layer overlap check complete:', data);

            // Show detailed results in console
            if (data.overlapping_layers && data.overlapping_layers.length > 0) {
                console.log('🌊 Overlapping EMODnet Human Activities layers:');
                data.overlapping_layers.forEach((layer, idx) => {
                    console.log(`  ${idx + 1}. ${layer.name} (${layer.overlap_percentage}% overlap)`);
                });
            }

            // Update the UI to show overlap button
            updateLayerOverlapButton(data.total_overlapping);

        } catch (error) {
            console.error('❌ Layer overlap check error:', error);

            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = `Layer overlap error: ${error.message}`;
                statusEl.className = 'status error';
            }
        }
    }

    /**
     * Update layer overlap button visibility
     */
    function updateLayerOverlapButton(count) {
        const btn = document.getElementById('show-layer-overlap-btn');
        if (btn) {
            if (count > 0) {
                btn.style.display = 'inline-block';
                btn.textContent = `📊 View ${count} Overlapping Layer(s)`;
            } else {
                btn.style.display = 'none';
            }
        }
    }

    /**
     * Show detailed analysis results in modal
     */
    function showAnalysisResults() {
        if (!currentAnalysisData) {
            alert('No analysis data available. Please draw an area first.');
            return;
        }

        // Create modal content
        let modalHTML = '<div class="analysis-results">';
        modalHTML += '<h3>📊 Area Analysis Results</h3>';

        // Basic statistics
        modalHTML += '<div class="analysis-section">';
        modalHTML += '<h4>Basic Statistics</h4>';
        modalHTML += `<p><strong>Area:</strong> ${currentAnalysisData.area_km2} km²</p>`;
        modalHTML += `<p><strong>Perimeter:</strong> ${currentAnalysisData.perimeter_km} km</p>`;
        modalHTML += `<p><strong>Center:</strong> ${currentAnalysisData.centroid[1].toFixed(4)}°N, ${currentAnalysisData.centroid[0].toFixed(4)}°E</p>`;
        modalHTML += `<p><strong>Geometry Type:</strong> ${currentAnalysisData.geometry_type}</p>`;
        modalHTML += '</div>';

        // Research sites
        if (currentAnalysisData.research_sites.length > 0) {
            modalHTML += '<div class="analysis-section">';
            modalHTML += '<h4>Research Site Overlap</h4>';
            modalHTML += '<ul>';
            currentAnalysisData.research_sites.forEach(site => {
                modalHTML += `<li><strong>${site.name}</strong> (${site.region}): ${site.overlap_percentage}% overlap</li>`;
            });
            modalHTML += '</ul>';
            modalHTML += '</div>';
        } else {
            modalHTML += '<div class="analysis-section">';
            modalHTML += '<p><em>No research site overlap detected</em></p>';
            modalHTML += '</div>';
        }

        // Layer overlap results
        if (currentLayerOverlapData && currentLayerOverlapData.overlapping_layers) {
            modalHTML += '<div class="analysis-section">';
            modalHTML += '<h4>EMODnet Human Activities Layer Overlap</h4>';

            if (currentLayerOverlapData.overlapping_layers.length > 0) {
                modalHTML += `<p>Found ${currentLayerOverlapData.total_overlapping} overlapping layers (out of ${currentLayerOverlapData.total_checked} total):</p>`;
                modalHTML += '<ul>';
                currentLayerOverlapData.overlapping_layers.slice(0, 10).forEach(layer => {
                    modalHTML += `<li><strong>${layer.name}</strong>: ${layer.overlap_percentage}% overlap</li>`;
                });
                if (currentLayerOverlapData.overlapping_layers.length > 10) {
                    modalHTML += `<li><em>...and ${currentLayerOverlapData.overlapping_layers.length - 10} more</em></li>`;
                }
                modalHTML += '</ul>';
            } else {
                modalHTML += '<p><em>No overlapping human activities layers detected</em></p>';
            }
            modalHTML += '</div>';
        }

        // Analysis timestamp
        modalHTML += '<div class="analysis-section">';
        modalHTML += `<p class="timestamp"><small>Analysis performed: ${new Date(currentAnalysisData.timestamp).toLocaleString()}</small></p>`;
        modalHTML += '</div>';

        modalHTML += '</div>';

        // Show in alert for now (could be enhanced with proper modal)
        alert(modalHTML.replace(/<[^>]*>/g, '\n'));
    }

    /**
     * Show layer overlap results in detail
     */
    function showLayerOverlapResults() {
        if (!currentLayerOverlapData) {
            alert('No layer overlap data available. Please draw an area first.');
            return;
        }

        // Create detailed results text
        let results = '🌊 EMODnet Human Activities Layer Overlap Results\n';
        results += '=' . repeat(50) + '\n\n';

        results += `Total Layers Checked: ${currentLayerOverlapData.total_checked}\n`;
        results += `Overlapping Layers: ${currentLayerOverlapData.total_overlapping}\n\n`;

        if (currentLayerOverlapData.overlapping_layers.length > 0) {
            results += 'Overlapping Layers (sorted by coverage):\n\n';

            currentLayerOverlapData.overlapping_layers.forEach((layer, idx) => {
                results += `${idx + 1}. ${layer.name}\n`;
                results += `   Overlap: ${layer.overlap_percentage}%\n`;
                if (layer.description) {
                    const shortDesc = layer.description.substring(0, 100);
                    results += `   Description: ${shortDesc}${layer.description.length > 100 ? '...' : ''}\n`;
                }
                results += '\n';
            });
        } else {
            results += '\nNo overlapping layers found in the selected area.\n';
        }

        results += '\n' + '='.repeat(50);
        results += `\nAnalysis Time: ${new Date(currentLayerOverlapData.timestamp).toLocaleString()}`;

        // Show results
        alert(results);

        // Also log to console for detailed information
        console.log('📊 Detailed Layer Overlap Results:', currentLayerOverlapData);
    }

    /**
     * Export area data
     */
    async function exportArea(format = 'geojson') {
        if (!selectedArea || !currentAnalysisData) {
            alert('No area selected. Please draw and analyze an area first.');
            return;
        }

        try {
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = `Exporting as ${format.toUpperCase()}...`;
                statusEl.className = 'status loading';
            }

            const response = await fetch(`${window.AppConfig.API_BASE_URL}/export-area`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    geometry: selectedArea.geometry,
                    format: format,
                    analysis_data: currentAnalysisData
                })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error || 'Export failed');
            }

            // Get filename from Content-Disposition header
            const contentDisposition = response.headers.get('Content-Disposition');
            let filename = `area_export.${format}`;
            if (contentDisposition) {
                const matches = /filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/.exec(contentDisposition);
                if (matches && matches[1]) {
                    filename = matches[1].replace(/['"]/g, '');
                }
            }

            // Download file
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.style.display = 'none';
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);

            if (statusEl) {
                statusEl.textContent = `Exported as ${filename}`;
                statusEl.className = 'status';
            }

            console.log(`✅ Export complete: ${filename}`);

        } catch (error) {
            console.error('❌ Export error:', error);

            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = `Export error: ${error.message}`;
                statusEl.className = 'status error';
            }
        }
    }

    /**
     * Clear current selection
     */
    function clearSelection() {
        if (drawnItems) {
            drawnItems.clearLayers();
        }

        selectedArea = null;
        currentAnalysisData = null;
        currentLayerOverlapData = null;

        hideAreaInfo();

        // Hide layer overlap button
        updateLayerOverlapButton(0);

        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.textContent = 'Selection cleared';
            statusEl.className = 'status';
        }

        console.log('Selection cleared');
    }

    /**
     * Get selected area data
     */
    function getSelectedArea() {
        return selectedArea;
    }

    /**
     * Get current analysis data
     */
    function getAnalysisData() {
        return currentAnalysisData;
    }

    // Public API
    window.AreaSelection = {
        init,
        enableDrawing,
        disableDrawing,
        toggleDrawing,
        analyzeArea,
        checkLayerOverlap,
        showAnalysisResults,
        showLayerOverlapResults,
        exportArea,
        clearSelection,
        getSelectedArea,
        getAnalysisData,
        getLayerOverlapData: () => currentLayerOverlapData,
        isEnabled: () => isDrawingEnabled
    };

    console.log('📦 Area Selection module loaded');

})(window);
