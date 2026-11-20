"""
Pytest configuration and shared fixtures for EMODnet Viewer tests
"""
import pytest
import os
import sys
from unittest.mock import Mock, patch
from xml.etree import ElementTree as ET

# Add src and config directories to Python path for imports
project_root = os.path.join(os.path.dirname(__file__), '..')
sys.path.insert(0, project_root)
sys.path.insert(0, os.path.join(project_root, 'config'))

from app import app as flask_app, cache
from config import TestingConfig


@pytest.fixture(autouse=True)
def clear_layer_cache():
    """Layer fetchers are @cache.cached - reset between tests so one test's
    (possibly live or mocked) result is never served to the next."""
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def app():
    """Create Flask app for testing"""
    flask_app.config.from_object(TestingConfig)

    with flask_app.app_context():
        yield flask_app


@pytest.fixture
def client(app):
    """Create test client"""
    return app.test_client()


@pytest.fixture
def runner(app):
    """Create CLI runner"""
    return app.test_cli_runner()


@pytest.fixture
def mock_wms_capabilities():
    """Mock WMS GetCapabilities response"""
    xml_content = '''<?xml version="1.0" encoding="UTF-8"?>
    <WMS_Capabilities version="1.3.0">
        <Service>
            <Name>WMS</Name>
            <Title>EMODnet Seabed Habitats WMS</Title>
        </Service>
        <Capability>
            <Layer>
                <Title>Root Layer</Title>
                <Layer>
                    <Name>all_eusm2021</Name>
                    <Title>EUSeaMap 2021 - All Habitats</Title>
                    <Abstract>Broad-scale seabed habitat map for Europe</Abstract>
                    <EX_GeographicBoundingBox>
                        <westBoundLongitude>-44.0</westBoundLongitude>
                        <eastBoundLongitude>42.0</eastBoundLongitude>
                        <southBoundLatitude>24.0</southBoundLatitude>
                        <northBoundLatitude>72.0</northBoundLatitude>
                    </EX_GeographicBoundingBox>
                    <MinScaleDenominator>1000</MinScaleDenominator>
                    <MaxScaleDenominator>10000000</MaxScaleDenominator>
                </Layer>
                <Layer>
                    <Name>substrate</Name>
                    <Title>Seabed Substrate</Title>
                    <Abstract>Seabed substrate types</Abstract>
                </Layer>
            </Layer>
        </Capability>
    </WMS_Capabilities>'''
    return xml_content


@pytest.fixture
def mock_successful_wms_response(mock_wms_capabilities):
    """Mock successful WMS response"""
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.content = mock_wms_capabilities.encode('utf-8')
    mock_response.text = mock_wms_capabilities
    return mock_response


@pytest.fixture
def mock_failed_wms_response():
    """Mock failed WMS response"""
    mock_response = Mock()
    mock_response.status_code = 500
    mock_response.content = b'Internal Server Error'
    return mock_response


@pytest.fixture
def sample_layer_data():
    """Sample layer data for tests"""
    return [
        {
            "name": "test_layer_1",
            "title": "Test Layer 1",
            "description": "Test layer description 1"
        },
        {
            "name": "test_layer_2",
            "title": "Test Layer 2",
            "description": "Test layer description 2"
        }
    ]


@pytest.fixture
def mock_xml_parser():
    """Mock XML parser for testing XML parsing functionality"""
    def parse_xml(content):
        return ET.fromstring(content)
    return parse_xml


class MockWMSServer:
    """Mock WMS server for integration tests"""

    def __init__(self):
        self.responses = {}
        self.request_count = 0

    def add_response(self, request_type, content, status_code=200):
        """Add a mock response for a specific request type"""
        self.responses[request_type] = {
            'content': content,
            'status_code': status_code
        }

    def get_response(self, request_type):
        """Get mock response for request type"""
        self.request_count += 1
        return self.responses.get(request_type, {
            'content': 'Not Found',
            'status_code': 404
        })


@pytest.fixture
def mock_wms_server():
    """Mock WMS server fixture"""
    return MockWMSServer()


@pytest.fixture
def temp_log_file(tmp_path):
    """Create temporary log file for testing"""
    log_file = tmp_path / "test.log"
    return str(log_file)