/**
 * BBT (Broad-scale Biotope) Tool Module
 *
 * Provides comprehensive BBT navigation, data management, and bathymetry visualization
 * for the MARBEFES project's marine biodiversity analysis across European seas.
 *
 * @module BBTTool
 * @requires Leaflet
 * @requires L.GeometryUtil (for geodesic area calculations)
 * @requires window.MapInit (for map instance access)
 *
 * @author MARBEFES Project Team
 * @version 1.1.0
 */

const BBTTool = (function() {
    'use strict';

    // ==================== Private Variables ====================

    /**
     * Cached BBT feature data from GeoJSON API
     * @private
     * @type {Object|null}
     */
    let bbtFeatureData = null;

    /**
     * Currently active BBT area name
     * @private
     * @type {string|null}
     */
    let currentActiveBBT = null;

    /**
     * Hover tooltip DOM element
     * @private
     * @type {HTMLElement|null}
     */
    let hoverTooltip = null;

    /**
     * Data store for BBT area information (editable by users)
     * @private
     * @type {Object}
     */
    let bbtDataStore = {};


    /**
     * Enhanced BBT region information from MARBEFES project
     * Contains research context, habitat descriptions, and scientific focus for each BBT area
     * @private
     * @type {Object}
     */
    const bbtRegionInfo = {
        'Archipelago': {
            region: 'Baltic Sea',
            description: 'Marine ecosystem functioning in the Swedish archipelago region',
            habitat: 'Coastal archipelago with complex habitat mosaic',
            research_focus: 'Benthic-pelagic coupling in coastal zones'
        },
        'Balearic': {
            region: 'Mediterranean Sea',
            description: 'Subtropical Mediterranean marine biodiversity hotspot',
            habitat: 'Mediterranean endemic species and Posidonia meadows',
            research_focus: 'Climate change impacts on Mediterranean ecosystems'
        },
        'Bay of Gdansk': {
            region: 'Baltic Sea',
            description: 'Semi-enclosed bay ecosystem with riverine influence',
            habitat: 'Brackish water transitional zone',
            research_focus: 'Land-sea connectivity and nutrient cycling'
        },
        'Gulf of Biscay': {
            region: 'Atlantic Ocean',
            description: 'Continental shelf ecosystem with upwelling dynamics',
            habitat: 'Deep-water Atlantic marine communities',
            research_focus: 'Ocean-shelf biodiversity gradients'
        },
        'Heraklion': {
            region: 'Mediterranean Sea',
            description: 'Eastern Mediterranean oligotrophic ecosystem',
            habitat: 'Deep Mediterranean basinal communities',
            research_focus: 'Deep-sea connectivity and endemic biodiversity'
        },
        'Hornsund': {
            region: 'Arctic Ocean',
            description: 'High Arctic fjord system with glacial influence',
            habitat: 'Arctic marine communities under climate change',
            research_focus: 'Arctic ecosystem resilience and tipping points'
        },
        'Kongsfjord': {
            region: 'Arctic Ocean',
            description: 'Arctic-Atlantic transition zone in Svalbard',
            habitat: 'Arctic-boreal species transition zone',
            research_focus: 'Climate-driven Arctic "atlantification"'
        },
        'Lithuanian coast': {
            region: 'Baltic Sea',
            description: 'Shallow coastal ecosystem with freshwater inputs',
            habitat: 'Sandy coastal waters with estuarine influence',
            research_focus: 'Coastal zone management and eutrophication'
        },
        'North Sea': {
            region: 'North Sea',
            description: 'Productive temperate shelf ecosystem',
            habitat: 'Continental shelf with diverse benthic communities',
            research_focus: 'Anthropogenic impacts and ecosystem services'
        },
        'Irish Sea': {
            region: 'Irish Sea',
            description: 'Semi-enclosed temperate marine ecosystem',
            habitat: 'Coastal and shelf habitats with tidal dynamics',
            research_focus: 'Marine spatial planning and biodiversity conservation'
        },
        'Sardinia': {
            region: 'Mediterranean Sea',
            description: 'Western Mediterranean island ecosystem',
            habitat: 'Mediterranean shelf communities and canyons',
            research_focus: 'Island biogeography and connectivity'
        }
    };

    /**
     * Template for editable BBT data fields
     * @private
     * @type {Object}
     */
    const bbtDataTemplate = {
        location: '',
        coordinates: '',
        depth_range: '',
        habitat_type: '',
        sampling_date: '',
        research_team: '',
        species_count: '',
        biodiversity_index: '',
        environmental_status: '',
        notes: ''
    };

    // ==================== BBT Feature Loading Functions ====================

    /**
     * Loads BBT features from the vector layer API
     * Fetches GeoJSON data for all BBT areas and caches for future use
     *
     * @async
     * @returns {Promise<Object>} GeoJSON feature collection with BBT areas
     * @throws {Error} If API request fails or returns non-OK status
     */
    async function loadBBTFeatures() {
        console.log('🔄 Loading BBT features from API...');

        try {
            const apiUrl = `${window.AppConfig.API_BASE_URL}/vector/layer/${encodeURIComponent('Bbt - Merged')}`;
            console.log('📡 Fetching from URL:', apiUrl);

            const response = await fetch(apiUrl);
            console.log('📥 API Response status:', response.status);

            if (response.ok) {
                bbtFeatureData = await response.json();
                console.log('✅ BBT features loaded successfully:', bbtFeatureData.features ? bbtFeatureData.features.length : 0, 'features');

                // Only call createBBTNavigationButtons in background loading mode
                // Buttons are now created statically in HTML
                console.log('ℹ️ BBT data ready for zoom operations');

                return bbtFeatureData;
            } else {
                const errorText = await response.text();

                // Handle 404 (not found) and 503 (service unavailable) as warnings, not errors
                if (response.status === 404) {
                    console.warn('⚠️ Vector data not available (no GPKG files):', response.status);
                } else if (response.status === 503) {
                    console.warn('⚠️ Vector service unavailable:', response.status, response.statusText);
                } else {
                    console.error('❌ API Error:', response.status, response.statusText, errorText);
                }

                throw new Error(`API Error: ${response.status}`);
            }
        } catch (error) {
            // Only log as error if it's not a 404 or 503 (expected when no vector data)
            if (!error.message.includes('404') && !error.message.includes('503')) {
                console.error('❌ Network Error loading BBT features:', error);
            }
            throw error;
        }
    }

    /**
     * Shows an error message when BBT features fail to load
     * Displays user-friendly error with retry link
     *
     * @param {string} message - Error message to display
     */
    function showBBTLoadingError(message) {
        const buttonsContainer = document.getElementById('bbt-nav-buttons');
        if (buttonsContainer) {
            buttonsContainer.innerHTML = `
                <div style="color: #CD5C5C; font-size: 11px; padding: 8px; text-align: center; border: 1px solid #CD5C5C; border-radius: 4px; background: #f0f8ff;">
                    ⚠️ ${message}
                    <br><small><a href="#" onclick="BBTTool.loadBBTFeatures(); return false;" style="color: #20B2AA;">Try again</a></small>
                </div>
            `;
        }
    }

    /**
     * Upgrades static BBT navigation buttons to interactive mode
     * Attaches event handlers and feature data to existing HTML buttons
     * Called after BBT features are loaded from API
     */
    function createBBTNavigationButtons() {
        console.log('✅ Upgrading BBT navigation buttons to interactive mode...');

        if (!bbtFeatureData || !bbtFeatureData.features) {
            console.error('No BBT feature data available');
            showBBTLoadingError('No feature data available');
            return;
        }

        const buttonsContainer = document.getElementById('bbt-nav-buttons');
        if (!buttonsContainer) {
            console.error('BBT buttons container not found');
            return;
        }

        console.log(`Found ${bbtFeatureData.features.length} BBT features to create buttons for`);

        // Show loading indicator
        const loadingElement = document.getElementById('bbt-loading');
        if (loadingElement) {
            loadingElement.style.display = 'block';
        }

        // Get all existing buttons (fallback buttons)
        const existingButtons = buttonsContainer.querySelectorAll('.bbt-nav-btn');
        console.log(`Found ${existingButtons.length} existing buttons to upgrade`);

        // Create feature lookup by name for easy matching
        const featuresByName = {};
        bbtFeatureData.features.forEach(feature => {
            const name = feature.properties.Name;
            if (name) {
                featuresByName[name] = feature;
            }
        });

        let upgradeCount = 0;

        // Upgrade existing buttons with interactive functionality
        existingButtons.forEach((button, index) => {
            const buttonText = button.textContent.trim();
            const matchingFeature = featuresByName[buttonText];

            if (matchingFeature) {
                // Replace the onclick with our interactive function
                button.onclick = () => zoomToBBTFeature(matchingFeature, button);
                button.title = `🗺️ Zoom to ${buttonText} BBT area`;

                // Add visual indication that it's now interactive
                button.style.position = 'relative';

                console.log(`✅ Upgraded button: "${buttonText}"`);
                upgradeCount++;
            } else {
                console.warn(`⚠️ No matching feature found for button: "${buttonText}"`);
            }
        });

        // Hide loading indicator
        if (loadingElement) {
            setTimeout(() => {
                loadingElement.style.display = 'none';
            }, 500);
        }

        console.log(`✅ Successfully upgraded ${upgradeCount} BBT navigation buttons to interactive mode!`);

        // Final verification
        setTimeout(() => {
            const allButtons = buttonsContainer.querySelectorAll('.bbt-nav-btn');
            console.log(`✅ Final verification: ${allButtons.length} interactive buttons ready`);

            // Add subtle animation to show they're now interactive
            allButtons.forEach((btn, idx) => {
                btn.style.transition = 'all 0.3s ease';
                setTimeout(() => {
                    btn.style.transform = 'scale(1.05)';
                    setTimeout(() => {
                        btn.style.transform = 'scale(1)';
                    }, 200);
                }, idx * 50);
            });
        }, 600);
    }

    // ==================== BBT Zoom Functions ====================

    /**
     * Zooms map to a specific BBT feature with bounds fitting
     * Ensures user-defined zoom level (5-15, default 11) to activate EUNIS layer
     *
     * @param {Object} feature - GeoJSON feature object for the BBT area
     * @param {HTMLElement} buttonElement - The button element that triggered the zoom
     */
    function zoomToBBTFeature(feature, buttonElement) {
        if (!feature.geometry) return;

        const map = window.MapInit.getMap();

        // Calculate bounds for the feature
        let bounds = L.latLngBounds();

        if (feature.geometry.type === 'Polygon') {
            feature.geometry.coordinates[0].forEach(coord => {
                bounds.extend([coord[1], coord[0]]);
            });
        } else if (feature.geometry.type === 'MultiPolygon') {
            feature.geometry.coordinates.forEach(polygon => {
                polygon[0].forEach(coord => {
                    bounds.extend([coord[1], coord[0]]);
                });
            });
        }

        // Zoom to the feature bounds (mode-dependent: fit bounds or force zoom 12)
        if (bounds.isValid()) {
            const zoomMode = window.bbtZoomMode || 'detail'; // 'fit' or 'detail'

            if (zoomMode === 'detail') {
                // Force zoom to user-defined level for optimal EUNIS visibility
                const zoomLevel = window.bbtDetailZoomLevel || 11;
                const center = bounds.getCenter();
                map.setView(center, zoomLevel);
            } else {
                // Fit bounds to show entire BBT area
                map.fitBounds(bounds, { padding: [20, 20] });
            }

            const areaName = feature.properties.Name;

            // Load EUNIS full layer for this BBT area after zoom completes
            setTimeout(() => {
                console.log('🗺️ [BBT-TOOL] Loading EUNIS full layer for BBT area:', areaName);
                console.log('🗺️ [BBT-TOOL] LayerManager available:', !!window.LayerManager);
                console.log('🗺️ [BBT-TOOL] selectWMSLayerAsOverlay available:', !!(window.LayerManager && window.LayerManager.selectWMSLayerAsOverlay));

                if (window.LayerManager && window.LayerManager.selectWMSLayerAsOverlay) {
                    console.log('🗺️ [BBT-TOOL] Calling selectWMSLayerAsOverlay with: eusm_2023_eunis2019_full');
                    window.LayerManager.selectWMSLayerAsOverlay('eusm_2023_eunis2019_full');

                    // Update dropdown to reflect loaded layer
                    const layerSelect = document.getElementById('layer-select');
                    if (layerSelect) {
                        layerSelect.value = 'wms:eusm_2023_eunis2019_full';
                        console.log('🗺️ [BBT-TOOL] Updated dropdown to show: eusm_2023_eunis2019_full');
                    } else {
                        console.warn('⚠️ [BBT-TOOL] layer-select dropdown not found');
                    }
                } else {
                    console.error('❌ [BBT-TOOL] LayerManager or selectWMSLayerAsOverlay not available!');
                }
            }, 300);

            // Update active button state
            if (buttonElement) {
                document.querySelectorAll('.bbt-nav-btn').forEach(btn => {
                    btn.classList.remove('active');
                });
                buttonElement.classList.add('active');
            }
            currentActiveBBT = areaName;

            // Update status
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = `Zoomed to ${areaName}`;
            }

            // Auto-load vector layer if not already loaded (requires global context)
            if (typeof window.selectVectorLayerAsBase === 'function') {
                if (window.currentLayerType !== 'vector' || !window.vectorLayerGroup?.getLayers().length) {
                    window.selectVectorLayerAsBase('Bbt - Merged');
                }
            }
        }
    }

    /**
     * Optimized direct zoom to BBT area by name (no zoom bounce)
     * Uses cached data for instant zoom, fetches if not available
     *
     * @param {string} areaName - Name of the BBT area to zoom to
     */
    function zoomToBBTArea(areaName) {
        console.log('🎯 Zooming directly to BBT area:', areaName);

        const map = window.MapInit.getMap();

        // Set manual zoom flag to prevent auto-reload
        if (typeof window.isManualZoom !== 'undefined') {
            window.isManualZoom = true;
            console.log('🔒 Manual zoom mode enabled');
        }

        // Update button states immediately
        document.querySelectorAll('.bbt-nav-btn').forEach(btn => {
            btn.classList.remove('active');
            if (btn.textContent === areaName) {
                btn.classList.add('active');
            }
        });

        // Set layer selection state (requires global context)
        if (typeof window.currentLayer !== 'undefined') {
            window.currentLayer = 'Bbt - Merged';
            window.currentLayerType = 'vector';
        }

        // Check if we already have BBT data cached
        if (bbtFeatureData && bbtFeatureData.features) {
            console.log('⚡ Using cached BBT data for instant zoom');

            // Find the specific feature
            const feature = bbtFeatureData.features.find(f => f.properties.Name === areaName);

            if (feature) {
                console.log('✅ Found specific BBT feature in cache, zooming instantly...');

                // Update status
                const statusEl = document.getElementById('status');
                if (statusEl) {
                    statusEl.textContent = `Zooming to ${areaName}...`;
                    statusEl.className = 'status loading';
                }

                // Check if BBT layer is already loaded (optimization: skip re-rendering if already visible)
                const isBBTLayerLoaded = window.currentLayer === 'Bbt - Merged' &&
                                        window.vectorLayerGroup &&
                                        window.vectorLayerGroup.getLayers().length > 0;

                if (!isBBTLayerLoaded) {
                    console.log('🔄 BBT layer not loaded, loading it now...');
                    // Clear any existing layers first
                    if (typeof window.vectorLayerGroup !== 'undefined') {
                        window.vectorLayerGroup.clearLayers();
                    }

                    // Load the complete layer WITHOUT auto-zoom
                    if (typeof window.loadVectorLayerWithoutAutoZoom === 'function') {
                        window.loadVectorLayerWithoutAutoZoom('Bbt - Merged', bbtFeatureData);
                    }
                } else {
                    console.log('⚡ BBT layer already loaded, skipping re-render!');
                }

                // Zoom directly to the specific feature immediately (no delay needed if layer exists)
                const zoomDelay = isBBTLayerLoaded ? 0 : 50;
                setTimeout(() => {
                    zoomToBBTFeatureDirect(feature, areaName);
                }, zoomDelay);
            } else {
                console.log('⚠️ Specific feature not found in cache');
                zoomToGeneralBBTArea(areaName);
            }
            return;
        }

        // If no cache, fetch the data (first time only)
        console.log('📡 Loading BBT data for first time...');
        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.textContent = `Loading ${areaName}...`;
            statusEl.className = 'status loading';
        }

        // Load the BBT vector layer data
        fetch(`${window.AppConfig.API_BASE_URL}/vector/layer/${encodeURIComponent('Bbt - Merged')}`)
            .then(response => {
                console.log('📥 BBT layer API response:', response.status);
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                return response.json();
            })
            .then(geojson => {
                console.log('✅ BBT data loaded, features:', geojson.features ? geojson.features.length : 0);

                // Store the data for future use
                bbtFeatureData = geojson;

                // Find the specific feature
                const feature = geojson.features.find(f => f.properties.Name === areaName);

                if (feature) {
                    console.log('✅ Found specific BBT feature, zooming directly...');

                    // Clear any existing layers first
                    if (typeof window.vectorLayerGroup !== 'undefined') {
                        window.vectorLayerGroup.clearLayers();
                    }

                    // Load the complete layer WITHOUT auto-zoom
                    if (typeof window.loadVectorLayerWithoutAutoZoom === 'function') {
                        window.loadVectorLayerWithoutAutoZoom('Bbt - Merged', geojson);
                    }

                    // Then zoom directly to the specific feature with optimized timing
                    setTimeout(() => {
                        zoomToBBTFeatureDirect(feature, areaName);
                    }, 100); // Reduced delay for faster UX
                } else {
                    console.log('⚠️ Specific feature not found, loading full layer...');
                    // Fallback to fast cached loading
                    if (typeof window.loadVectorLayerFast === 'function') {
                        window.loadVectorLayerFast('Bbt - Merged');
                    }
                }
            })
            .catch(error => {
                console.error('❌ Failed to load BBT data:', error);
                const statusEl = document.getElementById('status');
                if (statusEl) {
                    statusEl.textContent = `Failed to load ${areaName}`;
                    statusEl.className = 'status error';
                }

                // Fallback zoom
                console.log('📍 Using fallback zoom');
                zoomToGeneralBBTArea(areaName);
            });
    }

    /**
     * Direct zoom to BBT feature without bounce (optimized helper)
     * Calculates bounds and applies zoom with minimum level constraint
     *
     * @param {Object} feature - GeoJSON feature object
     * @param {string} areaName - Name of the BBT area
     */
    function zoomToBBTFeatureDirect(feature, areaName) {
        console.log('🎯 Zooming directly to BBT feature:', areaName);

        const map = window.MapInit.getMap();

        // Calculate bounds for the feature
        let bounds = L.latLngBounds();

        if (feature.geometry.type === 'Polygon') {
            feature.geometry.coordinates[0].forEach(coord => {
                bounds.extend([coord[1], coord[0]]);
            });
        } else if (feature.geometry.type === 'MultiPolygon') {
            feature.geometry.coordinates.forEach(polygon => {
                polygon[0].forEach(coord => {
                    bounds.extend([coord[1], coord[0]]);
                });
            });
        }

        // Zoom to the feature bounds (mode-dependent: fit bounds or force zoom 12)
        if (bounds.isValid()) {
            const zoomMode = window.bbtZoomMode || 'detail'; // 'fit' or 'detail'

            if (zoomMode === 'detail') {
                // Force zoom to user-defined level for optimal EUNIS visibility
                const zoomLevel = window.bbtDetailZoomLevel || 11;
                const center = bounds.getCenter();
                map.setView(center, zoomLevel);
            } else {
                // Fit bounds to show entire BBT area
                map.fitBounds(bounds, { padding: [30, 30] });
            }

            // Load EUNIS full layer for this BBT area after zoom completes
            setTimeout(() => {
                console.log('🗺️ [BBT-TOOL] Loading EUNIS full layer for BBT area:', areaName);
                console.log('🗺️ [BBT-TOOL] LayerManager available:', !!window.LayerManager);
                console.log('🗺️ [BBT-TOOL] selectWMSLayerAsOverlay available:', !!(window.LayerManager && window.LayerManager.selectWMSLayerAsOverlay));

                if (window.LayerManager && window.LayerManager.selectWMSLayerAsOverlay) {
                    console.log('🗺️ [BBT-TOOL] Calling selectWMSLayerAsOverlay with: eusm_2023_eunis2019_full');
                    window.LayerManager.selectWMSLayerAsOverlay('eusm_2023_eunis2019_full');

                    // Update dropdown to reflect loaded layer
                    const layerSelect = document.getElementById('layer-select');
                    if (layerSelect) {
                        layerSelect.value = 'wms:eusm_2023_eunis2019_full';
                        console.log('🗺️ [BBT-TOOL] Updated dropdown to show: eusm_2023_eunis2019_full');
                    } else {
                        console.warn('⚠️ [BBT-TOOL] layer-select dropdown not found');
                    }
                } else {
                    console.error('❌ [BBT-TOOL] LayerManager or selectWMSLayerAsOverlay not available!');
                }
            }, 300);

            // Update status
            const statusEl = document.getElementById('status');
            if (statusEl) {
                statusEl.textContent = `Zoomed to ${areaName}`;
                statusEl.className = 'status success';
            }

            console.log('✅ Direct zoom completed for:', areaName);

            // Reset manual zoom flag after zoom animation completes (500ms delay)
            setTimeout(() => {
                if (typeof window.isManualZoom !== 'undefined') {
                    window.isManualZoom = false;
                    console.log('🔓 Manual zoom mode disabled');
                }
            }, 500);
        } else {
            console.log('⚠️ Invalid bounds, using fallback zoom');
            zoomToGeneralBBTArea(areaName);

            // Reset flag even on fallback
            setTimeout(() => {
                if (typeof window.isManualZoom !== 'undefined') {
                    window.isManualZoom = false;
                    console.log('🔓 Manual zoom mode disabled (fallback)');
                }
            }, 500);
        }
    }

    /**
     * Fallback function for general BBT area zoom
     * Uses vector layer bounds or defaults to European marine area
     *
     * @param {string} areaName - Name of the BBT area
     */
    function zoomToGeneralBBTArea(areaName) {
        console.log('📍 Using general BBT area zoom for:', areaName);

        const map = window.MapInit.getMap();

        // Use vector layer bounds if available
        if (window.vectorLayerGroup && window.vectorLayerGroup.getLayers().length > 0) {
            const bounds = window.vectorLayerGroup.getBounds();
            if (bounds.isValid()) {
                map.fitBounds(bounds, {padding: [20, 20], maxZoom: 10});
                const statusEl = document.getElementById('status');
                if (statusEl) {
                    statusEl.textContent = `Showing ${areaName} in BBT layer`;
                    statusEl.className = 'status success';
                }
                return;
            }
        }

        // Final fallback: zoom to general European marine area
        map.setView([55.0, 10.0], 4);
        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.textContent = `Showing general area for ${areaName}`;
            statusEl.className = 'status warning';
        }
    }

    // ==================== BBT Area Calculation Functions ====================

    /**
     * Calculates the geodesic area of a GeoJSON feature in square kilometers
     * Uses Leaflet GeometryUtil for accurate spherical calculations
     *
     * @param {Object} feature - GeoJSON feature object
     * @returns {number|null} Area in km² (rounded to 2 decimals) or null if calculation fails
     */
    function calculateFeatureArea(feature) {
        if (!feature.geometry) return null;

        try {
            // Use Leaflet's built-in area calculation for polygons
            let area = 0;

            if (feature.geometry.type === 'Polygon') {
                const coords = feature.geometry.coordinates[0];
                area = L.GeometryUtil ? L.GeometryUtil.geodesicArea(coords.map(c => L.latLng(c[1], c[0]))) : 0;
            } else if (feature.geometry.type === 'MultiPolygon') {
                feature.geometry.coordinates.forEach(polygon => {
                    const coords = polygon[0];
                    area += L.GeometryUtil ? L.GeometryUtil.geodesicArea(coords.map(c => L.latLng(c[1], c[0]))) : 0;
                });
            }

            // Convert from square meters to square kilometers
            return area > 0 ? (area / 1000000).toFixed(2) : null;
        } catch (error) {
            // Fallback: simple bounding box area calculation
            if (feature.geometry.type === 'Polygon' || feature.geometry.type === 'MultiPolygon') {
                try {
                    const layer = L.geoJSON(feature);
                    const bounds = layer.getBounds();
                    const area = (bounds.getEast() - bounds.getWest()) * (bounds.getNorth() - bounds.getSouth()) * 12321; // Rough conversion
                    return area > 0 ? area.toFixed(2) : null;
                } catch (e) {
                    return null;
                }
            }
            return null;
        }
    }

    // ==================== Tooltip Functions ====================

    /**
     * Creates and displays a hover tooltip at specified coordinates
     *
     * @param {string} content - HTML content for the tooltip
     * @param {number} x - X coordinate (pixels from left)
     * @param {number} y - Y coordinate (pixels from top)
     */
    function createTooltip(content, x, y) {
        removeTooltip();

        hoverTooltip = document.createElement('div');
        hoverTooltip.className = 'vector-tooltip';
        hoverTooltip.innerHTML = content;
        hoverTooltip.style.left = x + 'px';
        hoverTooltip.style.top = (y - 10) + 'px';

        document.body.appendChild(hoverTooltip);
    }

    /**
     * Removes the current hover tooltip from the DOM
     */
    function removeTooltip() {
        if (hoverTooltip) {
            document.body.removeChild(hoverTooltip);
            hoverTooltip = null;
        }
    }

    /**
     * Updates the position of the existing tooltip
     *
     * @param {number} x - New X coordinate
     * @param {number} y - New Y coordinate
     */
    function updateTooltip(x, y) {
        if (hoverTooltip) {
            hoverTooltip.style.left = x + 'px';
            hoverTooltip.style.top = (y - 10) + 'px';
        }
    }

    /**
     * Generates enhanced tooltip content for BBT features with MARBEFES context
     * Includes area calculation, regional information, and research focus
     *
     * @param {Object} feature - GeoJSON feature object
     * @param {string} layerName - Name of the current layer
     * @returns {string} HTML content for the tooltip
     */
    function generateTooltipContent(feature, layerName) {
        let content = '';

        if (layerName && layerName.toLowerCase().includes('bbt')) {
            // Special handling for BBT layers with MARBEFES context
            const siteName = feature.properties?.Name || feature.properties?.name;
            const siteInfo = siteName ? bbtRegionInfo[siteName] : null;

            content += '<div class="tooltip-title">🌊 MARBEFES Broad Belt Transect</div>';

            if (siteName) {
                content += `<div style="font-weight: 600; color: #FFFFFF; margin: 4px 0;">${siteName}</div>`;
            }

            // Calculate area
            const area = calculateFeatureArea(feature);
            if (area) {
                content += `<div class="tooltip-area">📐 Area: ${area} km²</div>`;
            }

            // Add MARBEFES project context
            if (siteInfo) {
                content += `<div style="margin: 8px 0; padding: 6px; background: rgba(32, 178, 170, 0.1); border-radius: 4px;">`;
                content += `<div style="font-size: 11px; color: #20B2AA; font-weight: 600;">🗺️ ${siteInfo.region}</div>`;
                content += `<div style="font-size: 10px; margin-top: 2px; color: #E2E8F0;">${siteInfo.description}</div>`;
                content += `<div style="font-size: 10px; margin-top: 3px; color: #CBD5E0;"><strong>Habitat:</strong> ${siteInfo.habitat}</div>`;
                content += `<div style="font-size: 10px; margin-top: 2px; color: #CBD5E0;"><strong>Research:</strong> ${siteInfo.research_focus}</div>`;
                content += `</div>`;
            } else {
                // Generic MARBEFES info if specific site not found
                content += `<div style="margin: 8px 0; padding: 6px; background: rgba(32, 178, 170, 0.1); border-radius: 4px;">`;
                content += `<div style="font-size: 10px; color: #E2E8F0;">Part of the MARBEFES project studying marine biodiversity across European seas from river-to-ocean gradients.</div>`;
                content += `</div>`;
            }
        } else {
            // Generic vector layer tooltip
            content += '<div class="tooltip-title">Vector Feature</div>';
            const area = calculateFeatureArea(feature);
            if (area) {
                content += `<div class="tooltip-area">Area: ${area} km²</div>`;
            }

            // Show first few properties
            if (feature.properties) {
                const propEntries = Object.entries(feature.properties).slice(0, 3);
                propEntries.forEach(([key, value]) => {
                    if (value !== null && value !== undefined && value !== '') {
                        content += `<div>${key}: ${value}</div>`;
                    }
                });
            }
        }

        return content;
    }

    // ==================== BBT Data Management Functions ====================

    /**
     * Initializes BBT data store with default templates for all BBT locations
     * Called on page load or before opening data popup
     */
    function initializeBBTData() {
        const bbtLocations = [
            'Archipelago', 'Balearic', 'Bay of Gdansk', 'Gulf of Biscay',
            'Heraklion', 'Hornsund', 'Kongsfjord', 'Lithuanian coastal zone', 'Sardinia'
        ];

        bbtLocations.forEach(location => {
            if (!bbtDataStore[location]) {
                bbtDataStore[location] = {
                    ...bbtDataTemplate,
                    location: location
                };
            }
        });
    }

    /**
     * Opens the BBT data popup for a specific BBT area
     * Displays editable fields and bathymetry statistics if available
     *
     * @param {string} bbtName - Name of the BBT area
     */
    function openBBTDataPopup(bbtName) {
        console.log('📊 Opening BBT data popup for:', bbtName);

        // Get bathymetry stats from global context if available
        const bathymetryStats = window.bathymetryStats || {};
        console.log('📊 Available bathymetry data:', Object.keys(bathymetryStats));

        // Initialize if not done
        if (Object.keys(bbtDataStore).length === 0) {
            initializeBBTData();
        }

        // Get or create data for this BBT
        if (!bbtDataStore[bbtName]) {
            bbtDataStore[bbtName] = {
                ...bbtDataTemplate,
                location: bbtName
            };
        }

        const data = bbtDataStore[bbtName];

        // Update popup title
        const titleEl = document.getElementById('bbt-popup-title');
        if (titleEl) {
            titleEl.textContent = `${bbtName} - BBT Data`;
        }

        // Generate bathymetry stats section if available
        const bbtStats = bathymetryStats[bbtName];
        console.log(`🌊 Bathymetry lookup for "${bbtName}":`, bbtStats);
        console.log(`🌊 Stats available: ${bbtStats ? 'YES' : 'NO'}`);

        const bathymetrySection = bbtStats ? `
            <div class="bbt-data-section" style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin-bottom: 20px;">
                <h3 style="margin-top: 0; color: #1976d2; font-size: 16px; margin-bottom: 10px;">
                    🌊 Bathymetry Statistics
                </h3>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px;">
                    <div>
                        <strong>Min Depth:</strong> ${bbtStats.min_depth_m} m
                    </div>
                    <div>
                        <strong>Max Depth:</strong> ${bbtStats.max_depth_m} m
                    </div>
                    <div>
                        <strong>Avg Depth:</strong> ${bbtStats.avg_depth_m} m
                    </div>
                    <div>
                        <strong>Depth Range:</strong> ${(bbtStats.max_depth_m - bbtStats.min_depth_m).toFixed(1)} m
                    </div>
                </div>
                ${bbtStats.notes ? `<div style="font-style: italic; color: #555; margin-bottom: 8px;">${bbtStats.notes}</div>` : ''}
                <div style="font-size: 12px; color: #666;">
                    Source: ${bbtStats.sample_count ? 'EMODnet Bathymetry (sampled)' : 'Manual bathymetric data'}
                </div>
            </div>
        ` : '';

        // Generate form fields
        const content = `
            <div class="bbt-data-field">
                <label for="bbt-location">Location</label>
                <input type="text" id="bbt-location" value="${data.location}" readonly>
            </div>
            ${bathymetrySection}
            <div class="bbt-data-field">
                <label for="bbt-coordinates">Coordinates (Lat, Lon)</label>
                <input type="text" id="bbt-coordinates" value="${data.coordinates}" placeholder="e.g., 60.5, 25.2">
            </div>
            <div class="bbt-data-field">
                <label for="bbt-depth">Depth Range (m)</label>
                <input type="text" id="bbt-depth" value="${data.depth_range}" placeholder="e.g., 10-50m">
            </div>
            <div class="bbt-data-field">
                <label for="bbt-habitat">Habitat Type</label>
                <select id="bbt-habitat">
                    <option value="">Select habitat type</option>
                    <option value="Rocky reef" ${data.habitat_type === 'Rocky reef' ? 'selected' : ''}>Rocky reef</option>
                    <option value="Sandy bottom" ${data.habitat_type === 'Sandy bottom' ? 'selected' : ''}>Sandy bottom</option>
                    <option value="Muddy bottom" ${data.habitat_type === 'Muddy bottom' ? 'selected' : ''}>Muddy bottom</option>
                    <option value="Mixed sediment" ${data.habitat_type === 'Mixed sediment' ? 'selected' : ''}>Mixed sediment</option>
                    <option value="Seagrass meadow" ${data.habitat_type === 'Seagrass meadow' ? 'selected' : ''}>Seagrass meadow</option>
                    <option value="Kelp forest" ${data.habitat_type === 'Kelp forest' ? 'selected' : ''}>Kelp forest</option>
                </select>
            </div>
            <div class="bbt-data-field">
                <label for="bbt-sampling-date">Last Sampling Date</label>
                <input type="date" id="bbt-sampling-date" value="${data.sampling_date}">
            </div>
            <div class="bbt-data-field">
                <label for="bbt-research-team">Research Team</label>
                <input type="text" id="bbt-research-team" value="${data.research_team}" placeholder="e.g., Institute Name">
            </div>
            <div class="bbt-data-field">
                <label for="bbt-species-count">Species Count</label>
                <input type="number" id="bbt-species-count" value="${data.species_count}" placeholder="Number of species">
            </div>
            <div class="bbt-data-field">
                <label for="bbt-biodiversity">Biodiversity Index</label>
                <input type="text" id="bbt-biodiversity" value="${data.biodiversity_index}" placeholder="e.g., Shannon index">
            </div>
            <div class="bbt-data-field">
                <label for="bbt-env-status">Environmental Status</label>
                <select id="bbt-env-status">
                    <option value="">Select status</option>
                    <option value="Excellent" ${data.environmental_status === 'Excellent' ? 'selected' : ''}>Excellent</option>
                    <option value="Good" ${data.environmental_status === 'Good' ? 'selected' : ''}>Good</option>
                    <option value="Moderate" ${data.environmental_status === 'Moderate' ? 'selected' : ''}>Moderate</option>
                    <option value="Poor" ${data.environmental_status === 'Poor' ? 'selected' : ''}>Poor</option>
                    <option value="Bad" ${data.environmental_status === 'Bad' ? 'selected' : ''}>Bad</option>
                </select>
            </div>
            <div class="bbt-data-field">
                <label for="bbt-notes">Additional Notes</label>
                <textarea id="bbt-notes" placeholder="Enter any additional observations or notes...">${data.notes}</textarea>
            </div>
        `;

        const contentEl = document.getElementById('bbt-popup-content');
        if (contentEl) {
            contentEl.innerHTML = content;
        }

        console.log(`🌊 Bathymetry section included: ${bathymetrySection ? 'YES' : 'NO'}`);
        console.log(`🌊 Content length: ${content.length} characters`);

        // Store current BBT name for saving
        const overlayEl = document.getElementById('bbt-popup-overlay');
        if (overlayEl) {
            overlayEl.dataset.currentBbt = bbtName;
            overlayEl.classList.add('active');
        }
    }

    /**
     * Closes the BBT data popup
     */
    function closeBBTDataPopup() {
        const overlayEl = document.getElementById('bbt-popup-overlay');
        if (overlayEl) {
            overlayEl.classList.remove('active');
        }
    }

    /**
     * Saves BBT data from the popup form
     * Collects all form values and stores in bbtDataStore
     * TODO: Implement backend API integration for persistent storage
     */
    function saveBBTData() {
        const overlayEl = document.getElementById('bbt-popup-overlay');
        const bbtName = overlayEl ? overlayEl.dataset.currentBbt : null;

        if (!bbtName) {
            console.error('No BBT name found for saving');
            return;
        }

        // Collect data from form
        const updatedData = {
            location: document.getElementById('bbt-location')?.value || '',
            coordinates: document.getElementById('bbt-coordinates')?.value || '',
            depth_range: document.getElementById('bbt-depth')?.value || '',
            habitat_type: document.getElementById('bbt-habitat')?.value || '',
            sampling_date: document.getElementById('bbt-sampling-date')?.value || '',
            research_team: document.getElementById('bbt-research-team')?.value || '',
            species_count: document.getElementById('bbt-species-count')?.value || '',
            biodiversity_index: document.getElementById('bbt-biodiversity')?.value || '',
            environmental_status: document.getElementById('bbt-env-status')?.value || '',
            notes: document.getElementById('bbt-notes')?.value || ''
        };

        // Save to store
        bbtDataStore[bbtName] = updatedData;

        console.log('💾 Saved BBT data for', bbtName, updatedData);

        // TODO: Send data to backend API
        // fetch(`${window.AppConfig.API_BASE_URL}/bbt/data/${encodeURIComponent(bbtName)}`, {
        //     method: 'POST',
        //     headers: { 'Content-Type': 'application/json' },
        //     body: JSON.stringify(updatedData)
        // });

        // Show success message
        alert(`✅ Data saved successfully for ${bbtName}!`);

        // Close popup
        closeBBTDataPopup();
    }

    // ==================== Initialization Functions ====================

    /**
     * Enhanced BBT Navigation Initialization (background loading)
     * Loads BBT features asynchronously without blocking page load
     *
     * @async
     */
    async function initializeBBTNavigation() {
        console.log('🚀 Background loading BBT navigation data...');
        try {
            await loadBBTFeatures(); // Load data in background for future use
            createBBTNavigationButtons(); // Upgrade buttons after data loads
            console.log('✅ BBT navigation initialized successfully');
        } catch (error) {
            // Check if it's a 404 error (no vector data) or 503 (vector support disabled)
            if (error.message.includes('404')) {
                console.info('ℹ️ No vector data available - BBT navigation disabled (this is normal if no GPKG files are present)');
                // Don't show error message for 404 - this is expected when no vector data
            } else if (error.message.includes('503')) {
                console.warn('⚠️ Vector support disabled - BBT navigation unavailable');
                showBBTLoadingError('BBT features unavailable (vector support disabled)');
            } else {
                console.error('❌ Failed to initialize BBT navigation:', error);
                showBBTLoadingError('Failed to load BBT features');
            }
        }
    }

    /**
     * Initializes event listeners for BBT data popup
     * Sets up click-outside and keyboard (Escape) handlers
     */
    function initializeBBTDataPopupListeners() {
        // Close popup when clicking outside
        const overlayEl = document.getElementById('bbt-popup-overlay');
        if (overlayEl) {
            overlayEl.addEventListener('click', function(e) {
                if (e.target === this) {
                    closeBBTDataPopup();
                }
            });
        }

        // Close popup with Escape key
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                const overlay = document.getElementById('bbt-popup-overlay');
                if (overlay && overlay.classList.contains('active')) {
                    closeBBTDataPopup();
                }
            }
        });
    }

    // ==================== Public API ====================

    return {
        // Feature loading
        loadBBTFeatures: loadBBTFeatures,
        showBBTLoadingError: showBBTLoadingError,
        createBBTNavigationButtons: createBBTNavigationButtons,

        // Zoom functions
        zoomToBBTFeature: zoomToBBTFeature,
        zoomToBBTArea: zoomToBBTArea,
        zoomToBBTFeatureDirect: zoomToBBTFeatureDirect,
        zoomToGeneralBBTArea: zoomToGeneralBBTArea,

        // Area calculation
        calculateFeatureArea: calculateFeatureArea,

        // Tooltip functions
        createTooltip: createTooltip,
        removeTooltip: removeTooltip,
        updateTooltip: updateTooltip,
        generateTooltipContent: generateTooltipContent,

        // Data management
        initializeBBTData: initializeBBTData,
        openBBTDataPopup: openBBTDataPopup,
        closeBBTDataPopup: closeBBTDataPopup,
        saveBBTData: saveBBTData,

        // Initialization
        initialize: initializeBBTNavigation,
        initializePopupListeners: initializeBBTDataPopupListeners,

        // Data access (read-only)
        getBBTRegionInfo: () => ({ ...bbtRegionInfo }),
        getCurrentActiveBBT: () => currentActiveBBT,
        getBBTDataStore: () => ({ ...bbtDataStore })
    };
})();

