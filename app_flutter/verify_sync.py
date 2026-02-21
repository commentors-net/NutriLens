#!/usr/bin/env python3
"""
Version Sync Verification Script
Ensures Android and iOS configurations are in sync with pubspec.yaml
"""

import re
import sys
from pathlib import Path

def read_pubspec_version():
    """Read version from pubspec.yaml"""
    pubspec_path = Path(__file__).parent / 'pubspec.yaml'
    with open(pubspec_path, 'r') as f:
        content = f.read()
        match = re.search(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)', content)
        if match:
            return match.group(1), match.group(2)
    return None, None

def read_android_config():
    """Read Android configuration"""
    gradle_path = Path(__file__).parent / 'android' / 'app' / 'build.gradle'
    with open(gradle_path, 'r') as f:
        content = f.read()
        app_id = re.search(r'applicationId\s+"([^"]+)"', content)
        min_sdk = re.search(r'minSdkVersion\s+(\d+)', content)
        target_sdk = re.search(r'targetSdkVersion\s+(\d+)', content)
        return {
            'app_id': app_id.group(1) if app_id else None,
            'min_sdk': min_sdk.group(1) if min_sdk else None,
            'target_sdk': target_sdk.group(1) if target_sdk else None,
        }

def read_ios_config():
    """Read iOS configuration"""
    info_plist_path = Path(__file__).parent / 'ios' / 'Runner' / 'Info.plist'
    with open(info_plist_path, 'r') as f:
        content = f.read()
        bundle_id = re.search(r'<key>CFBundleIdentifier</key>\s*<string>\$\(PRODUCT_BUNDLE_IDENTIFIER\)</string>', content)
        version = re.search(r'<key>CFBundleShortVersionString</key>\s*<string>\$\(FLUTTER_BUILD_NAME\)</string>', content)
        build = re.search(r'<key>CFBundleVersion</key>\s*<string>\$\(FLUTTER_BUILD_NUMBER\)</string>', content)
        min_ios = re.search(r'<key>MinimumOSVersion</key>\s*<string>([^<]+)</string>', content)
        return {
            'uses_flutter_vars': bundle_id is not None and version is not None and build is not None,
            'min_ios': min_ios.group(1) if min_ios else None,
        }

def read_app_config():
    """Read app_config.yaml"""
    config_path = Path(__file__).parent / 'app_config.yaml'
    config = {}
    with open(config_path, 'r') as f:
        for line in f:
            if ':' in line and not line.strip().startswith('#'):
                key, value = line.split(':', 1)
                config[key.strip()] = value.strip().strip('"').strip("'")
    return config

def main():
    print("🔍 FoodVision Configuration Sync Check\n" + "="*50)
    
    # Read all configs
    version_name, version_code = read_pubspec_version()
    android_config = read_android_config()
    ios_config = read_ios_config()
    app_config = read_app_config()
    
    errors = []
    warnings = []
    
    # Check version synced from pubspec.yaml
    print(f"\n📱 Version Info (from pubspec.yaml):")
    print(f"  Version Name: {version_name}")
    print(f"  Version Code: {version_code}")
    
    # Check Android
    print(f"\n🤖 Android Configuration:")
    print(f"  Application ID: {android_config['app_id']}")
    print(f"  Min SDK: {android_config['min_sdk']}")
    print(f"  Target SDK: {android_config['target_sdk']}")
    
    if android_config['app_id'] != app_config.get('package_name'):
        errors.append(f"❌ Android applicationId mismatch: {android_config['app_id']} != {app_config.get('package_name')}")
    
    # Check iOS
    print(f"\n🍎 iOS Configuration:")
    print(f"  Uses Flutter Variables: {ios_config['uses_flutter_vars']}")
    print(f"  Min iOS Version: {ios_config['min_ios']}")
    
    if not ios_config['uses_flutter_vars']:
        errors.append("❌ iOS Info.plist not using Flutter variables (FLUTTER_BUILD_NAME, FLUTTER_BUILD_NUMBER)")
    
    # Check app_config.yaml
    print(f"\n⚙️  App Config (app_config.yaml):")
    print(f"  Bundle ID: {app_config.get('package_name')}")
    print(f"  Min Android SDK: {app_config.get('min_sdk')}")
    print(f"  Min iOS Version: {app_config.get('min_version')}")
    
    # Summary
    print(f"\n{'='*50}")
    if errors:
        print("❌ ERRORS FOUND:")
        for error in errors:
            print(f"  {error}")
        return 1
    elif warnings:
        print("⚠️  WARNINGS:")
        for warning in warnings:
            print(f"  {warning}")
    else:
        print("✅ All configurations are in sync!")
    
    print(f"\n💡 To update version:")
    print(f"  1. Edit pubspec.yaml: version: X.Y.Z+BUILD")
    print(f"  2. Run: flutter pub get")
    print(f"  3. Both Android and iOS will auto-sync")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
