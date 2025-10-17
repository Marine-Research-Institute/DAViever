#!/usr/bin/env python3
import requests
from xml.etree import ElementTree as ET

try:
    response = requests.get('https://ows.emodnet-bathymetry.eu/wms?service=WMS&version=1.3.0&request=GetCapabilities', timeout=15)
    root = ET.fromstring(response.content)
    
    # Remove namespaces
    for elem in root.iter():
        if '}' in elem.tag:
            elem.tag = elem.tag.split('}')[1]
    
    print('Available EMODnet Bathymetry layers:')
    for layer in root.findall('.//Layer'):
        name_elem = layer.find('Name')
        title_elem = layer.find('Title')
        if name_elem is not None and name_elem.text and 'emodnet:' in name_elem.text:
            layer_name = name_elem.text
            title = title_elem.text if title_elem is not None else 'No title'
            print(f'  {layer_name} - {title}')
except Exception as e:
    print(f'Error: {e}')