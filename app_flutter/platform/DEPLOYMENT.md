# FoodVision Platform Configuration & Deployment Guide

## Overview
This directory contains platform-specific configuration and guidance for deploying FoodVision on both Android and iOS.

### Structure
```
platform/
  android/          # Android-specific native code & docs
  ios/              # iOS-specific native code & docs
```

---

## Android Configuration

### Setup (Windows/macOS/Linux)
```bash
flutter doctor -v                    # Verify Android SDK, emulator, etc.
cd app_flutter
flutter pub get
flutter run -d emulator              # or use -d <device_id>
```

### Key Configuration Files
- `android/build.gradle` — Root Gradle build config (SDK versions 21–34)
- `android/app/build.gradle` — App-level Gradle (minSdk: 21, targetSdk: 34)
- `android/app/src/main/AndroidManifest.xml` — App declarations + permissions
  - `CAMERA` — required for food photo capture
  - `READ/WRITE_EXTERNAL_STORAGE` — photo file access
  - `INTERNET` — backend API calls
- `android/gradle.properties` — Gradle JVM args, AndroidX, R8

### Permissions
Request these at runtime (Android 6.0+):
```kotlin
// Example in Dart via permission_handler plugin
final cameraStatus = await Permission.camera.request();
final storageStatus = await Permission.storage.request();
```

### Debug Build
```bash
flutter run -d emulator -v
```

### Release Build
```bash
# Generate keystore (one-time)
keytool -genkey -v -keystore ~/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias foodvision

# Build AAB (Play Store)
flutter build appbundle --release

# Or APK (standalone)
flutter build apk --release
```

---

## iOS Configuration

### Setup (macOS only)
```bash
flutter doctor -v                    # Verify Xcode, iOS SDK
cd app_flutter
flutter pub get
flutter run -d simulator             # or use -d <device_id>
```

### Key Configuration Files
- `ios/Runner/Info.plist` — App bundle info + permissions
  - `NSCameraUsageDescription` — "FoodVision needs camera access…"
  - `NSPhotoLibraryUsageDescription` — "FoodVision needs access to your library…"
  - MinimumOSVersion: 12.0 (iPad air, iPhone 6+)
- `ios/Podfile` — CocoaPods dependency manager (platform iOS 12.0+)

### Permissions
iOS requires Info.plist keys (no runtime request needed for some):
- Camera: `AVCaptureDevice.requestAccess(for: .video)`
- Photos: `PHPhotoLibrary.requestAuthorization(_:)`

### Debug Build
```bash
flutter run -d simulator -v
```

### Release Build
```bash
# Requires Apple Developer account + provisioning profiles (in Xcode)
flutter build ios --release

# Archive in Xcode
open ios/Runner.xcworkspace
# Menu: Product → Archive → Distribute App
```

---

## Common Issues & Fixes

### Android
- **"Flutter SDK not found"** → Set `flutter.sdk` in `android/local.properties`
- **Camera not working** → Check `CAMERA` permission in AndroidManifest.xml
- **Build fails on Apple Silicon** → Add to `android/gradle.properties`:
  ```
  org.gradle.java.home=/path/to/java
  ```

### iOS
- **CocoaPods errors** → Run `cd ios && pod repo update && pod install`
- **Code signing issues** → Configure provisioning profiles in Xcode (targets → Signing & Capabilities)
- **Camera permission denied** → Ensure `NSCameraUsageDescription` is in Info.plist with a user-facing message

---

## Deployment Checklist

### Before Release
- [ ] Test on real Android device (min: Android 5.0)
- [ ] Test on real iOS device (min: iOS 12.0)
- [ ] Update version code/name in pubspec.yaml
- [ ] Run `flutter build appbundle/ipa` with `--release` flag
- [ ] Test signed APK/AAB/IPA locally

### Play Store (Android)
1. Create project in Google Play Console
2. Upload signed AAB
3. Fill store listing (description, screenshots, etc.)
4. Set up testing track (alpha/beta)
5. Request review

### App Store (iOS)
1. Create app in App Store Connect
2. Upload signed IPA via Transporter
3. Fill app information (description, screenshots, privacy)
4. Submit for review
5. Wait for Apple review (1–3 days)

---

## TODO (Future Milestones)

- [ ] **Milestone 3:** Configure real backend URL (currently hardcoded localhost)
- [ ] **Milestone 4:** Add app signing automation (fastlane or similar)
- [ ] **M4+:** Implement analytics (Firebase, Segment, etc.)
- [ ] **M4+:** Implement crash reporting (Crashlytics, Sentry)
- [ ] **M4+:** Deep linking for shared meals (optional)
