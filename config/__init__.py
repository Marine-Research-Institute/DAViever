"""
Configuration package for MARBEFES BBT Database

This package provides environment-based configuration management
for the EMODnet Seabed Habitats Viewer application.
"""

from .config import (
    Config,
    DevelopmentConfig,
    ProductionConfig,
    TestingConfig,
    get_config,
    EMODNET_LAYERS,
    BASEMAP_CONFIGS
)

__all__ = [
    'Config',
    'DevelopmentConfig',
    'ProductionConfig',
    'TestingConfig',
    'get_config',
    'EMODNET_LAYERS',
    'BASEMAP_CONFIGS'
]

__version__ = '1.2.1'
