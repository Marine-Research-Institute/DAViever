"""
Version information for MarineSABRES Demonstration Area Tool
"""

__version__ = "1.3.0"
__version_info__ = (1, 3, 0)
__release_date__ = "2025-10-18"
__status__ = "Production"

# Production version (current)
__production_version__ = "1.3.0"
__production_release_date__ = "2025-10-18"

# Version history
VERSION_HISTORY = {
    "1.3.0": {
        "date": "2025-10-18",
        "status": "Production",
        "changes": [
            "Removed MARBEFES BBT factsheet functionality",
            "Removed vector data processing (geopandas, fiona, pyproj, numpy)",
            "Cleaned up dependencies (7 core packages instead of 13)",
            "Added comprehensive input validation for security",
            "Standardized project naming to MarineSABRES",
            "Focused exclusively on 3 research sites",
            "Simplified codebase for WMS-only data sources",
            "Updated frameworks: Flask 3.1.2, Flask-Limiter 4.0.0, Gunicorn 23.0.0",
            "Fixed deployment scripts and configuration",
            "Implemented two-version deployment structure",
        ]
    },
    "1.3.0-dev": {
        "date": "2025-10-16",
        "status": "Development",
        "changes": [
            "Development version with auto-reload enabled",
            "Testing framework updates: pytest 8.4.2, black 25.9.0, flake8 7.3.0",
        ]
    },
    "1.2.1": {
        "date": "2025-01",
        "status": "Stable",
        "changes": [
            "Security enhancement: localhost binding by default",
            "Python 3.12+ compatibility fixes",
            "Input validation on API endpoints",
            "Flask-Caching 2.3.1 update",
        ]
    },
    "1.2.0": {
        "date": "2025-01",
        "status": "Stable",
        "changes": [
            "Factsheet data caching (86% performance improvement)",
            "Framework updates (Flask 3.1.2)",
        ]
    },
}

# Project metadata
PROJECT_NAME = "MarineSABRES Demonstration Area Tool"
PROJECT_FULL_NAME = "Marine Systems Approaches for Biodiversity Resilience and Ecosystem Sustainability"
PROJECT_GRANT = "Horizon Europe Grant Agreement No. 101093169"
PROJECT_URL = "https://www.marinesabres.eu"
CORDIS_URL = "https://cordis.europa.eu/project/id/101093169"

# Research sites
RESEARCH_SITES = [
    "Tuscan Archipelago",
    "Arctic Northeast Atlantic",
    "Macaronesia"
]

# Data sources
DATA_SOURCES = {
    "emodnet_habitats": {
        "name": "EMODnet Seabed Habitats",
        "url": "https://ows.emodnet-seabedhabitats.eu/geoserver/emodnet_view/wms",
        "layers": "265+",
    },
    "emodnet_human_activities": {
        "name": "EMODnet Human Activities",
        "url": "https://ows.emodnet-humanactivities.eu/wms",
        "layers": "48",
    }
}


def get_version_string():
    """Get formatted version string"""
    return f"{PROJECT_NAME} v{__version__} ({__status__})"


def get_version_info():
    """Get complete version information as dictionary"""
    return {
        "version": __version__,
        "version_info": __version_info__,
        "release_date": __release_date__,
        "status": __status__,
        "production_version": __production_version__,
        "production_release_date": __production_release_date__,
        "project_name": PROJECT_NAME,
        "project_full_name": PROJECT_FULL_NAME,
        "grant": PROJECT_GRANT,
        "project_url": PROJECT_URL,
        "cordis_url": CORDIS_URL,
        "research_sites": RESEARCH_SITES,
        "data_sources": DATA_SOURCES,
    }
