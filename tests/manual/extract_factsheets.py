#!/usr/bin/env python3
"""
Extract BBT Factsheet Data to JSON

This script reads individual BBT factsheet files (Excel/ODS) from the FactSheets directory
and extracts structured data into a consolidated JSON format.
"""

import pandas as pd
import json
import os
from pathlib import Path
from typing import Dict, List, Any
import warnings

warnings.filterwarnings('ignore')

# Factsheet directory
FACTSHEETS_DIR = Path("FactSheets")
OUTPUT_FILE = Path("data/bbt_factsheets.json")


def extract_excel_data(file_path: Path) -> Dict[str, Any]:
    """
    Extract data from an Excel or ODS factsheet file.

    Args:
        file_path: Path to the factsheet file

    Returns:
        Dictionary containing extracted data
    """
    print(f"Processing: {file_path.name}")

    bbt_name = file_path.stem.replace("FactSheet_", "").replace("FactSheet ", "").replace("Factsheet-", "").replace("-", " ")

    data = {
        "name": bbt_name,
        "source_file": file_path.name,
        "data": {}
    }

    try:
        # Read the file (works for both .xlsx and .ods)
        if file_path.suffix == '.ods':
            # For ODS files, use odfpy engine
            try:
                df = pd.read_excel(file_path, engine='odf', sheet_name=0)
            except Exception as e:
                print(f"  ⚠️ Could not read ODS file with odf engine: {e}")
                print(f"  Trying openpyxl...")
                df = pd.read_excel(file_path, sheet_name=0)
        else:
            df = pd.read_excel(file_path, sheet_name=0)

        # Extract all non-empty cells as key-value pairs
        for idx, row in df.iterrows():
            # Skip completely empty rows
            if row.isna().all():
                continue

            # Try to find key-value pairs
            row_values = row.dropna().tolist()

            if len(row_values) >= 2:
                # First column is likely the key, rest are values
                key = str(row_values[0]).strip()
                values = [str(v).strip() for v in row_values[1:]]

                # Store single values as strings, multiple as arrays
                if len(values) == 1:
                    data["data"][key] = values[0]
                else:
                    data["data"][key] = values
            elif len(row_values) == 1:
                # Single value - might be a header or note
                value = str(row_values[0]).strip()
                if value and len(value) > 3:  # Ignore very short entries
                    if "notes" not in data["data"]:
                        data["data"]["notes"] = []
                    data["data"]["notes"].append(value)

        print(f"  ✅ Extracted {len(data['data'])} fields")

    except Exception as e:
        print(f"  ❌ Error processing file: {e}")
        data["error"] = str(e)

    return data


def extract_all_factsheets() -> List[Dict[str, Any]]:
    """
    Extract data from all factsheet files.

    Returns:
        List of dictionaries containing BBT factsheet data
    """
    factsheets = []

    # Find all Excel and ODS files (excluding template)
    factsheet_files = [
        f for f in FACTSHEETS_DIR.glob("*")
        if f.suffix in ['.xlsx', '.ods', '.xls']
        and 'Template' not in f.name
        and 'Task3.1' not in f.name
    ]

    print(f"Found {len(factsheet_files)} factsheet files\n")

    for file_path in sorted(factsheet_files):
        factsheet_data = extract_excel_data(file_path)
        factsheets.append(factsheet_data)

    return factsheets


def save_to_json(factsheets: List[Dict[str, Any]], output_file: Path):
    """
    Save extracted factsheet data to JSON file.

    Args:
        factsheets: List of factsheet data dictionaries
        output_file: Path to output JSON file
    """
    # Create output directory if it doesn't exist
    output_file.parent.mkdir(parents=True, exist_ok=True)

    # Prepare output structure
    output = {
        "metadata": {
            "total_bbts": len(factsheets),
            "source_directory": str(FACTSHEETS_DIR),
            "extraction_date": pd.Timestamp.now().isoformat()
        },
        "bbts": factsheets
    }

    # Save to JSON with pretty formatting
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Saved {len(factsheets)} BBT factsheets to: {output_file}")
    print(f"   File size: {output_file.stat().st_size:,} bytes")


def main():
    """Main execution function."""
    print("=" * 60)
    print("BBT Factsheet Data Extraction")
    print("=" * 60)
    print()

    # Check if factsheets directory exists
    if not FACTSHEETS_DIR.exists():
        print(f"❌ Error: FactSheets directory not found: {FACTSHEETS_DIR}")
        return

    # Extract all factsheet data
    factsheets = extract_all_factsheets()

    if not factsheets:
        print("❌ No factsheet files found!")
        return

    # Save to JSON
    save_to_json(factsheets, OUTPUT_FILE)

    # Print summary
    print("\n" + "=" * 60)
    print("Summary by BBT:")
    print("=" * 60)
    for fs in factsheets:
        field_count = len(fs.get("data", {}))
        status = "❌ Error" if "error" in fs else f"✅ {field_count} fields"
        print(f"  {fs['name']:30} {status}")


if __name__ == "__main__":
    main()