// Auto-initialization DISABLED - vector support removed
// BBT Tool functionality disabled (GPKG files removed)
console.log('ℹ️ BBT Tool disabled (vector support removed)');

// Export to global scope for backward compatibility
window.BBTTool = BBTTool;

// Export commonly used functions to global scope for HTML onclick handlers
window.openBBTDataPopup = BBTTool.openBBTDataPopup;
window.closeBBTDataPopup = BBTTool.closeBBTDataPopup;
window.saveBBTData = BBTTool.saveBBTData;
window.zoomToBBTArea = BBTTool.zoomToBBTArea;

// BBT Zoom Mode Toggle Function
window.setBBTZoomMode = function(mode) {
    console.log('🔄 Setting BBT zoom mode to:', mode);
    window.bbtZoomMode = mode;

    // Update button states
    document.getElementById('zoom-mode-detail').classList.toggle('active', mode === 'detail');
    document.getElementById('zoom-mode-fit').classList.toggle('active', mode === 'fit');

    // Show/hide zoom level slider based on mode
    const sliderContainer = document.getElementById('zoom-level-slider-container');
    if (sliderContainer) {
        sliderContainer.style.display = mode === 'detail' ? 'block' : 'none';
    }

    // Update description
    const descEl = document.getElementById('zoom-mode-description');
    if (mode === 'detail') {
        const zoomLevel = window.bbtDetailZoomLevel || 11;
        descEl.textContent = `Full Detail: Always zoom to level ${zoomLevel} for optimal habitat layer visibility`;
    } else {
        descEl.textContent = 'Fit Bounds: Show entire BBT area extent (zoom level varies by size)';
    }

    console.log('✅ BBT zoom mode set to:', mode);
};

// BBT Detail Zoom Level Update Function
window.updateBBTZoomLevel = function(level) {
    const zoomLevel = parseInt(level);
    window.bbtDetailZoomLevel = zoomLevel;

    // Update display value
    const valueDisplay = document.getElementById('bbt-zoom-level-value');
    if (valueDisplay) {
        valueDisplay.textContent = zoomLevel;
    }

    // Update description if in detail mode
    if (window.bbtZoomMode === 'detail') {
        const descEl = document.getElementById('zoom-mode-description');
        if (descEl) {
            descEl.textContent = `Full Detail: Always zoom to level ${zoomLevel} for optimal habitat layer visibility`;
        }
    }

    console.log(`✅ BBT detail zoom level set to: ${zoomLevel}`);
};

// Initialize zoom mode and level on load
if (typeof window.bbtZoomMode === 'undefined') {
    window.bbtZoomMode = 'detail'; // Default to full detail mode
}
if (typeof window.bbtDetailZoomLevel === 'undefined') {
    window.bbtDetailZoomLevel = 11; // Default zoom level
}
