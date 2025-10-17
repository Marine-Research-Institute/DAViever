# BBT Bathymetry Statistics Tool

## Overview

The BBT Bathymetry Statistics Tool manages depth statistics (minimum, maximum, average) for each Broad Belt Transect (BBT) area. The tool supports two data input methods:

1. **Manual CSV Input** (Recommended): Simple CSV file with manually entered bathymetry data
2. **Automated Sampling**: Experimental WMS-based sampling from EMODnet Bathymetry service

## Features

- **Automated Data Collection**: Samples bathymetry data across BBT polygons using EMODnet WMS service
- **Statistical Analysis**: Calculates min, max, average, and standard deviation of depth
- **JSON Output**: Produces machine-readable statistics file for app integration
- **Progress Logging**: Detailed logging of calculation progress
- **Error Handling**: Graceful handling of missing or invalid data

## Data Source

**EMODnet Bathymetry**
- URL: https://portal.emodnet-bathymetry.eu/
- Service: WMS GetFeatureInfo
- Layer: `emodnet:mean_atlas_land`
- Coverage: European seas
- Resolution: Variable, point-based sampling

## Usage

### Quick Start (CSV Method - Recommended)

```bash
# 1. Edit the CSV file with your bathymetry data
nano data/bbt_bathymetry_manual.csv

# 2. Convert CSV to JSON format
./update_bathymetry_from_csv.sh

# 3. Restart the application to load new data
# The data will automatically appear in BBT popups
```

**CSV Format:**
```csv
BBT_Name,Min_Depth_m,Max_Depth_m,Avg_Depth_m,Notes
Archipelago,5.2,45.8,25.3,Shallow coastal waters with rocky outcrops
Bay of Gdansk,8.1,52.6,28.4,Baltic Sea coastal zone
```

### Advanced: WMS Sampling Method

```bash
# Run with default settings (25x25 point sampling)
./calculate_bathymetry.sh

# Run with verbose logging
./calculate_bathymetry.sh --verbose

# Run with custom sampling density
./calculate_bathymetry.sh --samples 30
```

### Python API

```python
from emodnet_viewer.utils.bathymetry_calculator import BathymetryCalculator

# Initialize
calculator = BathymetryCalculator(
    gpkg_path="data/vector/BBT.gpkg",
    layer_name="BBT areas"
)

# Calculate statistics
stats = calculator.calculate_all_bbt_stats(num_samples=25)

# Save to JSON
calculator.save_to_json("data/bbt_bathymetry_stats.json")

# Get summary
summary = calculator.get_summary()
print(f"Processed {summary['with_bathymetry_data']} BBT areas")
```

### Command Line Options

**Shell Script (`calculate_bathymetry.sh`)**:
- `--verbose`: Enable verbose logging
- `--samples N`: Number of sample points per dimension (default: 25)

**Python Script (`scripts/calculate_bathymetry.py`)**:
- `--gpkg PATH`: Path to BBT GPKG file (default: data/vector/BBT.gpkg)
- `--layer NAME`: Layer name in GPKG (default: BBT areas)
- `--output PATH`: Output JSON path (default: data/bbt_bathymetry_stats.json)
- `--samples N`: Sampling density (default: 25)
- `--verbose`: Verbose logging

## How It Works

### 1. Polygon Sampling

For each BBT area:
1. Creates a regular grid of sample points (default: 25×25 = 625 points)
2. Filters points to those inside the BBT polygon
3. Queries EMODnet WMS GetFeatureInfo at each point
4. Collects depth values

### 2. Statistical Calculation

For valid depth measurements:
- **Minimum depth**: Shallowest point
- **Maximum depth**: Deepest point
- **Average depth**: Mean of all samples
- **Standard deviation**: Depth variability
- **Sample count**: Number of valid measurements

### 3. Output Format

```json
{
  "metadata": {
    "source": "EMODnet Bathymetry",
    "url": "https://portal.emodnet-bathymetry.eu/",
    "method": "Point sampling using WMS GetFeatureInfo",
    "unit": "meters below sea level",
    "generated": "2025-10-06T10:00:00",
    "bbt_count": 11,
    "valid_count": 11
  },
  "statistics": {
    "Archipelago": {
      "min_depth_m": 5.2,
      "max_depth_m": 45.8,
      "avg_depth_m": 25.3,
      "std_depth_m": 12.1,
      "sample_count": 234
    },
    ...
  }
}
```

