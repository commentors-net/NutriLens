# FoodVision Platform Configuration Sync

## Overview
This directory maintains synchronized configuration across Android and iOS platforms.

### Single Source of Truth: `pubspec.yaml`
All version information is managed in `pubspec.yaml`:
```yaml
version: 0.1.0+1
       # ^^^^^ ^
       # |     └─ Build number (Android versionCode, iOS CFBundleVersion)
       # └─────── Version name (Android versionName, iOS CFBundleShortVersionString)
```

---

## Configuration Files

### 1. `app_config.yaml`
Central configuration reference for app identity and platform settings:
- App name, bundle ID, package name
- Platform minimum versions (Android minSdk, iOS deployment target)
- Build tool versions
- Permission documentation

**This is a reference file.** Actual values are read from `pubspec.yaml` by Flutter build tools.

### 2. `pubspec.yaml`
Primary configuration for Flutter app:
- `name`: App package name
- `version`: Version name + build number
- `description`: App description

### 3. `android/app/build.gradle`
Android-specific configuration that **auto-syncs from pubspec.yaml**:
```gradle
applicationId "com.foodvision.app"  // Must match iOS bundle ID
versionCode flutterVersionCode       // From pubspec.yaml build number
versionName flutterVersionName       // From pubspec.yaml version name
```

### 4. `ios/Runner/Info.plist`
iOS-specific configuration that **auto-syncs from pubspec.yaml**:
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>  <!-- Set in Xcode -->

<key>CFBundleShortVersionString</key>
<string>$(FLUTTER_BUILD_NAME)</string>  <!-- From pubspec.yaml -->

<key>CFBundleVersion</key>
<string>$(FLUTTER_BUILD_NUMBER)</string>  <!-- From pubspec.yaml -->
```

---

## How to Update Version

### 1. Edit `pubspec.yaml`
```yaml
version: 0.2.0+2
```

### 2. Run Flutter command
```bash
flutter pub get
```

### 3. Verify sync (optional)
```bash
python verify_sync.py
```

### 4. Build
```bash
# Android
flutter build appbundle --release

# iOS
flutter build ios --release
```

**Both platforms will automatically use the new version!**

---

## Configuration Checklist

When setting up for the first time or making changes:

- [ ] **Bundle ID/Application ID** matches across platforms
  - Android: `android/app/build.gradle` → `applicationId`
  - iOS: Set in Xcode → Runner target → Bundle Identifier
  - Must be: `com.foodvision.app`

- [ ] **App Name** is consistent
  - Android: `android/app/src/main/AndroidManifest.xml` → `android:label`
  - iOS: `ios/Runner/Info.plist` → `CFBundleDisplayName`
  - Should be: `FoodVision`

- [ ] **Version synced from pubspec.yaml**
  - Android: `build.gradle` uses `flutterVersionCode` and `flutterVersionName`
  - iOS: `Info.plist` uses `$(FLUTTER_BUILD_NAME)` and `$(FLUTTER_BUILD_NUMBER)`

- [ ] **Permissions documented** in `app_config.yaml`
  - Android: Check `AndroidManifest.xml`
  - iOS: Check `Info.plist` usage descriptions

---

## Verification Script

Run `python verify_sync.py` to check:
- ✅ Version numbers match
- ✅ Bundle IDs match
- ✅ iOS uses Flutter variables
- ✅ Platform minimums align with app_config.yaml

---

## Common Issues

### Issue: Versions not syncing
**Solution:** Run `flutter clean && flutter pub get`

### Issue: iOS shows wrong version
**Solution:** Verify `Info.plist` uses `$(FLUTTER_BUILD_NAME)` not hardcoded strings

### Issue: Android and iOS have different bundle IDs
**Solution:** 
1. Update `android/app/build.gradle` → `applicationId`
2. Update in Xcode: Runner target → Signing & Capabilities → Bundle Identifier
3. Update `app_config.yaml` for reference

### Issue: Build number not incrementing
**Solution:** Increment number after `+` in `pubspec.yaml` version field

---

## Best Practices

✅ **DO:**
- Always update version in `pubspec.yaml` only
- Run `flutter pub get` after version changes
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Increment build number with each release
- Keep bundle ID consistent across platforms

❌ **DON'T:**
- Hardcode versions in `Info.plist`
- Manually edit version in `build.gradle` (it auto-syncs)
- Use different bundle IDs for Android and iOS
- Forget to increment build number for new releases

---

## Release Workflow

### 1. Prepare Release
```bash
# Update version in pubspec.yaml
version: 1.0.0+10

# Sync dependencies
flutter pub get

# Verify sync
python verify_sync.py
```

### 2. Build Android
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 3. Build iOS
```bash
flutter build ios --release
# Then archive in Xcode: Product → Archive
```

### 4. Upload
- Android: Google Play Console → Release → Upload AAB
- iOS: Xcode → Organizer → Distribute App

Both builds will have **identical version numbers** from `pubspec.yaml`!

---

## Summary

| Property | Source | Android | iOS |
|----------|--------|---------|-----|
| Version Name | `pubspec.yaml` | `versionName` | `CFBundleShortVersionString` |
| Build Number | `pubspec.yaml` | `versionCode` | `CFBundleVersion` |
| App Name | Manual | `AndroidManifest.xml` | `Info.plist` |
| Bundle ID | Manual | `applicationId` | `CFBundleIdentifier` |

**Key Point:** Only edit `pubspec.yaml` for version changes. Other files auto-sync via Flutter build tools.
