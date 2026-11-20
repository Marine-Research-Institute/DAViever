"""
Unit tests for configuration management
"""
import pytest
import os
from unittest.mock import patch

from config import (
    Config, DevelopmentConfig, ProductionConfig, TestingConfig,
    get_config, EMODNET_LAYERS, BASEMAP_CONFIGS
)


class TestConfigClasses:
    """Test configuration classes"""

    def test_base_config_defaults(self):
        """Test base configuration defaults"""
        config = Config()

        assert config.DEBUG is False
        assert config.TESTING is False
        assert config.WMS_VERSION == '1.3.0'
        assert config.WMS_TIMEOUT == 10
        assert config.MAX_LAYERS_DISPLAY == 20
        assert config.DEFAULT_MAP_CENTER_LAT == 54.0
        assert config.DEFAULT_MAP_CENTER_LNG == 10.0
        assert config.DEFAULT_MAP_ZOOM == 4

    def test_development_config(self):
        """Test development configuration"""
        config = DevelopmentConfig()

        assert config.DEBUG is True
        assert config.LOG_LEVEL == 'DEBUG'
        assert hasattr(config, 'WMS_DEBUG_REQUESTS')
        assert config.WMS_DEBUG_REQUESTS is True

    @patch.dict(os.environ, {'SECRET_KEY': 'test-secret'})
    def test_production_config(self):
        """Test production configuration"""
        config = ProductionConfig()

        assert config.DEBUG is False
        assert config.LOG_LEVEL == 'WARNING'
        assert config.SESSION_COOKIE_SECURE is True
        assert config.SESSION_COOKIE_HTTPONLY is True
        assert config.SESSION_COOKIE_SAMESITE == 'Lax'

    def test_testing_config(self):
        """Test testing configuration"""
        config = TestingConfig()

        assert config.TESTING is True
        assert config.DEBUG is True
        assert config.CACHE_TYPE == 'simple'
        assert config.CACHE_DEFAULT_TIMEOUT == 1
        assert config.WMS_TIMEOUT == 5
        assert 'mock-wms' in config.WMS_BASE_URL

    # Config reads env vars into class attributes at import time, so patching
    # os.environ and instantiating Config() in-process can never see them.
    # Import config in a fresh interpreter instead - which is exactly how the
    # systemd/gunicorn service picks them up at startup.

    def test_environment_variable_override(self):
        """Test that environment variables override defaults"""
        assert _config_attr_in_fresh_process(
            {'WMS_BASE_URL': 'http://test-wms-server.com'}, 'WMS_BASE_URL'
        ) == 'http://test-wms-server.com'

    def test_integer_environment_variables(self):
        """Test integer environment variable parsing"""
        env = {'WMS_TIMEOUT': '15', 'MAX_LAYERS_DISPLAY': '30'}
        assert _config_attr_in_fresh_process(env, 'WMS_TIMEOUT') == 15
        assert _config_attr_in_fresh_process(env, 'MAX_LAYERS_DISPLAY') == 30

    def test_float_environment_variables(self):
        """Test float environment variable parsing"""
        env = {'DEFAULT_MAP_CENTER_LAT': '60.5', 'DEFAULT_MAP_CENTER_LNG': '15.2'}
        assert _config_attr_in_fresh_process(env, 'DEFAULT_MAP_CENTER_LAT') == 60.5
        assert _config_attr_in_fresh_process(env, 'DEFAULT_MAP_CENTER_LNG') == 15.2


def _config_attr_in_fresh_process(env, attr):
    """Return Config().<attr> as seen by a new Python process with `env` set."""
    import ast
    import subprocess
    import sys
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    code = f"from config import Config; print(repr(Config().{attr}))"
    out = subprocess.run(
        [sys.executable, '-c', code], cwd=root, env={**os.environ, **env},
        capture_output=True, text=True, check=True, timeout=30,
    )
    return ast.literal_eval(out.stdout.strip())


class TestGetConfig:
    """Test configuration factory function"""

    @patch.dict(os.environ, {'FLASK_ENV': 'development'})
    def test_get_development_config(self):
        """Test getting development configuration"""
        config = get_config()
        assert isinstance(config, DevelopmentConfig)
        assert config.DEBUG is True

    def test_production_requires_secret_key(self):
        """Production must refuse to start with an auto-generated SECRET_KEY"""
        env = {k: v for k, v in os.environ.items() if k != 'SECRET_KEY'}
        with patch.dict(os.environ, env, clear=True):
            with pytest.raises(ValueError, match='SECRET_KEY'):
                ProductionConfig()

    @patch.dict(os.environ, {'FLASK_ENV': 'production', 'SECRET_KEY': 'test-secret'})
    def test_get_production_config(self):
        """Test getting production configuration"""
        config = get_config()
        assert isinstance(config, ProductionConfig)
        assert config.DEBUG is False

    @patch.dict(os.environ, {'FLASK_ENV': 'testing'})
    def test_get_testing_config(self):
        """Test getting testing configuration"""
        config = get_config()
        assert isinstance(config, TestingConfig)
        assert config.TESTING is True

    @patch.dict(os.environ, {'FLASK_ENV': 'invalid'})
    def test_get_config_with_invalid_env(self):
        """Test getting config with invalid environment defaults to development"""
        config = get_config()
        assert isinstance(config, DevelopmentConfig)

    def test_get_config_without_env_variable(self):
        """Test getting config without FLASK_ENV set"""
        with patch.dict(os.environ, {}, clear=True):
            if 'FLASK_ENV' in os.environ:
                del os.environ['FLASK_ENV']
            config = get_config()
            assert isinstance(config, DevelopmentConfig)


