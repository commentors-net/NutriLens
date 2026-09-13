#!/usr/bin/env python3
"""
FoodVision Version Management Script
Bumps app version in pubspec.yaml, app_config.yaml, and records entry in VERSION_HISTORY.md.

Usage:
  python bump_version.py --type patch         # 0.1.0+1 -> 0.1.1+2
  python bump_version.py --type minor         # 0.1.0+1 -> 0.2.0+2
  python bump_version.py --type major         # 0.1.0+1 -> 1.0.0+2
  python bump_version.py --type build         # 0.1.0+1 -> 0.1.0+2
  python bump_version.py --set 0.2.0+5       # Explicit version
  python bump_version.py --get                # Print current version
"""

import argparse
import datetime
import io
import re
import sys
from pathlib import Path

# Ensure UTF-8 output on Windows consoles
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except AttributeError:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
APP_FLUTTER_DIR = REPO_ROOT / 'app_flutter'
PUBSPEC_PATH = APP_FLUTTER_DIR / 'pubspec.yaml'
APP_CONFIG_PATH = APP_FLUTTER_DIR / 'app_config.yaml'
VERSION_HISTORY_PATH = REPO_ROOT / 'VERSION_HISTORY.md'


def get_current_version():
    """Reads current version from pubspec.yaml."""
    if not PUBSPEC_PATH.exists():
        raise FileNotFoundError(f"pubspec.yaml not found at {PUBSPEC_PATH}")
    
    content = PUBSPEC_PATH.read_text(encoding='utf-8')
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', content, re.MULTILINE)
    if not match:
        raise ValueError("Could not parse version from pubspec.yaml (expected 'version: X.Y.Z+N')")
    return match.group(1), int(match.group(2))


def calculate_next_version(version_name, version_code, bump_type):
    """Calculates next semantic version and incremented build number."""
    major, minor, patch = map(int, version_name.split('.'))
    next_code = version_code + 1

    if bump_type == 'major':
        return f"{major + 1}.0.0", next_code
    elif bump_type == 'minor':
        return f"{major}.{minor + 1}.0", next_code
    elif bump_type == 'patch':
        return f"{major}.{minor}.{patch + 1}", next_code
    elif bump_type == 'build':
        return f"{major}.{minor}.{patch}", next_code
    else:
        raise ValueError(f"Unknown bump type: {bump_type}")


def update_pubspec(new_name, new_code):
    """Updates version in pubspec.yaml."""
    content = PUBSPEC_PATH.read_text(encoding='utf-8')
    new_version_str = f"version: {new_name}+{new_code}"
    updated_content = re.sub(r'^version:\s*\d+\.\d+\.\d+\+\d+', new_version_str, content, flags=re.MULTILINE)
    PUBSPEC_PATH.write_text(updated_content, encoding='utf-8')


def update_app_config(new_name, new_code):
    """Updates version documentation in app_config.yaml."""
    if not APP_CONFIG_PATH.exists():
        return
    content = APP_CONFIG_PATH.read_text(encoding='utf-8')
    content = re.sub(
        r'# Update these in pubspec\.yaml version field as:\s*\S+',
        f'# Update these in pubspec.yaml version field as: {new_name}+{new_code}',
        content
    )
    content = re.sub(
        r'# version_name:\s*\S+',
        f'# version_name: {new_name}',
        content
    )
    content = re.sub(
        r'# version_code:\s*\S+',
        f'# version_code: {new_code}',
        content
    )
    APP_CONFIG_PATH.write_text(content, encoding='utf-8')


def append_version_history(old_name, old_code, new_name, new_code, bump_reason=""):
    """Appends an entry to VERSION_HISTORY.md."""
    today = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = (
        f"| {new_name}+{new_code} | {new_name} | {new_code} | {today} | "
        f"{bump_reason or 'Automated release bump'} | `{old_name}+{old_code}` |\n"
    )
    
    if not VERSION_HISTORY_PATH.exists():
        header = (
            "# FoodVision Version History & Release Tracker\n\n"
            "This log tracks all version increments across Android and iOS builds.\n\n"
            "| Version | Version Name | Build Code | Date (UTC/Local) | Notes / Trigger | Previous Version |\n"
            "| :--- | :--- | :--- | :--- | :--- | :--- |\n"
        )
        VERSION_HISTORY_PATH.write_text(header + entry, encoding='utf-8')
    else:
        content = VERSION_HISTORY_PATH.read_text(encoding='utf-8')
        if "| Version | Version Name |" in content:
            lines = content.splitlines(keepends=True)
            table_idx = -1
            for i, line in enumerate(lines):
                if line.startswith("| :---"):
                    table_idx = i + 1
                    break
            if table_idx != -1:
                lines.insert(table_idx, entry)
                VERSION_HISTORY_PATH.write_text("".join(lines), encoding='utf-8')
            else:
                VERSION_HISTORY_PATH.write_text(content + entry, encoding='utf-8')
        else:
            VERSION_HISTORY_PATH.write_text(content + "\n" + entry, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description="FoodVision Version Management")
    parser.add_argument('--get', action='store_true', help="Print current version")
    parser.add_argument('--type', choices=['patch', 'minor', 'major', 'build'],
                        help="Bump type: patch (0.1.1), minor (0.2.0), major (1.0.0), build (0.1.0+2)")
    parser.add_argument('--set', type=str, help="Explicit version string in format X.Y.Z+N")
    parser.add_argument('--note', type=str, default="", help="Note / trigger reason for the version bump")
    parser.add_argument('--quiet', action='store_true', help="Only print the new version")

    args = parser.parse_args()

    curr_name, curr_code = get_current_version()

    if args.get:
        if args.quiet:
            print(f"{curr_name}+{curr_code}")
        else:
            print(f"Current version: {curr_name}+{curr_code} (name: {curr_name}, code: {curr_code})")
        return 0

    if not args.type and not args.set:
        parser.print_help()
        return 1

    if args.set:
        match = re.match(r'^(\d+\.\d+\.\d+)\+(\d+)$', args.set)
        if not match:
            print(f"Error: Invalid version format '{args.set}'. Expected format: X.Y.Z+N (e.g. 0.2.0+2)")
            return 1
        new_name, new_code = match.group(1), int(match.group(2))
    else:
        new_name, new_code = calculate_next_version(curr_name, curr_code, args.type)

    # Perform updates
    update_pubspec(new_name, new_code)
    update_app_config(new_name, new_code)
    append_version_history(curr_name, curr_code, new_name, new_code, args.note)

    if args.quiet:
        print(f"{new_name}+{new_code}")
    else:
        print(f"✅ Version bumped successfully:")
        print(f"   Previous: {curr_name}+{curr_code}")
        print(f"   New:      {new_name}+{new_code}")
        print(f"   Updated:  pubspec.yaml, app_config.yaml, VERSION_HISTORY.md")

    return 0


if __name__ == '__main__':
    sys.exit(main())