## Performance

### Execution Time
- **Per BBT area**: ~30-60 seconds (depends on polygon size and API response time)
- **Total (11 BBTs)**: ~5-10 minutes
- **API requests**: ~100-600 per BBT (only for points inside polygon)

### Sampling Density Trade-offs

| Samples | Points/BBT | Accuracy | Time/BBT |
|---------|------------|----------|----------|
| 15      | Up to 225  | Lower    | ~20s     |
| 25      | Up to 625  | Good     | ~45s     |
| 30      | Up to 900  | Better   | ~60s     |
| 40      | Up to 1600 | Best     | ~120s    |

## Integration with App

### 1. Automatic Loading

The Flask app automatically loads bathymetry statistics if available:

```python
# In app.py
BATHYMETRY_STATS_FILE = "data/bbt_bathymetry_stats.json"

if Path(BATHYMETRY_STATS_FILE).exists():
    with open(BATHYMETRY_STATS_FILE) as f:
        bathymetry_stats = json.load(f)
```

### 2. Display in BBT Popup

Statistics are displayed in the BBT information popup:

```html
<div class="depth-info">
  <h4>Bathymetry</h4>
  <table>
    <tr>
      <td>Min Depth:</td>
      <td>5.2 m</td>
    </tr>
    <tr>
      <td>Max Depth:</td>
      <td>45.8 m</td>
    </tr>
    <tr>
      <td>Avg Depth:</td>
      <td>25.3 m</td>
    </tr>
  </table>
</div>
```

## Deployment

### Production Workflow

1. **Calculate statistics** (run once or periodically):
   ```bash
   ./calculate_bathymetry.sh
   ```

2. **Verify output**:
   ```bash
   cat data/bbt_bathymetry_stats.json
   ```

3. **Deploy with app**:
   ```bash
   ./deploy_production.sh
   ```

### Automated Updates

Add to cron for periodic updates:

```bash
# Update bathymetry stats monthly
0 0 1 * * cd /path/to/EMODNET_PyDeck && ./calculate_bathymetry.sh
```

## Troubleshooting

### Common Issues

**1. No data returned for BBT area**
- Check if BBT polygon is in correct CRS (should be EPSG:4326)
- Verify EMODnet WMS service is accessible
- Try increasing sample density with `--samples 30`

**2. Slow execution**
- Reduce sampling density: `--samples 15`
- Check network connection to EMODnet
- Run during off-peak hours

**3. Import errors**
```bash
# Ensure dependencies are installed
pip install geopandas numpy requests
```

**4. Permission denied**
```bash
chmod +x calculate_bathymetry.sh
chmod +x scripts/calculate_bathymetry.py
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
./calculate_bathymetry.sh --verbose
```

Or directly with Python:

```bash
python scripts/calculate_bathymetry.py --verbose --samples 10
```

## File Structure

```
EMODNET_PyDeck/
├── calculate_bathymetry.sh              # Shell wrapper script
├── scripts/
│   └── calculate_bathymetry.py          # CLI tool
├── src/
│   └── emodnet_viewer/
│       └── utils/
│           └── bathymetry_calculator.py # Core library
├── data/
│   ├── vector/
│   │   └── BBT.gpkg                     # Input: BBT polygons
│   └── bbt_bathymetry_stats.json        # Output: Statistics
└── BATHYMETRY_TOOL.md                   # This documentation
```

## Dependencies

### Required
- Python 3.9+
- geopandas >= 1.1.1
- numpy >= 1.24.0
- requests >= 2.32.3
- shapely (via geopandas)

### Optional
- fiona >= 1.10.1 (for GPKG support, usually included with geopandas)
- pyproj >= 3.7.1 (for CRS transformations)

## License & Attribution

**Tool**: Part of MARBEFES BBT Database Project
**Data Source**: EMODnet Bathymetry
**License**: Same as main project

### Citation

When using bathymetry data, please cite:

> EMODnet Bathymetry Consortium (2024). EMODnet Digital Bathymetry (DTM).
> https://doi.org/10.12770/ff3aff8a-cff1-44a3-a2c8-1910bf109f85

## Support

For issues or questions:
1. Check this documentation
2. Review logs with `--verbose` flag
3. Verify EMODnet service status: https://portal.emodnet-bathymetry.eu/
4. Check project issues on GitHub
