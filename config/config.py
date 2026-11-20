"""
Configuration management for MarineSABRES Demonstration Area Tool
"""
import os
import secrets
from typing import Dict, Any


class Config:
    """Base configuration class"""

    # Flask settings
    # Use secrets module for cryptographically strong random key in development
    # Production MUST set SECRET_KEY environment variable
    SECRET_KEY = os.getenv('SECRET_KEY', secrets.token_hex(32))
    DEBUG = False
    TESTING = False
    APPLICATION_ROOT = os.getenv('APPLICATION_ROOT', '')  # Subpath for mounting app (e.g., '/BBTS')

    # WMS Service Configuration
    WMS_BASE_URL = os.getenv(
        'WMS_BASE_URL',
        'https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms'
    )
    WMS_VERSION = os.getenv('WMS_VERSION', '1.3.0')
    WMS_TIMEOUT = int(os.getenv('WMS_TIMEOUT', '10'))

    # EMODnet Human Activities WMS Service Configuration
    HUMAN_ACTIVITIES_WMS_BASE_URL = os.getenv(
        'HUMAN_ACTIVITIES_WMS_BASE_URL',
        'https://ows.emodnet-humanactivities.eu/wms'
    )
    HUMAN_ACTIVITIES_WMS_VERSION = os.getenv('HUMAN_ACTIVITIES_WMS_VERSION', '1.3.0')

    # EMODnet Finfish WFS Service Configuration
    FINFISH_WFS_BASE_URL = os.getenv(
        'FINFISH_WFS_BASE_URL',
        'https://geo.vliz.be/geoserver/Emodnetbio/wfs'
    )
    FINFISH_WFS_VERSION = os.getenv('FINFISH_WFS_VERSION', '2.0.0')
    FINFISH_WFS_TIMEOUT = int(os.getenv('FINFISH_WFS_TIMEOUT', '15'))

    # Application settings
    MAX_LAYERS_DISPLAY = int(os.getenv('MAX_LAYERS_DISPLAY', '20'))
    DEFAULT_MAP_CENTER_LAT = float(os.getenv('DEFAULT_MAP_CENTER_LAT', '54.0'))
    DEFAULT_MAP_CENTER_LNG = float(os.getenv('DEFAULT_MAP_CENTER_LNG', '10.0'))
    DEFAULT_MAP_ZOOM = int(os.getenv('DEFAULT_MAP_ZOOM', '4'))

    # Caching settings
    # Options: 'simple' (in-memory), 'redis', 'memcached', 'filesystem'
    CACHE_TYPE = os.getenv('CACHE_TYPE', 'simple')
    CACHE_DEFAULT_TIMEOUT = int(os.getenv('CACHE_DEFAULT_TIMEOUT', '3600'))
    WMS_CACHE_TIMEOUT = int(os.getenv('WMS_CACHE_TIMEOUT', '300'))  # 5 minutes

    # Redis cache configuration (used when CACHE_TYPE='redis')
    CACHE_REDIS_HOST = os.getenv('CACHE_REDIS_HOST', 'localhost')
    CACHE_REDIS_PORT = int(os.getenv('CACHE_REDIS_PORT', '6379'))
    CACHE_REDIS_DB = int(os.getenv('CACHE_REDIS_DB', '0'))
    CACHE_REDIS_PASSWORD = os.getenv('CACHE_REDIS_PASSWORD', None)
    # Redis connection URL format: redis://[:password]@host:port/db
    CACHE_REDIS_URL = os.getenv('CACHE_REDIS_URL', None)  # Override individual settings if set

    # Filesystem cache configuration (used when CACHE_TYPE='filesystem')
    CACHE_DIR = os.getenv('CACHE_DIR', 'cache')
    CACHE_THRESHOLD = int(os.getenv('CACHE_THRESHOLD', '1000'))  # Max items in filesystem cache

    # Layer filtering configuration
    CORE_EUROPEAN_LAYER_COUNT = int(os.getenv('CORE_EUROPEAN_LAYER_COUNT', '6'))

    # Logging configuration
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FILE = os.getenv('LOG_FILE', 'logs/emodnet_viewer.log')
    LOG_MAX_BYTES = int(os.getenv('LOG_MAX_BYTES', '10485760'))  # 10MB
    LOG_BACKUP_COUNT = int(os.getenv('LOG_BACKUP_COUNT', '5'))


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    LOG_LEVEL = 'DEBUG'

    # More verbose logging in development
    WMS_DEBUG_REQUESTS = True


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False

    # Production-specific security settings
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'

    # Production logging
    LOG_LEVEL = 'WARNING'

    def __init__(self):
        super().__init__()
        # Validate critical production settings
        # Require explicit SECRET_KEY in production (not auto-generated)
        if 'SECRET_KEY' not in os.environ:
            raise ValueError(
                "Production ERROR: SECRET_KEY environment variable must be explicitly set. "
                "Auto-generated keys are not suitable for production (sessions will reset on restart). "
                "Generate a secure key with: python -c 'import secrets; print(secrets.token_hex(32))'"
            )


