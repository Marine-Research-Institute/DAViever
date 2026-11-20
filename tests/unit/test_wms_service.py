"""
Unit tests for WMS service functionality
"""
import pytest
from unittest.mock import patch, Mock
from xml.etree import ElementTree as ET
import requests

from app import get_available_layers
from config import EMODNET_LAYERS


class TestGetAvailableLayers:
    """Test WMS layer discovery functionality"""

    @patch('app.wms_session.get')
    def test_successful_wms_request(self, mock_get, mock_successful_wms_response):
        """Test successful WMS GetCapabilities request"""
        mock_get.return_value = mock_successful_wms_response

        layers = get_available_layers()

        assert len(layers) >= 2
        layer_names = [layer['name'] for layer in layers]
        assert 'all_eusm2021' in layer_names
        assert 'substrate' in layer_names

        # Verify the request was made correctly
        mock_get.assert_called_once()
        params = mock_get.call_args.kwargs['params']
        assert params['service'] == 'WMS'
        assert params['request'] == 'GetCapabilities'

    @patch('app.wms_session.get')
    def test_failed_wms_request(self, mock_get, mock_failed_wms_response):
        """Test failed WMS GetCapabilities request falls back to defaults"""
        mock_get.return_value = mock_failed_wms_response

        layers = get_available_layers()

        # Should return default layers when WMS fails
        assert layers == EMODNET_LAYERS
        mock_get.assert_called_once()

    @patch('app.wms_session.get')
    def test_wms_timeout(self, mock_get):
        """Test WMS request timeout handling"""
        mock_get.side_effect = requests.exceptions.Timeout()

        layers = get_available_layers()

        # Should return default layers on timeout
        assert layers == EMODNET_LAYERS
        mock_get.assert_called_once()

    @patch('app.wms_session.get')
    def test_wms_connection_error(self, mock_get):
        """Test WMS connection error handling"""
        mock_get.side_effect = requests.exceptions.ConnectionError()

        layers = get_available_layers()

        # Should return default layers on connection error
        assert layers == EMODNET_LAYERS
        mock_get.assert_called_once()

    @patch('app.wms_session.get')
    def test_invalid_xml_response(self, mock_get):
        """Test handling of invalid XML response"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b'Invalid XML content'
        mock_get.return_value = mock_response

        layers = get_available_layers()

        # Should return default layers when XML parsing fails
        assert layers == EMODNET_LAYERS
        mock_get.assert_called_once()

    @patch('app.wms_session.get')
    def test_xml_parsing_with_namespaces(self, mock_get):
        """Test XML parsing handles namespaces correctly"""
        xml_with_namespaces = '''<?xml version="1.0" encoding="UTF-8"?>
        <wms:WMS_Capabilities xmlns:wms="http://www.opengis.net/wms" version="1.3.0">
            <wms:Capability>
                <wms:Layer>
                    <wms:Layer>
                        <wms:Name>test_layer</wms:Name>
                        <wms:Title>Test Layer Title</wms:Title>
                        <wms:Abstract>Test layer description</wms:Abstract>
                    </wms:Layer>
                </wms:Layer>
            </wms:Capability>
        </wms:WMS_Capabilities>'''

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = xml_with_namespaces.encode('utf-8')
        mock_get.return_value = mock_response

        layers = get_available_layers()

        # Should successfully parse namespaced XML
        assert len(layers) >= 1
        layer_names = [layer['name'] for layer in layers]
        assert 'test_layer' in layer_names

        # Find the test layer and verify its properties
        test_layer = next((layer for layer in layers if layer['name'] == 'test_layer'), None)
        assert test_layer is not None
        assert test_layer['title'] == 'Test Layer Title'
        assert test_layer['description'] == 'Test layer description'

    @patch('app.wms_session.get')
    def test_layer_filtering(self, mock_get):
        """Test that workspace-prefixed layer names are filtered out"""
        xml_with_prefixed_layers = '''<?xml version="1.0" encoding="UTF-8"?>
        <WMS_Capabilities version="1.3.0">
            <Capability>
                <Layer>
                    <Layer>
                        <Name>workspace:prefixed_layer</Name>
                        <Title>Prefixed Layer</Title>
                    </Layer>
                    <Layer>
                        <Name>normal_layer</Name>
                        <Title>Normal Layer</Title>
                    </Layer>
                </Layer>
            </Capability>
        </WMS_Capabilities>'''

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = xml_with_prefixed_layers.encode('utf-8')
        mock_get.return_value = mock_response

        layers = get_available_layers()

        layer_names = [layer['name'] for layer in layers]
        # Workspace-prefixed layer should be filtered out
        assert 'workspace:prefixed_layer' not in layer_names
        # Normal layer should be included
        assert 'normal_layer' in layer_names

    @patch('app.wms_session.get')
    def test_core_layers_first_and_all_discovered_kept(self, mock_get):
        """Predefined layers lead the list; every discovered layer follows (no cap).

        The old MAX_LAYERS_DISPLAY=20 cap was dropped - the UI lists all ~280
        EMODnet layers - so assert ordering and completeness instead.
        """
        layers_xml = '<WMS_Capabilities version="1.3.0"><Capability><Layer>'
        for i in range(50):
            layers_xml += f'''
            <Layer>
                <Name>layer_{i}</Name>
                <Title>Layer {i}</Title>
            </Layer>'''
        layers_xml += '</Layer></Capability></WMS_Capabilities>'

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = layers_xml.encode('utf-8')
        mock_get.return_value = mock_response

        layers = get_available_layers()
        names = [layer['name'] for layer in layers]

        core = [layer['name'] for layer in EMODNET_LAYERS]
        assert names[:len(core)] == core
        assert set(f'layer_{i}' for i in range(50)) <= set(names)
        assert len(names) == len(set(names)), "duplicate layer names"

    @patch('app.wms_session.get')
    def test_caribbean_layers_excluded(self, mock_get):
        """Caribbean layers are outside every MarineSABRES site and are dropped"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b'''<WMS_Capabilities version="1.3.0"><Capability><Layer>
            <Layer><Name>carib_eusm2025_full</Name><Title>Caribbean map</Title></Layer>
            <Layer><Name>med_layer</Name><Title>Mediterranean map</Title></Layer>
        </Layer></Capability></WMS_Capabilities>'''
        mock_get.return_value = mock_response

        names = [layer['name'] for layer in get_available_layers()]

        assert 'carib_eusm2025_full' not in names
        assert 'med_layer' in names

    @patch('app.wms_session.get')
    def test_empty_layer_response(self, mock_get):
        """Test handling of XML with no layers"""
        empty_xml = '''<?xml version="1.0" encoding="UTF-8"?>
        <WMS_Capabilities version="1.3.0">
            <Capability>
                <Layer>
                    <!-- No child layers -->
                </Layer>
            </Capability>
        </WMS_Capabilities>'''

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = empty_xml.encode('utf-8')
        mock_get.return_value = mock_response

        layers = get_available_layers()

        # Should return default layers when no layers found in XML
        assert layers == EMODNET_LAYERS

    @patch('app.wms_session.get')
    def test_empty_abstract_gives_empty_string(self, mock_get):
        """<Abstract/> with no text must yield '' not None (live EMODnet has such layers)"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b'''<WMS_Capabilities version="1.3.0"><Capability><Layer>
            <Layer><Name>no_abstract</Name><Title>No abstract</Title><Abstract/></Layer>
        </Layer></Capability></WMS_Capabilities>'''
        mock_get.return_value = mock_response

        layer = next(l for l in get_available_layers() if l['name'] == 'no_abstract')

        assert layer['description'] == ''

    def test_layer_data_structure(self):
        """Test that returned layers have correct structure"""
        with patch('app.wms_session.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.content = '''<?xml version="1.0"?>
            <WMS_Capabilities>
                <Capability>
                    <Layer>
                        <Layer>
                            <Name>test_layer</Name>
                            <Title>Test Title</Title>
                            <Abstract>Test Description</Abstract>
                        </Layer>
                    </Layer>
                </Capability>
            </WMS_Capabilities>'''.encode('utf-8')
            mock_get.return_value = mock_response

            layers = get_available_layers()

            assert len(layers) >= 1
            for layer in layers:
                assert 'name' in layer
                assert 'title' in layer
                assert 'description' in layer
                assert isinstance(layer['name'], str)
                assert isinstance(layer['title'], str)
                assert isinstance(layer['description'], str)