class TestEmodnetLayers:
    """Test EMODNET_LAYERS configuration"""

    def test_layers_structure(self):
        """Test that all layers have required fields"""
        for layer in EMODNET_LAYERS:
            assert 'name' in layer
            assert 'title' in layer
            assert 'description' in layer
            assert 'category' in layer
            assert isinstance(layer['name'], str)
            assert isinstance(layer['title'], str)
            assert isinstance(layer['description'], str)
            assert isinstance(layer['category'], str)

    def test_layers_categories(self):
        """Test that layer categories are valid"""
        valid_categories = {'habitat_maps', 'conservation', 'physical', 'quality'}
        for layer in EMODNET_LAYERS:
            assert layer['category'] in valid_categories

    def test_specific_layers_exist(self):
        """Test that expected layers exist"""
        layer_names = [layer['name'] for layer in EMODNET_LAYERS]
        expected_layers = [
            'eusm_eunis2019_group', 'eusm_msfd_group', 'ospar_2025_group',
            'eusm2025_msfd_bbht_and_eunis2019_conf', 'annexiMaps_all'
        ]
        for expected in expected_layers:
            assert expected in layer_names

    @pytest.mark.network
    @pytest.mark.wms
    @pytest.mark.parametrize("layer", EMODNET_LAYERS, ids=lambda l: l['name'])
    def test_predefined_layer_renders_on_emodnet(self, layer):
        """Each hard-coded layer must still render on the live EMODnet WMS.

        Two silent failure modes, both seen 2026-11:
        - renamed/retired layer: HTTP 200 + XML ServiceException instead of a PNG
        - scale-limited layer (e.g. *_full, MaxScaleDenominator=500000): a valid
          but fully transparent PNG at overview zooms
        So check the content type AND that the Europe-wide view has drawn pixels.
        """
        import io
        import requests
        Image = pytest.importorskip('PIL.Image')
        params = {
            'service': 'WMS', 'request': 'GetMap', 'version': '1.1.0',
            'layers': layer['name'], 'styles': '', 'format': 'image/png',
            'transparent': 'true', 'width': 256, 'height': 256, 'srs': 'EPSG:3857',
            # Whole of Europe incl. NE Atlantic, Med, Baltic (~zoom 3)
            'bbox': '-2500000,4000000,4500000,11000000',
        }
        try:
            # Europe-scale group layers take 10-20 s to render on EMODnet
            r = requests.get(Config.WMS_BASE_URL, params=params, timeout=60)
        except (requests.Timeout, requests.ConnectionError) as e:
            # Slowness/outage says nothing about a renamed or blank layer
            pytest.skip(f"EMODnet WMS unreachable or too slow: {e}")
        assert r.headers.get('Content-Type', '').startswith('image/'), r.text[:300]
        alpha = Image.open(io.BytesIO(r.content)).convert('RGBA').getchannel('A').histogram()
        filled = 1 - alpha[0] / sum(alpha)
        assert filled > 0.01, f"{layer['name']} renders blank at Europe scale ({filled:.1%} filled)"


class TestBasemapConfigs:
    """Test BASEMAP_CONFIGS configuration"""

    def test_basemap_structure(self):
        """Test that all basemaps have required fields"""
        for basemap_key, basemap in BASEMAP_CONFIGS.items():
            assert 'name' in basemap
            assert 'url' in basemap
            assert 'attribution' in basemap
            assert isinstance(basemap['name'], str)
            assert isinstance(basemap['url'], str)
            assert isinstance(basemap['attribution'], str)
            assert '{z}' in basemap['url']  # Ensure tile URL template

    def test_expected_basemaps_exist(self):
        """Test that expected basemaps exist"""
        expected_basemaps = ['osm', 'satellite', 'ocean', 'light']
        for expected in expected_basemaps:
            assert expected in BASEMAP_CONFIGS

    def test_basemap_urls_are_https(self):
        """Test that basemap URLs use HTTPS where possible"""
        for basemap_key, basemap in BASEMAP_CONFIGS.items():
            # Most tile services should use HTTPS
            if 'openstreetmap.org' not in basemap['url']:
                assert basemap['url'].startswith('https://'), f"Basemap {basemap_key} should use HTTPS"

class TestFlaskCachingType:
    """Short CACHE_TYPE names must map to class names Flask-Caching >=2.5 accepts"""

    @pytest.mark.parametrize("short, expected", [
        ('simple', 'SimpleCache'),
        ('SIMPLE', 'SimpleCache'),
        ('filesystem', 'FileSystemCache'),
        ('redis', 'RedisCache'),
        ('null', 'NullCache'),
        ('SimpleCache', 'SimpleCache'),  # already a class name: pass through
    ])
    def test_translation(self, short, expected):
        from config import flask_caching_type
        assert flask_caching_type(short) == expected

    @pytest.mark.parametrize("short", ['simple', 'filesystem', 'null'])
    def test_backend_actually_loads(self, short, tmp_path):
        """The translated name must be importable by the installed Flask-Caching"""
        from flask import Flask
        from flask_caching import Cache
        from config import flask_caching_type
        app = Flask(__name__)
        Cache(app, config={'CACHE_TYPE': flask_caching_type(short),
                           'CACHE_DIR': str(tmp_path)})
