# Changelog

All notable changes to the MarineSABRES Demonstration Area Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - TBD (Production Release)

### Added
- Centralized version management in `__version__.py`
- Comprehensive version history tracking
- Development/Production version distinction
- Input validation for all layer name parameters
- Security logging for suspicious requests

### Changed
- **BREAKING**: Removed MARBEFES BBT factsheet functionality
- **BREAKING**: Removed vector data processing capabilities
- Cleaned up dependencies from 13 to 7 core packages
- Standardized project naming to "MarineSABRES Demonstration Area Tool"
- Updated deployment URL to laguna.ku.lt:5002
- Focused exclusively on 3 MarineSABRES research sites
- Simplified to WMS-only data sources

### Removed
- BBT factsheet API endpoints (`/api/factsheets`, `/api/factsheet/<name>`)
- Vector API endpoints (`/api/vector/*`)
- Bathymetry statistics functionality
- Dependencies: geopandas, fiona, pyproj, numpy, pyogrio
- Vector configuration from config.py
- Unused MARBEFES references

### Security
- Added layer name validation to prevent path traversal attacks
- Added XSS prevention in API endpoints
- Implemented security logging for rejected requests
- Defense-in-depth approach on all user inputs

### Performance
- Reduced package footprint by ~50% (dependency cleanup)
- Faster installation and smaller deployment size
- Simplified codebase for easier maintenance


## [1.3.0-dev] - 2025-10-16 (Development)

Development version with all changes listed above.


## [1.2.1] - 2025-01

### Added
- Input validation on API endpoints
- Python 3.12+ timezone-aware datetime support

### Changed
- Default host binding changed to 127.0.0.1 for development safety
- Flask-Caching updated to 2.3.1

### Fixed
- Deprecated `datetime.utcnow()` replaced with `datetime.now(timezone.utc)`


## [1.2.0] - 2025-01

### Added
- Factsheet data in-memory caching

### Changed
- Framework updates (Flask 3.1.2)

### Performance
- 86% faster factsheet API responses (from ~50ms to ~7ms)


## [1.1.0] - 2024

### Changed
- Flask: 2.3.3 → 3.1.2
- GeoPandas: 0.14.0 → 1.1.1
- Pytest: 7.4.2 → 8.4.2
- Black: 23.7.0 → 25.1.0
- Flake8: 6.0.0 → 7.3.0

### Security
- Updated Flask to address CVE-2024 vulnerabilities
- Added explicit Werkzeug dependency
- Updated requests library for security patches


## [1.0.0] - 2024

Initial release with:
- EMODnet WMS integration (Seabed Habitats + Human Activities)
- Interactive Leaflet map interface
- Research site navigation
- Layer selection and opacity controls
- Health monitoring endpoint
- Caching and rate limiting
