# FoodVision Quick Start Guide

## Initial Setup

### 1. Prerequisites
- **Flutter SDK** (latest stable)
- **Android Studio** or VS Code with Flutter extension
- **Xcode** (macOS only, for iOS)
- **Python 3.7+** (for backend and sync verification)

### 2. Clone & Setup
```bash
cd NutriLens
flutter doctor -v  # Verify Flutter setup
```

### 3. Install Dependencies

#### Flutter App
```bash
cd app_flutter
flutter pub get
```

#### Backend
```bash
cd backend
python -m venv .venv

# Windows:
.\.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
```

---

## Running the App

### Android
```bash
cd app_flutter
flutter run -d emulator
# or specify device: flutter devices, then flutter run -d <device_id>
```

### iOS (macOS only)
```bash
cd app_flutter
flutter run -d simulator
# or: open -a Simulator, then flutter run
```

### Backend (Development)
```bash
cd backend
# Activate venv first (see above)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
# API will be at: http://localhost:8000
# API docs: http://localhost:8000/docs
```

---

## Version Management

### Update Version (Before Release)
1. Edit `app_flutter/pubspec.yaml`:
   ```yaml
   version: 0.2.0+2  # MAJOR.MINOR.PATCH+BUILD
   ```

2. Sync both platforms:
   ```bash
   cd app_flutter
   flutter pub get
   ```

3. Verify sync:
   ```bash
   python verify_sync.py
   # or Windows: verify_sync.bat
   ```

**Both Android and iOS will now have version 0.2.0 (build 2)!**

---

## Configuration Files

### App Identity (Must Match!)
- **Bundle ID/Package Name:** `com.foodvision.app`
- **App Name:** `FoodVision`

Check these files:
- `app_flutter/app_config.yaml` — central reference
- `app_flutter/android/app/build.gradle` — `applicationId`
- Xcode → Runner target → Bundle Identifier

### Environment Variables

#### Backend
```bash
cd backend
cp .env.example .env
# Edit .env with your settings
```

#### Android Signing (for release builds)
```bash
cd app_flutter/android
cp key.properties.example key.properties
# Edit key.properties with your keystore info
```

---

## Building for Release

### Android (AAB for Play Store)
```bash
cd app_flutter
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Android (APK for direct install)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS (requires macOS + Xcode)
```bash
flutter build ios --release
# Then open in Xcode: open ios/Runner.xcworkspace
# Product → Archive → Distribute App
```

---

## Testing Backend Locally

### 1. Start Backend
```bash
cd backend
# Activate venv
uvicorn app.main:app --reload
```

### 2. Test Health Check
```bash
curl http://localhost:8000/health
# Should return: {"status":"ok"}
```

### 3. Test Analyze Endpoint
```bash
# Using curl (example with dummy images)
curl -X POST http://localhost:8000/meals/analyze \
  -F "images=@photo1.jpg" \
  -F "images=@photo2.jpg" \
  -F "images=@photo3.jpg" \
  -F 'metadata={"client":{"platform":"test"}}'
```

### 4. View API Docs
Open browser: http://localhost:8000/docs

---

## Common Issues

### Flutter: SDK not found
```bash
# Set Flutter SDK path
flutter config --android-sdk <path-to-android-sdk>
```

### Android: Gradle build fails
```bash
cd app_flutter/android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### iOS: CocoaPods issues
```bash
cd app_flutter/ios
pod repo update
pod install
cd ..
flutter clean
flutter pub get
```

### Backend: Module not found
```bash
cd backend
# Ensure venv is activated
pip install -r requirements.txt
```

### Config not syncing
```bash
cd app_flutter
flutter clean
flutter pub get
python verify_sync.py
```

---

## Development Workflow

### 1. Start Backend (Terminal 1)
```bash
cd backend
.\.venv\Scripts\activate  # or source .venv/bin/activate
uvicorn app.main:app --reload
```

### 2. Start Flutter App (Terminal 2)
```bash
cd app_flutter
flutter run
# Hot reload: press 'r' in terminal
# Hot restart: press 'R' in terminal
```

### 3. Make Changes
- Edit `.dart` files → hot reload automatically
- Edit backend `.py` files → uvicorn auto-reloads
- Edit UI → press 'r' to hot reload

### 4. Run Tests

#### Flutter Tests
```bash
cd app_flutter
flutter test
```

#### Backend Tests
```bash
cd backend
# Activate venv
pytest
# With coverage:
pytest --cov=app tests/
```

---

## Next Steps

1. **Milestone 1:** Implement capture screen UI
2. **Milestone 2:** Test backend endpoints
3. **Milestone 3:** Add real nutrition database
4. **Milestone 4:** Integrate AI/ML inference

See [foodvision_dev_playbook.md](../foodvision_dev_playbook.md) for detailed milestones.

---

## Quick Reference

| Task | Command |
|------|---------|
| Run Android | `flutter run` |
| Run iOS | `flutter run` (macOS only) |
| Start Backend | `uvicorn app.main:app --reload` |
| Hot Reload | Press `r` in Flutter terminal |
| Hot Restart | Press `R` in Flutter terminal |
| Build APK | `flutter build apk --release` |
| Build AAB | `flutter build appbundle --release` |
| Build iOS | `flutter build ios --release` |
| Run Tests | `flutter test` (app), `pytest` (backend) |
| Verify Config | `python verify_sync.py` |
| Update Version | Edit `pubspec.yaml`, run `flutter pub get` |

---

## Documentation

- [Dev Playbook](../foodvision_dev_playbook.md) — Full development guide
- [CONFIG_SYNC.md](CONFIG_SYNC.md) — Version management
- [platform/DEPLOYMENT.md](platform/DEPLOYMENT.md) — Deployment guide
- [.gitignore.README.md](../.gitignore.README.md) — Git configuration

**Happy coding! 🎉**
