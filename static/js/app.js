/**
 * Main Application Orchestrator
 * Coordinates initialization of all modules and manages application lifecycle
 */

(function() {
    'use strict';

    // Application state
    let map = null;
    let vectorLayerGroup = null;
    let initializationComplete = false;

    /**
     * Main application initialization
     */
    async function initApp() {
        console.log('🚀 MARBEFES BBT Database - Initializing application...');

        try {
            // 1. Initialize map
            console.log('📍 Step 1: Initializing map...');
            map = window.MapInit.initMap();
            if (!map) {
                throw new Error('Failed to initialize map');
            }

            // 2. Create vector layer group
            vectorLayerGroup = L.layerGroup().addTo(map);
            console.log('📊 Step 2: Vector layer group created');

            // 3. Initialize layer manager
            console.log('🗺️ Step 3: Initializing layer manager...');
            window.LayerManager.init(map, vectorLayerGroup);

            // 4. Initialize UI handlers
            console.log('🎛️ Step 4: Initializing UI handlers...');
            window.UIHandlers.init();

            // 5. Initialize BBT tool
            console.log('🔍 Step 5: Initializing BBT navigation tool...');
            if (window.BBTTool && typeof window.BBTTool.initialize === 'function') {
                // BBT tool initializes itself with delay, just ensure it's available
                console.log('✅ BBT Tool will initialize in background');
            } else {
                console.warn('⚠️ BBT Tool not available');
            }

            // 6. Load initial layers
            console.log('🌊 Step 6: Loading initial layers...');
            await loadInitialLayers();

            // 7. Setup layer dropdown options
            populateLayerDropdowns();

            // Mark initialization as complete
            initializationComplete = true;
            console.log('✅ Application initialization complete!');

            // Update status
            window.UIHandlers.showSuccess('Application ready', 2000);

        } catch (error) {
            console.error('❌ Application initialization failed:', error);
            window.UIHandlers.showError('Initialization failed: ' + error.message);
        }
    }

    /**
     * Load initial layers on startup
     */
    async function loadInitialLayers() {
        try {
            console.log('ℹ️ Vector layer loading disabled (GPKG functionality removed)');

            // Vector support disabled - skip loading
            if (window.vectorLayers && window.vectorLayers.length > 0) {
                console.warn('⚠️ Vector layers detected in template but support is disabled');
            }

            // DO NOT load default EUNIS layer at startup
            // Layer will be loaded automatically when user zooms to a BBT
            console.log('🗺️ EUNIS layer will load when zooming to BBT areas');

            // Enable automatic zoom-based layer switching
            window.LayerManager.enableAutoLayerSwitching(true);

        } catch (error) {
            console.error('❌ Error loading initial layers:', error);
            console.error('Stack trace:', error.stack);
            // Don't throw - app can still function
        }
    }

    /**
     * Populate layer selection dropdowns from template data
     */
    function populateLayerDropdowns() {
        const layerSelect = document.getElementById('layer-select');
        const humanActivitiesSelect = document.getElementById('human-activities-select');

        // Populate WMS layers (EMODnet Seabed Habitats)
        if (layerSelect && window.wmsLayers) {
            // Clear existing options except "None"
            layerSelect.innerHTML = '<option value="none">None (BBT only)</option>';

            // Add WMS layers
            window.wmsLayers.forEach(layer => {
                const option = document.createElement('option');
                option.value = 'wms:' + layer.name;
                option.textContent = layer.title || layer.name;
                layerSelect.appendChild(option);
            });

            console.log(`📋 Populated ${window.wmsLayers.length} EMODnet Seabed Habitats layers`);

            // Update status tooltip
            const emodnetStatusTooltip = document.getElementById('emodnet-status-tooltip');
            if (emodnetStatusTooltip) {
                emodnetStatusTooltip.textContent = 'No overlay';
                emodnetStatusTooltip.style.color = '#666';
            }
        }

        // Populate Human Activities layers
        if (humanActivitiesSelect && window.humanActivitiesLayers) {
            // Clear existing options except "None"
            humanActivitiesSelect.innerHTML = '<option value="none">None</option>';

            // Add Human Activities layers
            window.humanActivitiesLayers.forEach(layer => {
                const option = document.createElement('option');
                option.value = 'human_activities:' + layer.name;
                option.textContent = layer.title || layer.name;
                // Add description as title attribute for hover tooltip
                if (layer.description) {
                    option.title = layer.description;
                }
                humanActivitiesSelect.appendChild(option);
            });

            console.log(`📋 Populated ${window.humanActivitiesLayers.length} Human Activities layers`);

            // Update status tooltip
            const humanActivitiesStatusTooltip = document.getElementById('human-activities-status-tooltip');
            if (humanActivitiesStatusTooltip) {
                humanActivitiesStatusTooltip.textContent = 'No overlay';
                humanActivitiesStatusTooltip.style.color = '#666';
            }
        }
    }

    /**
     * Get application state
     */
    function getState() {
        return {
            initialized: initializationComplete,
            map: map,
            vectorLayerGroup: vectorLayerGroup,
            currentLayer: window.LayerManager ? window.LayerManager.getCurrentLayer() : null,
            currentLayerType: window.LayerManager ? window.LayerManager.getCurrentLayerType() : null
        };
    }

    /**
     * Cleanup and reset application
     */
    function cleanup() {
        console.log('🧹 Cleaning up application...');

        if (window.LayerManager) {
            window.LayerManager.clearLayers('all');
        }

        if (map) {
            map.remove();
            map = null;
        }

        vectorLayerGroup = null;
        initializationComplete = false;

        console.log('✅ Cleanup complete');
    }

    // Export public API
    window.App = {
        init: initApp,
        getState: getState,
        cleanup: cleanup,
        version: '2.0.0'
    };

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initApp);
    } else {
        // DOM already loaded
        initApp();
    }

    console.log('📦 Main application module loaded (v2.0.0)');
})();
