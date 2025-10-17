/**
 * Configuration Module
 * Centralizes all application configuration and constants
 */

// Application configuration (will be injected by Flask template)
// Only initialize if not already set by template
if (typeof window.AppConfig === 'undefined') {
    window.AppConfig = {
        API_BASE_URL: '', // Set by template
        WMS_BASE_URL: '', // Set by template
        HELCOM_WMS_BASE_URL: '', // Set by template
        HUMAN_ACTIVITIES_WMS_BASE_URL: '', // Set by template
        FINFISH_WFS_BASE_URL: '' // Set by template
    };
}

// Add default configuration properties
Object.assign(window.AppConfig, {
    // Default map settings
    defaultView: {
        lat: 54.0,
        lng: 10.0,
        zoom: 4
    },

    // Default layer settings
    defaultLayer: 'eusm_2023_eunis2019_full',
    defaultOpacity: 0.7,

    // Map configuration
    zoomControl: false
});

// Base map definitions
window.BaseMaps = {
    'emodnet_bathymetry': {
        url: 'https://tiles.emodnet-bathymetry.eu/latest/mean_atlas_land/web_mercator/{z}/{x}/{y}.png',
        options: {
            attribution: '© EMODnet Bathymetry | Marine data from European seas',
            minZoom: 0,
            maxZoom: 18
        }
    },
    'osm': {
        url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        options: {
            attribution: '© OpenStreetMap contributors'
        }
    },
    'satellite': {
        url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        options: {
            attribution: '© Esri'
        }
    },
    'ocean': {
        url: 'https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}',
        options: {
            attribution: '© Esri'
        }
    },
    'light': {
        url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
        options: {
            attribution: '© CartoDB'
        }
    }
};

// Default base map
window.AppConfig.defaultBaseMap = 'satellite';
