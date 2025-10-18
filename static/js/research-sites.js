/**
 * MarineSABRES Research Sites Module
 *
 * Provides navigation functionality for MarineSABRES research sites
 * 
 * @module ResearchSites
 * @requires Leaflet
 * @requires window.MapInit (for map instance access)
 *
 * @author MarineSABRES Project Team
 * @version 1.0.0
 */

const ResearchSites = (function() {
    'use strict';

    // ==================== Research Sites Data ====================
    
    /**
     * MarineSABRES Research Sites with approximate coordinates
     * @private
     * @type {Object}
     */
    const researchSites = {
        'Tuscan': {
            name: 'Tuscan Archipelago',
            center: [42.8, 10.3],  // Approximate center of Tuscan Archipelago, Italy
            zoom: 9,
            description: 'Tuscan Archipelago - Seagrass conservation and tourism'
        },
        'Arctic': {
            name: 'Arctic Northeast Atlantic',
            center: [66.0, -18.0],  // Approximate center between Iceland, Greenland, Faroes
            zoom: 5,
            description: 'Arctic Northeast Atlantic - Climate change and commercial fisheries'
        },
        'Macaronesia': {
            name: 'Macaronesia',
            center: [30.0, -20.0],  // Approximate center of Azores, Madeira, Canary Islands
            zoom: 5,
            description: 'Macaronesia - Biodiversity conservation and ecotourism'
        }
    };

    // ==================== Public API ====================

    /**
     * Zoom to a specific research site
     * @param {string} siteKey - Key identifying the research site
     * @public
     */
    function zoomToResearchSite(siteKey) {
        const site = researchSites[siteKey];
        
        if (!site) {
            console.error(`Research site '${siteKey}' not found`);
            console.error('Available sites:', Object.keys(researchSites));
            return;
        }

        // Get map instance from MapInit module
        let map = null;
        if (window.MapInit && typeof window.MapInit.getMap === 'function') {
            map = window.MapInit.getMap();
        }
        
        if (!map) {
            console.error('Map instance not available. MapInit may not be initialized yet.');
            console.error('Available on window:', Object.keys(window).filter(k => k.includes('Map')));
            return;
        }

        console.log(`✈️ Zooming to ${site.name}`);
        console.log(`📍 Coordinates: [${site.center[0]}, ${site.center[1]}]`);
        console.log(`🔍 Zoom level: ${site.zoom}`);
        
        // Fly to the site location with smooth animation
        map.flyTo(site.center, site.zoom, {
            duration: 2.0,  // Longer duration for better visibility
            easeLinearity: 0.15
        });
        
        // Log success
        setTimeout(() => {
            console.log(`✅ Zoomed to ${site.name}`);
        }, 2100);
    }

    /**
     * Get research site information
     * @param {string} siteKey - Key identifying the research site
     * @returns {Object|null} Site information or null if not found
     * @public
     */
    function getSiteInfo(siteKey) {
        return researchSites[siteKey] || null;
    }

    /**
     * Get all research sites
     * @returns {Object} All research sites data
     * @public
     */
    function getAllSites() {
        return researchSites;
    }

    /**
     * Initialize research sites functionality
     * @public
     */
    function initialize() {
        console.log('🗺️ Research Sites module initialized');
        console.log('📍 Available sites:', Object.keys(researchSites).join(', '));
        
        // Test map availability (informational only - map loads async)
        const map = window.MapInit && window.MapInit.getMap ? window.MapInit.getMap() : null;
        if (map) {
            console.log('✅ Map instance is available for research sites');
        } else {
            console.log('ℹ️ Map instance initializing... (will be available for button clicks)');
        }
    }

    // ==================== Expose Public API ====================

    return {
        zoomToResearchSite: zoomToResearchSite,
        getSiteInfo: getSiteInfo,
        getAllSites: getAllSites,
        initialize: initialize
    };
})();

// ==================== Global Function Wrappers ====================

/**
 * Global wrapper for zooming to research sites (called from HTML onclick)
 * @param {string} siteKey - Key identifying the research site
 */
function zoomToResearchSite(siteKey) {
    console.log(`🖱️ Button clicked for site: ${siteKey}`);
    ResearchSites.zoomToResearchSite(siteKey);
}

// Initialize when DOM is ready (optimized for DRY principle)
function initializeResearchSites() {
    ResearchSites?.initialize?.();
}

document.readyState === 'loading'
    ? document.addEventListener('DOMContentLoaded', initializeResearchSites)
    : initializeResearchSites();

// Placeholder functions for zoom mode (to be implemented if needed)
function setDAZoomMode(mode) {
    console.log(`DA Zoom mode set to: ${mode}`);
    // Implementation would go here
}

function updateDAZoomLevel(level) {
    console.log(`DA Zoom level updated to: ${level}`);
    document.getElementById('da-zoom-level-value').textContent = level;
    // Implementation would go here
}

// Placeholder functions for data popup (to be implemented if needed)
function openDADataPopup(site) {
    console.log(`Opening data popup for: ${site}`);
    // Implementation would go here
}

function closeDADataPopup() {
    console.log('Closing DA data popup');
    const overlay = document.getElementById('da-popup-overlay');
    if (overlay) {
        overlay.style.display = 'none';
    }
}

function saveDAData() {
    console.log('Saving DA data');
    // Implementation would go here
    closeDADataPopup();
}