class TestingConfig(Config):
    """Testing configuration"""
    TESTING = True
    DEBUG = True

    # Use in-memory cache for tests
    CACHE_TYPE = 'simple'
    CACHE_DEFAULT_TIMEOUT = 1

    # Mock WMS for testing
    WMS_BASE_URL = 'http://localhost:8080/mock-wms'
    WMS_TIMEOUT = 5

    # Test logging
    LOG_LEVEL = 'DEBUG'


def get_config() -> Config:
    """Get configuration based on environment"""
    env = os.getenv('FLASK_ENV', 'development').lower()

    config_map = {
        'development': DevelopmentConfig,
        'production': ProductionConfig,
        'testing': TestingConfig,
    }

    return config_map.get(env, DevelopmentConfig)()


# Flask-Caching resolves CACHE_TYPE by backend class name. The short aliases
# ('simple', 'redis', ...) worked in 2.3.1 but are rejected by 2.5.1, so the
# app keeps short names in its own config and translates them at the boundary.
_FLASK_CACHING_BACKENDS = {
    'simple': 'SimpleCache',
    'filesystem': 'FileSystemCache',
    'redis': 'RedisCache',
    'memcached': 'MemcachedCache',
    'null': 'NullCache',
}


def flask_caching_type(cache_type: str) -> str:
    """Map a short CACHE_TYPE name to the Flask-Caching backend class name.

    Unknown values (e.g. an already-qualified 'SimpleCache') pass through unchanged.
    """
    return _FLASK_CACHING_BACKENDS.get(cache_type.lower(), cache_type)


# Predefined EMODnet layers configuration
# Layer names must exist on the live WMS - EMODnet retires names between
# EUSeaMap releases (the 2021 names were gone by Nov 2026). Verified against
# GetCapabilities 2026-11-20; tests/unit/test_config.py checks each one renders.
# Prefer the version-less eusm_*_group layers: they always point at the
# current EUSeaMap release and render at all zooms. The year-stamped *_full
# layers have MaxScaleDenominator=500000 and are blank at site-overview zooms.
# Seabed substrate omitted: EMODnet's substrate group layers (eusm_subs_group,
# eusm2023_subs_group) are listed but fail GetMap with LayerNotDefined as of
# 2026-11-20. Re-add eusm_subs_group once it renders.
EMODNET_LAYERS = [
    {
        "name": "eusm_eunis2019_group",
        "title": "EUSeaMap - Habitats (EUNIS 2019)",
        "description": "Broad-scale predictive seabed habitat map for Europe (current EUSeaMap release), EUNIS 2019 classification",
        "category": "habitat_maps"
    },
    {
        "name": "eusm_msfd_group",
        "title": "EUSeaMap - MSFD Broad Habitat Types",
        "description": "Broad-scale predictive seabed habitat map for Europe (current EUSeaMap release), MSFD benthic broad habitat types",
        "category": "habitat_maps"
    },
    {
        "name": "ospar_2025_group",
        "title": "OSPAR Threatened Habitats (2025)",
        "description": "OSPAR threatened and/or declining habitats, NE Atlantic point and polygon records",
        "category": "conservation"
    },
    {
        "name": "eusm2025_msfd_bbht_and_eunis2019_conf",
        "title": "EUSeaMap 2025 - Classification Confidence",
        "description": "Confidence in the MSFD broad habitat type and EUNIS 2019 habitat classification",
        "category": "quality"
    },
    {
        "name": "annexiMaps_all",
        "title": "Annex I Habitats",
        "description": "Habitats Directive Annex I habitat types",
        "category": "conservation"
    }
]

# Base map configurations
BASEMAP_CONFIGS = {
    'osm': {
        'name': 'OpenStreetMap',
        'url': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        'attribution': '© OpenStreetMap contributors'
    },
    'satellite': {
        'name': 'Satellite',
        'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        'attribution': '© Esri'
    },
    'ocean': {
        'name': 'Ocean',
        'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}',
        'attribution': '© Esri'
    },
    'light': {
        'name': 'Light Gray',
        'url': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
        'attribution': '© CartoDB'
    }
}