# Version Information

## Current Version

**Development Version:** `1.3.0-dev`  
**Release Date:** October 16, 2025  
**Status:** Development  

**Production Version:** `1.3.0` (To Be Released)  
**Production Date:** TBD

---

## Version Management

This project uses centralized version management through `__version__.py`:

```python
from __version__ import __version__, get_version_info

# Get version string
print(__version__)  # "1.3.0-dev"

# Get complete version information
info = get_version_info()
```

### Files Containing Version Information

1. **`__version__.py`** - Central version tracking (source of truth)
2. **`app.py`** - Imports version from `__version__.py`
3. **`templates/index.html`** - Displays version in UI (updated automatically via health API)
4. **`CHANGELOG.md`** - Version history and release notes
5. **`CLAUDE.md`** - Documentation with version references

---

## Development vs Production Versions

### Development (Current)
- Version: `1.3.0-dev`
- Status: "Development"
- Purpose: Active development, testing, feature additions
- Stability: May contain breaking changes

### Production (Future)
- Version: `1.3.0`
- Status: "Stable"
- Purpose: Deployed to production servers
- Stability: Stable, tested, production-ready

---

## Release Process

### Preparing a Production Release

Use the automated release preparation script:

```bash
cd /home/razinka/OneDrive/HORIZON_EUROPE/Marine-SABRES/DAViwer/DAViever
python scripts/prepare_release.py
```

This script will:
1. Update version from `1.3.0-dev` → `1.3.0`
2. Update status from "Development" → "Stable"
3. Set production release date
4. Update CHANGELOG.md
5. Update HTML template
6. Generate release notes

### Manual Release Steps

If you prefer manual control:

1. **Update `__version__.py`:**
   ```python
   __version__ = "1.3.0"
   __version_info__ = (1, 3, 0)
   __release_date__ = "2025-XX-XX"
   __status__ = "Stable"
   __production_release_date__ = "2025-XX-XX"
   ```

2. **Update `CHANGELOG.md`:**
   ```markdown
   ## [1.3.0] - 2025-XX-XX (Production Release)
   ```

3. **Update `templates/index.html`:**
   ```html
   <td id="app-version">1.3.0</td>
   <td id="app-release-date">Month Day, Year</td>
   <span class="status-badge status-healthy" id="version-status">Stable</span>
   ```

4. **Commit and Tag:**
   ```bash
   git add .
   git commit -m "Release v1.3.0"
   git tag -a v1.3.0 -m "Release v1.3.0"
   git push && git push --tags
   ```

5. **Deploy to Production:**
   ```bash
   # Using Gunicorn
   gunicorn -c gunicorn.conf.py app:app
   
   # Or using systemd
   sudo systemctl restart flaskapp
   ```

---

## Version History

### v1.3.0-dev (October 16, 2025) - Current Development

**Major Changes:**
- Removed MARBEFES BBT factsheet functionality
- Removed vector data processing (geopandas, fiona, pyproj, numpy)
- Cleaned up dependencies (13 → 7 core packages)
- Added comprehensive input validation
- Standardized project naming to MarineSABRES
- Focused on 3 research sites only

**Security Improvements:**
- Input validation for layer names
- XSS prevention in API endpoints
- Security logging for suspicious requests

**Performance Improvements:**
- 50% smaller dependency footprint
- Faster installation time
- Simplified codebase

### v1.2.1 (January 2025)
- Security enhancements (localhost binding)
- Python 3.12+ compatibility
- Flask-Caching 2.3.1 update

### v1.2.0 (January 2025)
- Factsheet caching (86% performance improvement)
- Flask 3.1.2 update

### v1.1.0 (2024)
- Framework updates
- Security patches

### v1.0.0 (2024)
- Initial release

---

## Checking Version at Runtime

### Via Health API
```bash
curl http://localhost:5002/health | jq '.version'
```

### Via Python
```python
from __version__ import __version__, __status__
print(f"Version: {__version__} ({__status__})")
```

### Via Browser
Open the application and click the ⓘ icon in the header to see version information modal.

---

## Version Numbering Scheme

This project follows [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH[-SUFFIX]
  1  .  3  .  0  - dev

MAJOR: Breaking changes (incompatible API changes)
MINOR: New features (backward-compatible)
PATCH: Bug fixes (backward-compatible)
SUFFIX: dev (development), alpha, beta, rc (release candidate)
```

---

## Questions?

- **Development:** Use `1.3.0-dev` for ongoing development
- **Production:** Wait for `1.3.0` stable release
- **Issues:** See CHANGELOG.md for known issues
- **Updates:** Check GitHub releases for new versions
