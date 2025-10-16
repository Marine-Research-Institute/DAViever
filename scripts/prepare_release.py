#!/usr/bin/env python3
"""
Release preparation script for MarineSABRES Demonstration Area Tool

This script helps prepare a production release by:
1. Updating version numbers
2. Updating release dates
3. Creating git tags
4. Generating release notes
"""

import sys
import os
from pathlib import Path
from datetime import date

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from __version__ import __version__, __production_version__, VERSION_HISTORY


def update_version_for_production():
    """Update __version__.py for production release"""

    version_file = PROJECT_ROOT / "__version__.py"
    today = date.today().isoformat()

    print(f"🚀 Preparing Production Release")
    print(f"   Current Dev Version: {__version__}")
    print(f"   Target Prod Version: {__production_version__}")
    print(f"   Release Date: {today}")
    print()

    response = input(f"Proceed with release {__production_version__}? (yes/no): ")
    if response.lower() != "yes":
        print("❌ Release cancelled")
        return False

    # Read current version file
    with open(version_file, 'r') as f:
        content = f.read()

    # Update version strings
    content = content.replace(
        f'__version__ = "{__version__}"',
        f'__version__ = "{__production_version__}"'
    )
    content = content.replace(
        '__version_info__ = (1, 3, 0, "dev")',
        '__version_info__ = (1, 3, 0)'
    )
    content = content.replace(
        f'__release_date__ = "2025-10-16"',
        f'__release_date__ = "{today}"'
    )
    content = content.replace(
        '__status__ = "Development"',
        '__status__ = "Stable"'
    )
    content = content.replace(
        '__production_release_date__ = "TBD"',
        f'__production_release_date__ = "{today}"'
    )

    # Write updated file
    with open(version_file, 'w') as f:
        f.write(content)

    print(f"✅ Updated {version_file}")
    return True


def update_changelog():
    """Update CHANGELOG.md with production release date"""

    changelog_file = PROJECT_ROOT / "CHANGELOG.md"
    today = date.today().isoformat()

    with open(changelog_file, 'r') as f:
        content = f.read()

    # Update release header
    content = content.replace(
        f"## [1.3.0] - TBD (Production Release)",
        f"## [1.3.0] - {today} (Production Release)"
    )

    with open(changelog_file, 'w') as f:
        f.write(content)

    print(f"✅ Updated {changelog_file}")


def update_html_template():
    """Update templates/index.html version display"""

    template_file = PROJECT_ROOT / "templates" / "index.html"
    today = date.today().strftime("%B %d, %Y")

    with open(template_file, 'r') as f:
        content = f.read()

    # Update version and status
    content = content.replace(
        '<td id="app-version">1.3.0-dev</td>',
        '<td id="app-version">1.3.0</td>'
    )
    content = content.replace(
        '<td id="app-release-date">October 16, 2025</td>',
        f'<td id="app-release-date">{today}</td>'
    )
    content = content.replace(
        '<span class="status-badge" id="version-status">Development</span>',
        '<span class="status-badge status-healthy" id="version-status">Stable</span>'
    )

    with open(template_file, 'w') as f:
        f.write(content)

    print(f"✅ Updated {template_file}")


def generate_release_notes():
    """Generate release notes from CHANGELOG"""

    print("\n📋 Release Notes for v1.3.0:")
    print("=" * 60)

    # Get changes from VERSION_HISTORY
    if "1.3.0-dev" in VERSION_HISTORY:
        changes = VERSION_HISTORY["1.3.0-dev"]["changes"]
        for change in changes:
            print(f"  • {change}")

    print("\n" + "=" * 60)
    print("\n✅ Release preparation complete!")
    print("\nNext steps:")
    print("  1. Review changes: git diff")
    print("  2. Commit changes: git commit -am 'Release v1.3.0'")
    print("  3. Create tag: git tag -a v1.3.0 -m 'Release v1.3.0'")
    print("  4. Push changes: git push && git push --tags")
    print("  5. Deploy to production server")
    print()


def main():
    """Main release preparation workflow"""
    print("\n" + "=" * 60)
    print("  MarineSABRES DA Tool - Release Preparation")
    print("=" * 60 + "\n")

    if update_version_for_production():
        update_changelog()
        update_html_template()
        generate_release_notes()
    else:
        print("\n⚠️  No changes made")


if __name__ == "__main__":
    main()
