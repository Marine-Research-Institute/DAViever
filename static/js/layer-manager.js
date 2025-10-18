/**
 * Layer Manager Module
 *
 * Comprehensive layer management for WMS, HELCOM, and Vector layers
 * with interactive tooltips, GetFeatureInfo, and extent management.
 *
 * Dependencies:
 * - window.AppConfig (from config.js)
 * - window.MapInit.getMap() (from map-init.js)
 * - Leaflet library
 * - Leaflet.GeometryUtil plugin (optional, for accurate area calculations)
 */

(function(window) {
    'use strict';

    // ========================================
    // PRIVATE VARIABLES
    // ========================================

    let map = null;
    let currentLayer = null;
    let currentLayerType = 'vector'; // 'wms', 'wms-overlay', 'helcom-overlay', 'vector'
    let currentOpacity = 0.7;
    let wmsLayer = null;
    let helcomLayer = null;
    let vectorLayerGroup = null;
    let hoverTooltip = null;
    let currentActiveBBT = null;
    let autoSwitchEnabled = true;
    let lastAutoSwitchedZoom = -1;
    let isManualZoom = false;

    // Layer cache for instant access (simplification-aware)
    const layerCache = new Map();

    // Factsheet data cache
    const factsheetCache = new Map();
    let factsheetsLoaded = false;

    // Enhanced BBT region information from MARBEFES project
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

    // ========================================
    // INITIALIZATION
    // ========================================

    /**
     * Initialize the layer manager with map instance
     * @param {L.Map} mapInstance - Leaflet map instance
     * @param {L.LayerGroup} vectorGroup - Vector layer group for BBT features
     */
    function init(mapInstance, vectorGroup) {
        if (!mapInstance) {
            console.error('LayerManager: Map instance is required');
            return;
        }

        map = mapInstance;
        vectorLayerGroup = vectorGroup || L.layerGroup();

        // Initialize map event handlers
        setupMapEventHandlers();

        // NOTE: Factsheet loading disabled - not applicable for MarineSABRES DA tool
        // (Previously used for MARBEFES BBT project)
        // loadFactsheets();

        console.log('LayerManager initialized');
    }

    /**
     * Setup map event handlers for layer management
     */
    function setupMapEventHandlers() {
        // Remove tooltips when clicking on empty map areas
        map.on('click', function(e) {
            removeTooltip();
        });

        // Zoom-based layer switching with debouncing
        let zoomSwitchTimeout;
        map.on('zoomend', function() {
            clearTimeout(zoomSwitchTimeout);
            zoomSwitchTimeout = setTimeout(switchEUSeaMapLayerByZoom, 300);
        });

        console.log('Map event handlers initialized');
    }

    // ========================================
    // FACTSHEET DATA LOADING
    // ========================================

    /**
     * Load all factsheet data from API
     */
    async function loadFactsheets() {
        if (factsheetsLoaded) {
            return; // Already loaded
        }

        try {
            const response = await fetch(`${window.AppConfig.API_BASE_URL}/factsheets`);
            if (!response.ok) {
                console.warn('Factsheets not available:', response.status);
                return;
            }

            const data = await response.json();

            // Cache factsheets by normalized name for easy lookup
            if (data.bbts && Array.isArray(data.bbts)) {
                data.bbts.forEach(bbt => {
                    // Store by original name and normalized variants
                    const normalizedName = bbt.name.toLowerCase().replace(/[_\s-]+/g, ' ').trim();
                    factsheetCache.set(normalizedName, bbt);
                    factsheetCache.set(bbt.name, bbt); // Also store by exact name
                });

                factsheetsLoaded = true;
                console.log(`✅ Loaded ${data.bbts.length} factsheets`);
            }
        } catch (error) {
            console.warn('Error loading factsheets:', error);
        }
    }

    /**
     * Get factsheet data for a BBT by name
     * @param {string} bbtName - Name of the BBT
     * @returns {Object|null} Factsheet data or null
     */
    function getFactsheetData(bbtName) {
        if (!bbtName) return null;

        // Try exact match first
        if (factsheetCache.has(bbtName)) {
            return factsheetCache.get(bbtName);
        }

        // Try normalized match
        const normalizedName = bbtName.toLowerCase().replace(/[_\s-]+/g, ' ').trim();
        if (factsheetCache.has(normalizedName)) {
            return factsheetCache.get(normalizedName);
        }

        // Try partial match
        for (const [key, value] of factsheetCache.entries()) {
            if (key.includes(normalizedName) || normalizedName.includes(key)) {
                return value;
            }
        }

        return null;
    }

    // ========================================
    // TOOLTIP FUNCTIONS
    // ========================================

    /**
     * Calculate area of a feature in square kilometers
     * @param {Object} feature - GeoJSON feature
     * @returns {string|null} Area in km² or null if calculation fails
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

    /**
     * Create hover tooltip at specified position
     * @param {string} content - HTML content for tooltip
     * @param {number} x - X coordinate (pixels)
     * @param {number} y - Y coordinate (pixels)
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
     * Remove hover tooltip
     */
    function removeTooltip() {
        if (hoverTooltip) {
            document.body.removeChild(hoverTooltip);
            hoverTooltip = null;
        }
    }

    /**
     * Update tooltip position
     * @param {number} x - X coordinate (pixels)
     * @param {number} y - Y coordinate (pixels)
     */
    function updateTooltip(x, y) {
        if (hoverTooltip) {
            hoverTooltip.style.left = x + 'px';
            hoverTooltip.style.top = (y - 10) + 'px';
        }
    }

    /**
     * Generate enhanced tooltip content for BBT features with MARBEFES context
     * @param {Object} feature - GeoJSON feature
     * @param {string} layerName - Layer name
     * @returns {string} HTML content for tooltip
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

            // Note: Factsheet data is available in the BBT Data popup (📊 button)
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

    // ========================================
    // ZOOM & EXTENT FUNCTIONS
    // ========================================

    /**
     * Helper function to convert scale denominator to approximate zoom level
     * @param {number} scale - Scale denominator
     * @returns {number} Zoom level (0-18)
     */
    function scaleToZoom(scale) {
        // Approximate conversion: scale = 591659030.4 / (2^zoom)
        // This is based on Web Mercator projection at equator
        const baseScale = 591659030.4;
        const zoom = Math.log2(baseScale / scale);
        return Math.max(0, Math.min(18, Math.round(zoom)));
    }

    /**
     * Helper function to calculate optimal zoom considering bounds and scale constraints
     * @param {Array} bounds - Leaflet bounds array
     * @param {number} minScale - Minimum scale denominator
     * @param {number} maxScale - Maximum scale denominator
     * @returns {number|null} Optimal zoom level or null
     */
    function calculateOptimalZoom(bounds, minScale, maxScale) {
        if (!minScale && !maxScale) return null;

        // Calculate what zoom level would fit the bounds
        const boundsZoom = map.getBoundsZoom(bounds);

        let optimalZoom = boundsZoom;

        // Constrain zoom based on scale denominators
        if (minScale) {
            const maxZoom = scaleToZoom(minScale);
            optimalZoom = Math.min(optimalZoom, maxZoom);
        }

        if (maxScale) {
            const minZoom = scaleToZoom(maxScale);
            optimalZoom = Math.max(optimalZoom, minZoom);
        }

        return Math.max(0, Math.min(18, optimalZoom));
    }

    /**
     * Zoom to layer extent with scale awareness
     * @param {string} layerName - WMS layer name
     */
    function zoomToLayerExtent(layerName) {
        const config = window.AppConfig;
        if (!config) {
            console.error('AppConfig not available');
            return;
        }

        // Get layer bounds from WMS GetCapabilities
        const capabilitiesUrl = `${config.WMS_BASE_URL}?service=WMS&version=1.3.0&request=GetCapabilities`;

        fetch(capabilitiesUrl)
            .then(response => response.text())
            .then(data => {
                // Parse XML
                const parser = new DOMParser();
                const xmlDoc = parser.parseFromString(data, "text/xml");

                // Find the layer
                const layers = xmlDoc.getElementsByTagName('Layer');
                for (let i = 0; i < layers.length; i++) {
                    const nameElement = layers[i].getElementsByTagName('Name')[0];
                    if (nameElement && nameElement.textContent === layerName) {

                        // Extract scale denominators for the layer
                        let minScale = null;
                        let maxScale = null;

                        const minScaleElement = layers[i].getElementsByTagName('MinScaleDenominator')[0];
                        const maxScaleElement = layers[i].getElementsByTagName('MaxScaleDenominator')[0];

                        if (minScaleElement) {
                            minScale = parseFloat(minScaleElement.textContent);
                        }
                        if (maxScaleElement) {
                            maxScale = parseFloat(maxScaleElement.textContent);
                        }

                        // Look for BoundingBox or EX_GeographicBoundingBox
                        let boundingBox = layers[i].getElementsByTagName('EX_GeographicBoundingBox')[0];
                        if (!boundingBox) {
                            boundingBox = layers[i].getElementsByTagName('LatLonBoundingBox')[0];
                        }

                        if (boundingBox) {
                            let west, south, east, north;

                            // Try EX_GeographicBoundingBox format (WMS 1.3.0)
                            const westBound = boundingBox.getElementsByTagName('westBoundLongitude')[0];
                            const southBound = boundingBox.getElementsByTagName('southBoundLatitude')[0];
                            const eastBound = boundingBox.getElementsByTagName('eastBoundLongitude')[0];
                            const northBound = boundingBox.getElementsByTagName('northBoundLatitude')[0];

                            if (westBound && southBound && eastBound && northBound) {
                                west = parseFloat(westBound.textContent);
                                south = parseFloat(southBound.textContent);
                                east = parseFloat(eastBound.textContent);
                                north = parseFloat(northBound.textContent);
                            } else {
                                // Try LatLonBoundingBox format (WMS 1.1.1)
                                west = parseFloat(boundingBox.getAttribute('minx'));
                                south = parseFloat(boundingBox.getAttribute('miny'));
                                east = parseFloat(boundingBox.getAttribute('maxx'));
                                north = parseFloat(boundingBox.getAttribute('maxy'));
                            }

                            if (!isNaN(west) && !isNaN(south) && !isNaN(east) && !isNaN(north)) {
                                // Calculate appropriate zoom level based on scale constraints
                                const bounds = [[south, west], [north, east]];

                                // Calculate zoom level that respects scale constraints
                                let targetZoom = calculateOptimalZoom(bounds, minScale, maxScale);

                                if (targetZoom) {
                                    // Use calculated zoom level
                                    const center = [(south + north) / 2, (west + east) / 2];
                                    map.setView(center, targetZoom);
                                } else {
                                    // Fallback to fitBounds with constraints
                                    const fitOptions = { padding: [20, 20] };

                                    // Apply zoom constraints if available
                                    if (minScale || maxScale) {
                                        if (minScale) fitOptions.maxZoom = scaleToZoom(minScale);
                                        if (maxScale) fitOptions.minZoom = scaleToZoom(maxScale);
                                    }

                                    map.fitBounds(bounds, fitOptions);
                                }
                                return;
                            }
                        }
                        break;
                    }
                }

                // Fallback to European waters if no bounds found
                map.setView([54.0, 10.0], 4);
            })
            .catch(error => {
                console.log('Could not get layer extent:', error);
                // Fallback to European waters
                map.setView([54.0, 10.0], 4);
            });
    }

    // ========================================
    // GETFEATUREINFO FUNCTIONS
    // ========================================

    /**
     * Set up GetFeatureInfo for layer tooltips
     * @param {string} layerName - Layer name
     */
    function setupGetFeatureInfo(layerName) {
        // Remove any existing click handlers
        map.off('click', handleMapClick);

        // Add new click handler for the current layer
        map.on('click', function(e) {
            handleMapClick(e, layerName);
        });
    }

    /**
     * Handle map clicks and fetch feature info
     * @param {Object} e - Leaflet event object
     * @param {string} layerName - Layer name
     */
    function handleMapClick(e, layerName) {
        const latlng = e.latlng;
        const zoom = map.getZoom();
        const bounds = map.getBounds();
        const size = map.getSize();

        // Convert click coordinates to pixel coordinates
        const point = map.latLngToContainerPoint(latlng);

        // Build GetFeatureInfo URL
        const getFeatureInfoUrl = buildGetFeatureInfoUrl(
            layerName,
            bounds,
            size.x,
            size.y,
            Math.round(point.x),
            Math.round(point.y)
        );

        // Show loading indicator
        updateStatus('Getting feature info...', 'loading');

        // Make GetFeatureInfo request
        fetch(getFeatureInfoUrl)
            .then(response => response.text())
            .then(data => {
                // Reset status
                checkLayerVisibility(layerName);

                // Parse and display feature info
                displayFeatureInfo(data, latlng);
            })
            .catch(error => {
                console.log('GetFeatureInfo error:', error);
                // Reset status
                checkLayerVisibility(layerName);

                // Show error popup
                L.popup()
                    .setLatLng(latlng)
                    .setContent('<div style="padding: 10px;"><strong>No information available</strong><br/>Click elsewhere to try again.</div>')
                    .openOn(map);
            });
    }

    /**
     * Build GetFeatureInfo URL
     * @param {string} layerName - Layer name
     * @param {Object} bounds - Map bounds
     * @param {number} width - Map width in pixels
     * @param {number} height - Map height in pixels
     * @param {number} x - Click X coordinate
     * @param {number} y - Click Y coordinate
     * @returns {string} GetFeatureInfo URL
     */
    function buildGetFeatureInfoUrl(layerName, bounds, width, height, x, y) {
        const config = window.AppConfig;
        const sw = bounds.getSouthWest();
        const ne = bounds.getNorthEast();

        const params = new URLSearchParams({
            'service': 'WMS',
            'version': '1.1.0',
            'request': 'GetFeatureInfo',
            'layers': layerName,
            'query_layers': layerName,
            'styles': '',
            'bbox': `${sw.lng},${sw.lat},${ne.lng},${ne.lat}`,
            'width': width,
            'height': height,
            'format': 'image/png',
            'info_format': 'text/html',
            'srs': 'EPSG:4326',
            'x': x,
            'y': y
        });

        return `${config.WMS_BASE_URL}?${params.toString()}`;
    }

    /**
     * Display feature information in a popup
     * @param {string} htmlContent - HTML content from GetFeatureInfo
     * @param {Object} latlng - Leaflet LatLng object
     */
    function displayFeatureInfo(htmlContent, latlng) {
        // Clean up the HTML content
        let content = htmlContent;

        // Check if we got meaningful content
        if (!content || content.trim() === '' ||
            content.includes('no features') ||
            content.includes('No data')) {
            content = '<div style="padding: 10px;"><strong>No information available</strong><br/>This area has no data for the selected layer.</div>';
        } else {
            // Wrap content in a styled container
            content = `<div style="padding: 10px; max-width: 300px; max-height: 400px; overflow-y: auto;">${content}</div>`;
        }

        // Create and show popup
        L.popup({
            maxWidth: 350,
            maxHeight: 450,
            autoPan: true,
            closeButton: true,
            autoClose: false,
            closeOnEscapeKey: true
        })
        .setLatLng(latlng)
        .setContent(content)
        .openOn(map);
    }

    // ========================================
    // WMS LAYER MANAGEMENT
    // ========================================

    /**
     * Update WMS layer
     * @param {string} layerName - Layer name
     * @param {number} opacity - Layer opacity (0-1)
     */
    function updateWMSLayer(layerName, opacity) {
        const config = window.AppConfig;

        updateStatus('Loading layer...', 'loading');

        // Remove existing WMS layer if present
        if (wmsLayer) {
            map.removeLayer(wmsLayer);
        }

        // Add new WMS layer
        wmsLayer = L.tileLayer.wms(config.WMS_BASE_URL, {
            layers: layerName,
            format: 'image/png',
            transparent: true,
            version: '1.1.0',
            opacity: opacity,
            attribution: 'MARBEFES BBT Database | EMODnet Seabed Habitats',
            tiled: true
        });

        wmsLayer.addTo(map);

        // Set up click events for GetFeatureInfo
        setupGetFeatureInfo(layerName);

        // Update legend
        updateLegend(layerName);

        // Zoom to layer extent (this will handle scale-appropriate zoom)
        zoomToLayerExtent(layerName);

        // Set up zoom level monitoring for layer visibility
        map.on('zoomend', function() {
            checkLayerVisibility(layerName);
        });

        // Update status
        setTimeout(() => {
            checkLayerVisibility(layerName);
        }, 1000);
    }

    /**
     * Check if layer is visible at current zoom level
     * @param {string} layerName - Layer name
     */
    function checkLayerVisibility(layerName) {
        const config = window.AppConfig;
        const capabilitiesUrl = `${config.WMS_BASE_URL}?service=WMS&version=1.3.0&request=GetCapabilities`;

        fetch(capabilitiesUrl)
            .then(response => response.text())
            .then(data => {
                const parser = new DOMParser();
                const xmlDoc = parser.parseFromString(data, "text/xml");
                const layers = xmlDoc.getElementsByTagName('Layer');

                for (let i = 0; i < layers.length; i++) {
                    const nameElement = layers[i].getElementsByTagName('Name')[0];
                    if (nameElement && nameElement.textContent === layerName) {
                        const minScaleElement = layers[i].getElementsByTagName('MinScaleDenominator')[0];
                        const maxScaleElement = layers[i].getElementsByTagName('MaxScaleDenominator')[0];

                        let minScale = minScaleElement ? parseFloat(minScaleElement.textContent) : null;
                        let maxScale = maxScaleElement ? parseFloat(maxScaleElement.textContent) : null;

                        if (minScale || maxScale) {
                            const currentZoom = map.getZoom();
                            const currentScale = 591659030.4 / Math.pow(2, currentZoom);

                            let statusMsg = 'Layer loaded';
                            let statusClass = 'status';

                            if (minScale && currentScale < minScale) {
                                statusMsg = 'Zoom out to see this layer';
                                statusClass = 'status error';
                            } else if (maxScale && currentScale > maxScale) {
                                statusMsg = 'Zoom in to see this layer';
                                statusClass = 'status error';
                            }

                            updateStatus(statusMsg, statusClass.replace('status ', ''));
                        } else {
                            updateStatus('Layer loaded', '');
                        }
                        break;
                    }
                }
            })
            .catch(error => {
                updateStatus('Layer loaded', '');
            });
    }

    /**
     * Update legend
     * @param {string} layerName - Layer name
     */
    function updateLegend(layerName) {
        const config = window.AppConfig;
        const legendUrl = `${config.WMS_BASE_URL}?service=WMS&version=1.1.0&request=GetLegendGraphic&layer=${layerName}&format=image/png`;
        const legendImg = document.getElementById('legend-image');
        const legendContainer = document.getElementById('legend-container');

        if (!legendImg || !legendContainer) return;

        // Reset src to avoid cached errors
        legendImg.src = '';

        legendImg.onload = () => {
            legendContainer.style.display = 'block';
        };
        legendImg.onerror = () => {
            // Silently hide legend if not available (common for some WMS layers)
            legendContainer.style.display = 'none';
            console.debug(`Legend not available for layer: ${layerName}`);
        };

        // Set src after handlers are attached
        legendImg.src = legendUrl;
    }

    /**
     * Select WMS layer as overlay (new behavior for dropdown)
     * @param {string} layerName - Layer name
     */
    function selectWMSLayerAsOverlay(layerName) {
        const config = window.AppConfig;

        console.log(`🔄 [LAYER-MGR] Loading WMS overlay: ${layerName}`);
        console.log(`   - WMS Base URL: ${config.WMS_BASE_URL}`);
        console.log(`   - Current map zoom: ${map.getZoom()}`);
        console.log(`   - Current map center:`, map.getCenter());
        console.log(`   - Map instance exists:`, !!map);

        currentLayer = layerName;
        currentLayerType = 'wms-overlay';

        // Show loading indicator
        console.log('🎬 [LAYER-MGR] Calling showLoadingTimer...');
        updateStatus(`Loading ${layerName}...`, 'loading');
        showLoadingTimer(layerName);
        console.log('✅ [LAYER-MGR] showLoadingTimer called');

        // Clear existing WMS layer from map and layer control
        if (wmsLayer) {
            console.log('🗑️ Removing existing WMS layer');
            map.removeLayer(wmsLayer);
            if (window.MapInit && window.MapInit.removeOverlayFromControl) {
                window.MapInit.removeOverlayFromControl(wmsLayer);
            }
        }

        // Create a custom pane for WMS layers if it doesn't exist
        if (!map.getPane('wmsPane')) {
            const wmsPane = map.createPane('wmsPane');
            wmsPane.style.zIndex = 400; // Above basemap (200) but below overlays (400) and vector (600)
            console.log('📐 Created wmsPane with z-index 400');
        }

        // Add WMS layer as overlay
        wmsLayer = L.tileLayer.wms(config.WMS_BASE_URL, {
            layers: layerName,
            format: 'image/png',
            transparent: true,
            version: '1.1.0',
            opacity: currentOpacity,
            pane: 'wmsPane',  // Use dedicated WMS pane
            attribution: 'EMODnet Seabed Habitats'
        });

        console.log('📦 WMS layer will render in wmsPane (z-index: 400)');

        console.log('📦 WMS Layer created with config:', {
            layers: layerName,
            format: 'image/png',
            transparent: true,
            version: '1.1.0',
            opacity: currentOpacity,
            zIndex: 500
        });

        // Track tile loading - simplified approach
        let tilesLoading = 0;
        let tilesLoaded = 0;
        let firstTileLoaded = false;
        let hasErrors = false;

        // Set up tile event listeners
        wmsLayer.on('tileloadstart', function() {
            tilesLoading++;
            console.log('⏳ Tile load started (total requested:', tilesLoading, ')');
        });

        wmsLayer.on('tileload', function() {
            tilesLoaded++;
            console.log('✅ Tile loaded successfully (', tilesLoaded, '/', tilesLoading, ')');

            if (!firstTileLoaded) {
                firstTileLoaded = true;
                console.log('🎨 First tile visible!');
            }

            // Hide timer when enough tiles loaded (80% or after 3 seconds)
            if (tilesLoaded >= Math.ceil(tilesLoading * 0.8) && tilesLoading > 0) {
                setTimeout(() => {
                    console.log('🎉 Most tiles loaded, hiding timer');
                    hideLoadingTimer();
                    updateStatus(`Layer loaded: ${layerName}`, '');
                }, 500);
            }
        });

        wmsLayer.on('tileerror', function(error) {
            hasErrors = true;
            tilesLoaded++;
            console.error('❌ Tile error:', error);

            // Don't immediately hide on single error
            if (tilesLoaded >= tilesLoading) {
                hideLoadingTimer();
                updateStatus(`Layer loaded with some errors`, 'error');
            }
        });

        // Safety timeout: hide timer after 10 seconds regardless
        const safetyTimeout = setTimeout(() => {
            console.log('⏰ Safety timeout reached, hiding timer');
            hideLoadingTimer();
            if (tilesLoaded > 0) {
                updateStatus(`Layer loaded: ${layerName}`, '');
            } else {
                updateStatus(`Layer load may be slow or incomplete`, 'error');
            }
        }, 10000);

        wmsLayer.addTo(map);
        console.log('✅ WMS layer added to map, hasLayer:', map.hasLayer(wmsLayer));

        // Force map to redraw by invalidating size
        setTimeout(() => {
            map.invalidateSize();
            console.log('🔄 Map invalidated to force redraw');
        }, 100);

        // Log a sample tile URL for debugging
        const bounds = map.getBounds();
        const size = map.getSize();
        const sw = bounds.getSouthWest();
        const ne = bounds.getNorthEast();
        const sampleUrl = `${config.WMS_BASE_URL}?service=WMS&version=1.1.0&request=GetMap&layers=${layerName}&bbox=${sw.lng},${sw.lat},${ne.lng},${ne.lat}&width=${size.x}&height=${size.y}&format=image/png&transparent=true&srs=EPSG:4326`;
        console.log('🔗 Sample WMS tile URL (first 150 chars):', sampleUrl.substring(0, 150) + '...');
        console.log('📋 Full tile URL for browser testing:', sampleUrl);

        // Add to native layer control
        if (window.MapInit && window.MapInit.addOverlayToControl) {
            // Get friendly layer name from window.wmsLayers if available
            let friendlyName = layerName;
            if (window.wmsLayers) {
                const layerInfo = window.wmsLayers.find(l => l.name === layerName);
                if (layerInfo && layerInfo.title) {
                    friendlyName = layerInfo.title;
                }
            }
            window.MapInit.addOverlayToControl(wmsLayer, `🌊 EMODnet: ${friendlyName}`);
        }

        // Update legend
        updateLegend(layerName);
    }

    /**
     * Get optimal EUSeaMap layer based on zoom level
     * @param {number} zoom - Zoom level
     * @returns {Array} Array of layer names (priority order)
     */
    function getOptimalEUSeaMapLayer(zoom) {
        // Return best EUNIS 2019 layer name based on zoom level
        // Uses 800m simplification for regional overview (zoom < 12)
        // Uses full resolution for BBT coverage and detailed views (zoom >= 12)
        if (zoom < 12) {
            return ['eusm_2023_eunis2019_800', 'eusm_2023_eunis2019_full'];
        } else {
            return ['eusm_2023_eunis2019_full'];
        }
    }

    /**
     * Switch EUSeaMap layer based on zoom level
     */
    function switchEUSeaMapLayerByZoom() {
        if (!autoSwitchEnabled) return;
        if (!wmsLayer || !map.hasLayer(wmsLayer)) return;

        const currentZoom = map.getZoom();
        const zoomThreshold = 1; // Only switch if zoom changes by more than this

        if (Math.abs(currentZoom - lastAutoSwitchedZoom) < zoomThreshold) {
            return; // Don't switch for minor zoom changes
        }

        // Check if current layer is a EUNIS 2019 layer (auto-switch only for these)
        const currentLayerName = wmsLayer.options.layers;
        const isEunis2019Layer = currentLayerName && currentLayerName.includes('eusm_2023_eunis2019');

        if (!isEunis2019Layer) {
            return; // Don't auto-switch if user selected a different layer type
        }

        const optimalLayers = getOptimalEUSeaMapLayer(currentZoom);

        // Check if current layer is still optimal
        if (optimalLayers.includes(currentLayerName)) {
            return; // Current layer is fine
        }

        // Switch to optimal layer
        console.log(`🔄 Zoom changed to ${currentZoom}, switching EUSeaMap EUNIS 2019 layer...`);
        const newLayer = optimalLayers[0]; // Try first option

        selectWMSLayerAsOverlay(newLayer);

        // Update dropdown
        const layerSelect = document.getElementById('layer-select');
        if (layerSelect) {
            layerSelect.value = 'wms:' + newLayer;
        }

        // Update status tooltip
        const statusTooltip = document.getElementById('emodnet-status-tooltip');
        if (statusTooltip) {
            const simplificationLevel = currentZoom < 6 ? '800m (overview)' : 'full detail';
            statusTooltip.textContent = `EUNIS 2019 - ${simplificationLevel}`;
            statusTooltip.style.color = '#20B2AA';
        }

        lastAutoSwitchedZoom = currentZoom;
        console.log(`✅ Switched to ${newLayer} for zoom level ${currentZoom}`);
    }

    // ========================================
    // HUMAN ACTIVITIES LAYER MANAGEMENT
    // ========================================

    /**
     * Select Human Activities layer as overlay
     * @param {string} layerName - Layer name
     */
    function selectHumanActivitiesLayerAsOverlay(layerName) {
        const config = window.AppConfig;

        console.log(`🔄 [LAYER-MGR] Loading Human Activities overlay: ${layerName}`);
        console.log(`   - Human Activities WMS URL: ${config.HUMAN_ACTIVITIES_WMS_BASE_URL}`);

        currentLayer = layerName;
        currentLayerType = 'human_activities-overlay';

        // Show loading indicator
        updateStatus(`Loading ${layerName}...`, 'loading');

        // Clear existing Human Activities layer from map and layer control
        if (helcomLayer) {
            console.log('🗑️ Removing existing Human Activities layer');
            map.removeLayer(helcomLayer);
            if (window.MapInit && window.MapInit.removeOverlayFromControl) {
                window.MapInit.removeOverlayFromControl(helcomLayer);
            }
        }

        // Create a custom pane for Human Activities layers if it doesn't exist
        if (!map.getPane('humanActivitiesPane')) {
            const haPane = map.createPane('humanActivitiesPane');
            haPane.style.zIndex = 500; // Above WMS (400) but below vectors (600)
            console.log('📐 Created humanActivitiesPane with z-index 500');
        }

        // Add Human Activities layer as overlay
        helcomLayer = L.tileLayer.wms(config.HUMAN_ACTIVITIES_WMS_BASE_URL, {
            layers: layerName,
            format: 'image/png',
            transparent: true,
            version: '1.1.0',
            opacity: currentOpacity,
            pane: 'humanActivitiesPane',
            attribution: 'EMODnet Human Activities'
            // Note: crossOrigin removed - WMS tiles don't require CORS for display
        });

        console.log('📦 Human Activities layer created with config:', {
            layers: layerName,
            version: '1.1.0',
            opacity: currentOpacity,
            pane: 'humanActivitiesPane'
        });

        // Track tile loading
        let tilesLoading = 0;
        let tilesLoaded = 0;
        let hasErrors = false;

        helcomLayer.on('tileloadstart', function() {
            tilesLoading++;
            console.log('⏳ HA tile load started (total:', tilesLoading, ')');
        });

        helcomLayer.on('tileload', function() {
            tilesLoaded++;
            console.log('✅ HA tile loaded (', tilesLoaded, '/', tilesLoading, ')');
        });

        helcomLayer.on('tileerror', function(error) {
            hasErrors = true;
            tilesLoaded++;
            console.error('❌ HA tile error:', error);
            console.error('   Tile URL:', error.tile?.src || 'unknown');
            console.error('   Error type:', error.error || error.type || 'unknown');
        });

        helcomLayer.addTo(map);
        console.log('✅ Human Activities layer added to map');

        // Log sample tile URL for debugging
        const bounds = map.getBounds();
        const size = map.getSize();
        const sw = bounds.getSouthWest();
        const ne = bounds.getNorthEast();
        const sampleUrl = `${config.HUMAN_ACTIVITIES_WMS_BASE_URL}?service=WMS&version=1.1.0&request=GetMap&layers=${layerName}&bbox=${sw.lng},${sw.lat},${ne.lng},${ne.lat}&width=${size.x}&height=${size.y}&format=image/png&transparent=true&srs=EPSG:4326`;
        console.log('🔗 Sample HA tile URL:', sampleUrl.substring(0, 150) + '...');

        // Add to native layer control
        if (window.MapInit && window.MapInit.addOverlayToControl) {
            // Get friendly layer name from window.humanActivitiesLayers if available
            let friendlyName = layerName;
            if (window.humanActivitiesLayers) {
                const layerInfo = window.humanActivitiesLayers.find(l => l.name === layerName);
                if (layerInfo && layerInfo.title) {
                    friendlyName = layerInfo.title;
                }
            }
            window.MapInit.addOverlayToControl(helcomLayer, `🚢 Human Activities: ${friendlyName}`);
        }

        // Clear legend since Human Activities might not have standard legends
        const legendContainer = document.getElementById('legend-container');
        if (legendContainer) {
            legendContainer.style.display = 'none';
        }

        // Zoom to layer extent to ensure visibility
        zoomToHumanActivitiesLayerExtent(layerName);

        // Update status after zoom completes
        setTimeout(() => {
            updateStatus(`Layer loaded: ${layerName}`, '');
        }, 1500);
    }

    /**
     * Zoom to Human Activities layer extent
     * @param {string} layerName - Layer name
     */
    function zoomToHumanActivitiesLayerExtent(layerName) {
        const config = window.AppConfig;
        if (!config.HUMAN_ACTIVITIES_WMS_BASE_URL) {
            console.error('HUMAN_ACTIVITIES_WMS_BASE_URL not configured');
            return;
        }

        const capabilitiesUrl = `${config.HUMAN_ACTIVITIES_WMS_BASE_URL}?service=WMS&version=1.3.0&request=GetCapabilities`;

        fetch(capabilitiesUrl)
            .then(response => response.text())
            .then(data => {
                const parser = new DOMParser();
                const xmlDoc = parser.parseFromString(data, "text/xml");
                const layers = xmlDoc.getElementsByTagName('Layer');

                for (let i = 0; i < layers.length; i++) {
                    const nameElement = layers[i].getElementsByTagName('Name')[0];
                    if (nameElement && nameElement.textContent === layerName) {
                        // Look for EX_GeographicBoundingBox
                        const boundingBox = layers[i].getElementsByTagName('EX_GeographicBoundingBox')[0];

                        if (boundingBox) {
                            const westBound = boundingBox.getElementsByTagName('westBoundLongitude')[0];
                            const southBound = boundingBox.getElementsByTagName('southBoundLatitude')[0];
                            const eastBound = boundingBox.getElementsByTagName('eastBoundLongitude')[0];
                            const northBound = boundingBox.getElementsByTagName('northBoundLatitude')[0];

                            if (westBound && southBound && eastBound && northBound) {
                                const west = parseFloat(westBound.textContent);
                                const south = parseFloat(southBound.textContent);
                                const east = parseFloat(eastBound.textContent);
                                const north = parseFloat(northBound.textContent);

                                if (!isNaN(west) && !isNaN(south) && !isNaN(east) && !isNaN(north)) {
                                    console.log(`📍 Layer extent: [${west}, ${south}, ${east}, ${north}]`);

                                    // Check if bounds are global (very large) - don't zoom if so
                                    const isGlobal = (east - west > 350) || (north - south > 170);

                                    if (isGlobal) {
                                        console.log('🌍 Layer has global extent, keeping current view');
                                        // Just zoom to European waters for global layers
                                        map.setView([54.0, 10.0], 4);
                                    } else {
                                        // Zoom to actual layer bounds
                                        const bounds = [[south, west], [north, east]];
                                        map.fitBounds(bounds, { padding: [20, 20] });
                                        console.log('🎯 Zoomed to layer extent');
                                    }
                                    return;
                                }
                            }
                        }
                        break;
                    }
                }

                // Fallback to European waters if no bounds found
                console.log('⚠️ No extent found, defaulting to European waters');
                map.setView([54.0, 10.0], 4);
            })
            .catch(error => {
                console.log('Could not get Human Activities layer extent:', error);
                // Fallback to European waters
                map.setView([54.0, 10.0], 4);
            });
    }

    // ========================================
    // FINFISH WFS LAYER MANAGEMENT
    // ========================================

    let finfishWfsLayer = null;

    /**
     * Select Finfish WFS layer as overlay
     * @param {string} layerName - Layer name
     */
    function selectFinfishWFSLayerAsOverlay(layerName) {
        const config = window.AppConfig;

        console.log(`🔄 [LAYER-MGR] Loading Finfish WFS overlay: ${layerName}`);
        console.log(`   - Finfish WFS URL: ${config.FINFISH_WFS_BASE_URL}`);

        currentLayer = layerName;
        currentLayerType = 'finfish_wfs-overlay';

        // Show loading indicator
        updateStatus(`Loading ${layerName}...`, 'loading');

        // Clear existing Finfish WFS layer from map
        if (finfishWfsLayer) {
            console.log('🗑️ Removing existing Finfish WFS layer');
            map.removeLayer(finfishWfsLayer);
            if (window.MapInit && window.MapInit.removeOverlayFromControl) {
                window.MapInit.removeOverlayFromControl(finfishWfsLayer);
            }
        }

        // Create a custom pane for Finfish WFS layers if it doesn't exist
        if (!map.getPane('finfishWfsPane')) {
            const fwPane = map.createPane('finfishWfsPane');
            fwPane.style.zIndex = 550; // Above Human Activities (500) but below vectors (600)
            console.log('📐 Created finfishWfsPane with z-index 550');
        }

        // Fetch WFS features as GeoJSON
        const bounds = map.getBounds();
        const sw = bounds.getSouthWest();
        const ne = bounds.getNorthEast();

        // Build WFS GetFeature URL
        const wfsParams = new URLSearchParams({
            'service': 'WFS',
            'version': '2.0.0',
            'request': 'GetFeature',
            'typeName': layerName,
            'outputFormat': 'application/json',
            'srsName': 'EPSG:4326',
            'bbox': `${sw.lat},${sw.lng},${ne.lat},${ne.lng},EPSG:4326`
        });

        const wfsUrl = `${config.FINFISH_WFS_BASE_URL}?${wfsParams.toString()}`;
        console.log('🔗 WFS GetFeature URL:', wfsUrl.substring(0, 150) + '...');

        // Fetch and render GeoJSON
        fetch(wfsUrl)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }
                return response.json();
            })
            .then(geojson => {
                console.log('📊 Received WFS features:', geojson.features?.length || 0);

                // Create GeoJSON layer with point styling
                finfishWfsLayer = L.geoJSON(geojson, {
                    pane: 'finfishWfsPane',
                    pointToLayer: function(feature, latlng) {
                        // Style points as circle markers
                        return L.circleMarker(latlng, {
                            radius: 6,
                            fillColor: '#FF6B6B',
                            color: '#fff',
                            weight: 2,
                            opacity: 1,
                            fillOpacity: currentOpacity,
                            pane: 'finfishWfsPane'
                        });
                    },
                    style: function(feature) {
                        // Style polygons/lines if present
                        return {
                            fillColor: '#FF6B6B',
                            color: '#fff',
                            weight: 2,
                            opacity: 1,
                            fillOpacity: currentOpacity * 0.7,
                            pane: 'finfishWfsPane'
                        };
                    },
                    onEachFeature: function(feature, layer) {
                        // Create popup content from feature properties
                        if (feature.properties) {
                            let popupContent = '<div style="max-width: 300px;">';
                            popupContent += '<div style="font-weight: 600; color: #FF6B6B; margin-bottom: 8px;">🐟 Finfish Data</div>';

                            // Display all properties
                            Object.keys(feature.properties).forEach(key => {
                                const value = feature.properties[key];
                                if (value !== null && value !== undefined && value !== '') {
                                    popupContent += `<div style="margin: 4px 0;"><strong>${key}:</strong> ${value}</div>`;
                                }
                            });

                            popupContent += '</div>';
                            layer.bindPopup(popupContent);
                        }

                        // Hover effects
                        layer.on({
                            mouseover: function(e) {
                                if (e.target.setStyle) {
                                    e.target.setStyle({
                                        fillOpacity: currentOpacity + 0.2,
                                        weight: 3
                                    });
                                }
                            },
                            mouseout: function(e) {
                                if (e.target.setStyle) {
                                    e.target.setStyle({
                                        fillOpacity: currentOpacity,
                                        weight: 2
                                    });
                                }
                            }
                        });
                    }
                });

                finfishWfsLayer.addTo(map);
                console.log('✅ Finfish WFS layer added to map');

                // Add to native layer control
                if (window.MapInit && window.MapInit.addOverlayToControl) {
                    // Get friendly layer name
                    let friendlyName = layerName;
                    if (window.finfishWfsLayers) {
                        const layerInfo = window.finfishWfsLayers.find(l => l.name === layerName);
                        if (layerInfo && layerInfo.title) {
                            friendlyName = layerInfo.title;
                        }
                    }
                    window.MapInit.addOverlayToControl(finfishWfsLayer, `🐟 Finfish: ${friendlyName}`);
                }

                // Update status
                const featureCount = geojson.features?.length || 0;
                updateStatus(`Loaded ${featureCount} finfish features`, '');

                // Clear legend (WFS layers typically don't have legends)
                const legendContainer = document.getElementById('legend-container');
                if (legendContainer) {
                    legendContainer.style.display = 'none';
                }
            })
            .catch(error => {
                console.error('❌ Finfish WFS error:', error);
                updateStatus(`Error loading finfish layer: ${error.message}`, 'error');
            });
    }

    // ========================================
    // VECTOR LAYER MANAGEMENT
    // ========================================

    /**
     * Load and display vector layer (async optimized)
     * @param {string} layerName - Layer name
     */
    async function loadVectorLayer(layerName) {
        const config = window.AppConfig;

        try {
            updateStatus('Loading vector layer...', 'loading');

            // Determine simplification based on zoom level
            // For zoom < 12 (all BBTs view): use 800m simplification (0.007 degrees ≈ 800m)
            // For zoom >= 12 (individual BBT): no simplification
            const currentZoom = map.getZoom();
            const simplifyParam = currentZoom < 12 ? '?simplify=0.007' : '';

            console.log(`Loading vector layer with zoom=${currentZoom}, simplification=${simplifyParam ? '800m' : 'none'}`);

            // Fetch GeoJSON for the layer with timeout
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 15000);

            const response = await fetch(`${config.API_BASE_URL}/vector/layer/${encodeURIComponent(layerName)}${simplifyParam}`, {
                signal: controller.signal
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const geojson = await response.json();

            // Process the vector layer data
            await processVectorLayerData(geojson, layerName);

        } catch (error) {
            console.error('Error loading vector layer:', error);
            if (error.name === 'AbortError') {
                updateStatus('Vector layer loading timed out', 'error');
            } else {
                updateStatus('Error loading vector layer', 'error');
            }
        }
    }

    /**
     * Enhanced layer loading with instant cache access (simplification-aware)
     * @param {string} layerName - Layer name
     */
    async function loadVectorLayerFast(layerName) {
        console.log('DEBUG LayerManager: loadVectorLayerFast called with layerName =', layerName);
        try {
            // Determine current simplification state based on zoom
            const currentZoom = map.getZoom();
            console.log('DEBUG LayerManager: currentZoom =', currentZoom);
            const isSimplified = currentZoom < 12;
            const cacheKey = `${layerName}:${isSimplified ? 'simplified' : 'full'}`;

            // Check cache first for instant loading (with simplification awareness)
            if (layerCache.has(cacheKey)) {
                console.log(`✅ Loading ${layerName} from cache (${isSimplified ? '800m simplified' : 'full detail'})`);
                const geojson = layerCache.get(cacheKey);

                // Process immediately from cache
                await processVectorLayerData(geojson, layerName);
                return;
            }

            // Fallback to regular loading (which will apply simplification)
            console.log(`🔄 Loading ${layerName} from server (cache miss, ${isSimplified ? '800m simplified' : 'full detail'})`);
            await loadVectorLayer(layerName);

        } catch (error) {
            console.error(`❌ Failed to load layer ${layerName}:`, error);
            console.error('Stack trace:', error.stack);
            updateStatus(`Failed to load ${layerName}`, 'error');
        }
    }

    /**
     * Helper to process vector layer data efficiently
     * @param {Object} geojson - GeoJSON data
     * @param {string} layerName - Layer name
     */
    async function processVectorLayerData(geojson, layerName) {
        console.log('DEBUG processVectorLayerData: Called with layerName =', layerName);
        console.log('DEBUG processVectorLayerData: GeoJSON has', geojson.features?.length || 0, 'features');

        // Clear existing layers
        vectorLayerGroup.clearLayers();
        console.log('DEBUG processVectorLayerData: Cleared existing layers');

        // Create a custom pane for vector layers if it doesn't exist
        if (!map.getPane('vectorPane')) {
            const vectorPane = map.createPane('vectorPane');
            vectorPane.style.zIndex = 600; // Above WMS (400)
            console.log('📐 Created vectorPane with z-index 600');
        }

        // Use VERY subtle styling to let WMS layers show through clearly
        const style = geojson.metadata?.style || {
            fillColor: '#20B2AA',    // Light sea green
            color: '#FFD700',        // Gold border
            weight: 2,               // Border width
            fillOpacity: 0.05,       // VERY transparent (5%) - WMS clearly visible!
            opacity: 0.9             // Visible border
        };
        console.log('DEBUG processVectorLayerData: Using VERY subtle overlay style (5% fill):', style);

        // Create optimized GeoJSON layer with explicit pane assignment
        const geoJsonLayer = L.geoJSON(geojson, {
            style: () => ({ ...style, pane: 'vectorPane' }),
            pane: 'vectorPane',
            onEachFeature: function(feature, layer) {
                // Enhanced popup creation
                if (feature.properties) {
                    // Use the same enhanced content as tooltips for consistency
                    let popupContent = generateTooltipContent(feature, layerName);

                    // Wrap in popup-appropriate styling
                    popupContent = `<div style="max-width: 400px; max-height: 300px; overflow-y: auto;">${popupContent}</div>`;
                    layer.bindPopup(popupContent);
                }

                // Optimized hover effects
                layer.on({
                    mouseover: (e) => {
                        const tooltip = generateTooltipContent(feature, layerName);
                        createTooltip(tooltip, e.originalEvent.pageX, e.originalEvent.pageY);
                        layer.setStyle({ weight: style.weight + 2, fillOpacity: (style.fillOpacity || 0.4) + 0.2 });
                    },
                    mouseout: () => {
                        removeTooltip();
                        layer.setStyle(style);
                    },
                    mousemove: (e) => updateTooltip(e.originalEvent.pageX, e.originalEvent.pageY)
                });
            }
        });
        console.log('DEBUG processVectorLayerData: Created GeoJSON layer, bounds:', geoJsonLayer.getBounds());

        vectorLayerGroup.addLayer(geoJsonLayer);
        console.log('DEBUG processVectorLayerData: Added layer to vectorLayerGroup, layer count:', vectorLayerGroup.getLayers().length);

        if (!map.hasLayer(vectorLayerGroup)) {
            map.addLayer(vectorLayerGroup);
            console.log('DEBUG processVectorLayerData: Added vectorLayerGroup to map');

            // Add vector layer group to layer control (only once)
            if (window.MapInit && window.MapInit.addOverlayToControl) {
                window.MapInit.addOverlayToControl(vectorLayerGroup, `📍 BBT Areas: ${layerName}`);
            }
        } else {
            console.log('DEBUG processVectorLayerData: vectorLayerGroup already on map');
        }

        // Zoom to bounds if available
        if (geojson.metadata?.bounds) {
            const [minX, minY, maxX, maxY] = geojson.metadata.bounds;
            map.fitBounds([[minY, minX], [maxY, maxX]]);
        }

        // Update status
        const featureCount = geojson.metadata?.feature_count || 'unknown';
        updateStatus(`Vector layer loaded (${featureCount} features)`, '');

        // Hide legend for vector layers
        const legendContainer = document.getElementById('legend-container');
        if (legendContainer) {
            legendContainer.style.display = 'none';
        }
    }

    /**
     * Concurrent layer processing for better performance (with simplification support)
     * @param {Array} layerNames - Array of layer names
     * @param {number} maxConcurrent - Maximum concurrent requests
     * @returns {Object} Results and errors
     */
    async function loadMultipleLayersConcurrently(layerNames, maxConcurrent = 3) {
        const config = window.AppConfig;

        console.log(`Loading ${layerNames.length} layers concurrently (max ${maxConcurrent} parallel)`);

        const results = [];
        const errors = [];

        // Determine current zoom for simplification
        const currentZoom = map.getZoom();
        const simplifyParam = currentZoom < 12 ? '?simplify=0.007' : '';
        const simplificationType = currentZoom < 12 ? 'simplified' : 'full';

        // Process in batches to avoid overwhelming the server
        for (let i = 0; i < layerNames.length; i += maxConcurrent) {
            const batch = layerNames.slice(i, i + maxConcurrent);

            const batchPromises = batch.map(async (layerName) => {
                try {
                    const controller = new AbortController();
                    const timeoutId = setTimeout(() => controller.abort(), 20000); // 20s timeout

                    const response = await fetch(`${config.API_BASE_URL}/vector/layer/${encodeURIComponent(layerName)}${simplifyParam}`, {
                        signal: controller.signal
                    });

                    clearTimeout(timeoutId);

                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                    }

                    const data = await response.json();
                    return { layerName, data, success: true, simplificationType };
                } catch (error) {
                    return { layerName, error: error.message, success: false, simplificationType };
                }
            });

            const batchResults = await Promise.allSettled(batchPromises);
            batchResults.forEach((result, index) => {
                if (result.status === 'fulfilled') {
                    if (result.value.success) {
                        results.push(result.value);
                    } else {
                        errors.push(result.value);
                    }
                } else {
                    errors.push({ layerName: batch[index], error: result.reason?.message || 'Unknown error', success: false });
                }
            });

            // Brief pause between batches to be server-friendly
            if (i + maxConcurrent < layerNames.length) {
                await new Promise(resolve => setTimeout(resolve, 200));
            }
        }

        return { results, errors };
    }

    /**
     * Background preloading for instant layer access
     * @param {Array} vectorLayers - Array of vector layer metadata
     */
    async function preloadLayersInBackground(vectorLayers) {
        try {
            if (!vectorLayers || vectorLayers.length === 0) return;

            console.log('Preloading vector layers in background...');
            const layerNames = vectorLayers.map(layer => layer.display_name);
            const { results, errors } = await loadMultipleLayersConcurrently(layerNames, 2);

            // Cache successful results with simplification-aware keys
            results.forEach(({ layerName, data, simplificationType }) => {
                const cacheKey = `${layerName}:${simplificationType}`;
                layerCache.set(cacheKey, data);
            });

            const simplType = results.length > 0 ? results[0].simplificationType : 'unknown';
            console.log(`Cached ${results.length} layers (${simplType}) for instant access`);
            if (errors.length > 0) {
                console.warn(`${errors.length} layers failed to preload`);
            }

        } catch (error) {
            console.error('Background preloading failed:', error);
        }
    }

    // ========================================
    // UTILITY FUNCTIONS
    // ========================================

    // Loading timer state
    let loadingTimerElement = null;
    let loadingTimerInterval = null;
    let loadingStartTime = null;

    /**
     * Show loading timer widget
     * @param {string} layerName - Name of the layer being loaded
     */
    function showLoadingTimer(layerName) {
        console.log('⏱️ [TIMER] showLoadingTimer called for:', layerName);

        hideLoadingTimer(); // Clear any existing timer
        console.log('⏱️ [TIMER] Cleared any existing timer');

        loadingStartTime = Date.now();

        // Create loading timer element
        loadingTimerElement = document.createElement('div');
        loadingTimerElement.className = 'loading-timer';
        loadingTimerElement.innerHTML = `
            <div style="background: rgba(32, 178, 170, 0.95); color: white; padding: 12px 20px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); font-family: system-ui, -apple-system, sans-serif; position: fixed; top: 20px; left: 50%; transform: translateX(-50%); z-index: 10000; min-width: 300px; text-align: center;">
                <div style="font-weight: 600; margin-bottom: 6px;">⏳ Loading Layer</div>
                <div style="font-size: 13px; opacity: 0.9; margin-bottom: 8px;">${layerName}</div>
                <div style="font-size: 24px; font-weight: bold; font-family: 'Courier New', monospace;" id="loading-timer-seconds">0.0s</div>
            </div>
        `;
        document.body.appendChild(loadingTimerElement);
        console.log('⏱️ [TIMER] Timer element created and added to DOM');

        // Update timer every 100ms
        loadingTimerInterval = setInterval(() => {
            const elapsed = (Date.now() - loadingStartTime) / 1000;
            const timerDisplay = document.getElementById('loading-timer-seconds');
            if (timerDisplay) {
                timerDisplay.textContent = elapsed.toFixed(1) + 's';
            }
        }, 100);
        console.log('⏱️ [TIMER] Timer interval started');
    }

    /**
     * Hide loading timer widget
     */
    function hideLoadingTimer() {
        if (loadingTimerInterval) {
            clearInterval(loadingTimerInterval);
            loadingTimerInterval = null;
        }
        if (loadingTimerElement) {
            document.body.removeChild(loadingTimerElement);
            loadingTimerElement = null;
        }
        loadingStartTime = null;
    }

    /**
     * Update status indicator
     * @param {string} message - Status message
     * @param {string} type - Status type ('loading', 'error', '', etc.)
     */
    function updateStatus(message, type = '') {
        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.textContent = message;
            statusEl.className = type ? `status ${type}` : 'status';
        }
    }

    /**
     * Set opacity for active layer
     * @param {number} opacity - Opacity value (0-1)
     */
    function setOpacity(opacity) {
        currentOpacity = opacity;

        if ((currentLayerType === 'wms' || currentLayerType === 'wms-overlay') && wmsLayer) {
            wmsLayer.setOpacity(currentOpacity);
        } else if ((currentLayerType === 'helcom-overlay' || currentLayerType === 'human_activities-overlay') && helcomLayer) {
            helcomLayer.setOpacity(currentOpacity);
        } else if (currentLayerType === 'vector' && map.hasLayer(vectorLayerGroup)) {
            // Update opacity for vector layers
            vectorLayerGroup.eachLayer(function(layer) {
                if (layer.setStyle) {
                    const currentStyle = layer.options.style || {};
                    layer.setStyle({
                        ...currentStyle,
                        opacity: currentOpacity,
                        fillOpacity: currentOpacity * 0.6  // Slightly more transparent fill
                    });
                }
            });
        }
    }

    /**
     * Clear layers by type
     * @param {string} layerType - Type of layer to clear ('all', 'wms', 'human_activities', 'finfish_wfs', 'vector')
     */
    function clearLayers(layerType = 'all') {
        if (layerType === 'all' || layerType === 'wms') {
            if (wmsLayer) {
                map.removeLayer(wmsLayer);
                wmsLayer = null;
            }
        }
        if (layerType === 'all' || layerType === 'human_activities') {
            if (helcomLayer) {
                map.removeLayer(helcomLayer);
                helcomLayer = null;
            }
        }
        if (layerType === 'all' || layerType === 'finfish_wfs') {
            if (finfishWfsLayer) {
                map.removeLayer(finfishWfsLayer);
                finfishWfsLayer = null;
            }
        }
        if (layerType === 'all' || layerType === 'vector') {
            if (vectorLayerGroup) {
                vectorLayerGroup.clearLayers();
            }
        }
        removeTooltip();
    }

    // ========================================
    // PUBLIC API
    // ========================================

    window.LayerManager = {
        // Initialization
        init: init,

        // WMS Layer Functions
        updateWMSLayer: updateWMSLayer,
        selectWMSLayerAsOverlay: selectWMSLayerAsOverlay,
        checkLayerVisibility: checkLayerVisibility,
        updateLegend: updateLegend,

        // Human Activities Layer Functions
        selectHumanActivitiesLayerAsOverlay: selectHumanActivitiesLayerAsOverlay,

        // Finfish WFS Layer Functions
        selectFinfishWFSLayerAsOverlay: selectFinfishWFSLayerAsOverlay,

        // Vector Layer Functions
        loadVectorLayer: loadVectorLayer,
        loadVectorLayerFast: loadVectorLayerFast,
        preloadLayersInBackground: preloadLayersInBackground,

        // Extent/Zoom Functions
        zoomToLayerExtent: zoomToLayerExtent,
        scaleToZoom: scaleToZoom,
        calculateOptimalZoom: calculateOptimalZoom,

        // GetFeatureInfo Functions
        setupGetFeatureInfo: setupGetFeatureInfo,
        handleMapClick: handleMapClick,
        buildGetFeatureInfoUrl: buildGetFeatureInfoUrl,
        displayFeatureInfo: displayFeatureInfo,

        // Tooltip Functions
        createTooltip: createTooltip,
        removeTooltip: removeTooltip,
        updateTooltip: updateTooltip,
        generateTooltipContent: generateTooltipContent,
        calculateFeatureArea: calculateFeatureArea,

        // Utility Functions
        setOpacity: setOpacity,
        clearLayers: clearLayers,
        updateStatus: updateStatus,
        enableAutoLayerSwitching: (enabled) => {
            autoSwitchEnabled = enabled;
            console.log(`Auto layer switching ${enabled ? 'enabled' : 'disabled'}`);
        },

        // Getters
        getCurrentLayer: () => currentLayer,
        getCurrentLayerType: () => currentLayerType,
        getWMSLayer: () => wmsLayer,
        getHELCOMLayer: () => helcomLayer,
        getVectorLayerGroup: () => vectorLayerGroup,
        getLayerCache: () => layerCache
    };

})(window);
