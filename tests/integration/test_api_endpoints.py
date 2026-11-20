"""
Integration tests for API endpoints
"""
import pytest
import json
from unittest.mock import patch


class TestAPIEndpoints:
    """Test Flask API endpoints"""

    def test_layers_api_endpoint(self, client):
        """Test /api/layers endpoint"""
        response = client.get('/api/layers')

        assert response.status_code == 200
        assert response.content_type == 'application/json'

        data = json.loads(response.data)
        assert isinstance(data, list)
        assert len(data) > 0

        # Check structure of first layer
        if data:
            layer = data[0]
            assert 'name' in layer
            assert 'title' in layer
            assert 'description' in layer

    @patch('app.wms_session.get')
    def test_layers_api_with_mock_wms(self, mock_get, client, mock_successful_wms_response):
        """Test /api/layers endpoint with mocked WMS response"""
        mock_get.return_value = mock_successful_wms_response

        response = client.get('/api/layers')

        assert response.status_code == 200
        data = json.loads(response.data)

        layer_names = [layer['name'] for layer in data]
        assert 'all_eusm2021' in layer_names
        assert 'substrate' in layer_names

    def test_capabilities_api_endpoint(self, client):
        """Test /api/capabilities endpoint"""
        with patch('app.wms_session.get') as mock_get:
            mock_response = mock_get.return_value
            mock_response.content = b'<WMS_Capabilities>Mock XML</WMS_Capabilities>'
            mock_response.status_code = 200

            response = client.get('/api/capabilities')

            assert response.status_code == 200
            assert response.content_type.startswith('text/xml')
            assert b'WMS_Capabilities' in response.data

    def test_capabilities_api_error_handling(self, client):
        """Test /api/capabilities endpoint error handling"""
        with patch('app.wms_session.get') as mock_get:
            mock_get.side_effect = Exception("Connection error")

            response = client.get('/api/capabilities')

            assert response.status_code == 500
            assert response.content_type == 'application/json'

            data = json.loads(response.data)
            assert 'error' in data

    def test_legend_api_endpoint(self, client):
        """Test /api/legend/<layer> endpoint"""
        response = client.get('/api/legend/test_layer')

        assert response.status_code == 200
        assert response.content_type == 'application/json'

        data = json.loads(response.data)
        assert 'legend_url' in data
        assert 'test_layer' in data['legend_url']
        assert 'GetLegendGraphic' in data['legend_url']

    def test_legend_api_with_special_characters(self, client):
        """Test legend API with layer names containing special characters"""
        layer_name = "layer-with_special.chars"
        response = client.get(f'/api/legend/{layer_name}')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert layer_name in data['legend_url']

    def test_main_page_loads(self, client):
        """Test that main page loads successfully"""
        response = client.get('/')

        assert response.status_code == 200
        assert response.content_type == 'text/html; charset=utf-8'
        assert b'EMODnet Seabed Habitats' in response.data
        assert b'leaflet' in response.data.lower()

    def test_test_page_loads(self, client):
        """Test that test page loads successfully"""
        response = client.get('/test')

        assert response.status_code == 200
        assert response.content_type == 'text/html; charset=utf-8'
        assert b'WMS Test' in response.data
        assert b'emodnet-seabedhabitats.eu' in response.data

    def test_nonexistent_endpoint(self, client):
        """Test that nonexistent endpoints return 404"""
        response = client.get('/nonexistent')
        assert response.status_code == 404

    def test_api_endpoint_methods(self, client):
        """Test that API endpoints only accept GET requests"""
        endpoints = ['/api/layers', '/api/capabilities', '/api/legend/test']

        for endpoint in endpoints:
            # Test POST request
            response = client.post(endpoint)
            assert response.status_code == 405  # Method Not Allowed

            # Test PUT request
            response = client.put(endpoint)
            assert response.status_code == 405

            # Test DELETE request
            response = client.delete(endpoint)
            assert response.status_code == 405


class TestAPIErrorHandling:
    """Test API error handling scenarios"""

    @patch('app.wms_session.get')
    def test_layers_api_timeout(self, mock_get, client):
        """Test /api/layers endpoint with timeout"""
        from requests.exceptions import Timeout
        mock_get.side_effect = Timeout()

        response = client.get('/api/layers')

        # Should still return 200 with default layers
        assert response.status_code == 200
        data = json.loads(response.data)
        assert len(data) > 0  # Should return default EMODNET_LAYERS

    @patch('app.wms_session.get')
    def test_layers_api_connection_error(self, mock_get, client):
        """Test /api/layers endpoint with connection error"""
        from requests.exceptions import ConnectionError
        mock_get.side_effect = ConnectionError()

        response = client.get('/api/layers')

        # Should still return 200 with default layers
        assert response.status_code == 200
        data = json.loads(response.data)
        assert len(data) > 0

    @patch('app.wms_session.get')
    def test_capabilities_api_timeout(self, mock_get, client):
        """Test /api/capabilities endpoint with timeout"""
        from requests.exceptions import Timeout
        mock_get.side_effect = Timeout()

        response = client.get('/api/capabilities')

        assert response.status_code == 500
        data = json.loads(response.data)
        assert 'error' in data


class TestAPIContentValidation:
    """Test API content validation and formatting"""

    def test_layers_api_content_structure(self, client):
        """Test that layers API returns properly structured data"""
        response = client.get('/api/layers')

        assert response.status_code == 200
        data = json.loads(response.data)

        for layer in data:
            # Each layer must have these fields
            for field in ('name', 'title', 'description'):
                assert field in layer, f"Layer missing field: {field}"
                assert isinstance(layer[field], str), f"Field {field} must be string"
            # Some EMODnet layers genuinely have no <Abstract>, so only
            # name and title must be non-empty
            assert layer['name'].strip() and layer['title'].strip()

    def test_legend_api_url_format(self, client):
        """Test that legend API returns properly formatted URLs"""
        test_layer = "test_layer_123"
        response = client.get(f'/api/legend/{test_layer}')

        assert response.status_code == 200
        data = json.loads(response.data)

        legend_url = data['legend_url']

        # Verify URL components
        assert legend_url.startswith('http')
        assert 'service=WMS' in legend_url
        assert 'request=GetLegendGraphic' in legend_url
        assert f'layer={test_layer}' in legend_url
        assert 'format=image/png' in legend_url