# 🔧 FoodVision Development Guide - Debug/Live Mode Switching

## Overview

The FoodVision Flutter app now supports **dynamic backend switching** between:

- **🔴 Debug Mode** - Connect to your local development backend (localhost)
- **🟢 Live Mode** - Connect to the Cloud Run production backend

Switch modes anytime without rebuilding the APK!

---

## 🎯 Quick Setup

### For Android Emulator (Default)

The default debug configuration uses `10.0.2.2:8000` which automatically routes to your localhost:

```dart
// If you're running backend locally:
// lib/core/config/environment.dart ✅ Already configured
const String kBackendBaseUrlDebug = 'http://10.0.2.2:8000';
```

**Nothing to change!** Just:
1. Start backend locally: `uvicorn app.main:app --reload`
2. Open Settings in the app (⚙️ icon)
3. Select **Debug (Localhost)**
4. Tap a meal feature - it will connect to your local backend

### For Physical Android Device

If testing on a real phone, you need to replace `10.0.2.2` with your computer's IP:

1. **Find your computer's IP address:**
   ```bash
   # Windows
   ipconfig
   
   # macOS/Linux
   ifconfig
   ```
   Look for something like `192.168.0.10` or `192.168.1.100`

2. **Update the debug URL in code:**
   ```dart
   // lib/core/config/environment.dart
   const String kBackendBaseUrlDebug = 'http://192.168.0.10:8000';
   // Replace 192.168.0.10 with YOUR IP!
   ```

3. **Make sure backend is running on your machine:**
   ```bash
   cd backend
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   The `--host 0.0.0.0` makes it accessible from other devices on the network.

4. **Rebuild the app:**
   ```bash
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 📱 Using Debug/Live Mode in the App

### 1. Open Settings
Tap the **Settings** button in the app drawer or use: `Settings` from home screen

### 2. Switch Backends
You'll see:
```
API Environment
○ Live (Cloud)       ← Production cloud backend
● Debug (Localhost)  ← Your local backend
```

Select which one you want to use.

### 3. Restart the App
The change takes effect after you **restart the app**.

---

## 🔌 Testing Workflow

### Testing with Local Backend

1. **Start backend locally:**
   ```bash
   cd backend
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

2. **Switch app to Debug mode** (Settings → Debug Localhost)

3. **Test features:**
   - Sign up / Login
   - Capture meals
   - Save recipes
   - Sync data
   - View history

4. **Watch backend logs** for errors/requests

### Testing with Cloud Backend

1. **Switch app to Live mode** (Settings → Live Cloud)

2. **Test features** against production Cloud Run endpoint

3. **Monitor logs in Cloud Console:**
   ```bash
   gcloud run logs read nutrilens-api --limit=50
   ```

---

## 🛠️ Development Commands

### Run local backend
```bash
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Check backend health
```bash
# Local
curl http://localhost:8000/health

# Cloud
curl https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/health
```

### View API docs
```bash
# Local
open http://localhost:8000/docs

# Cloud
open https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/docs
```

### Sync Flutter pubspec
```bash
cd app_flutter
flutter pub get
flutter pub upgrade
```

### Build test APK
```bash
cd app_flutter
flutter build apk --debug  # Faster, unoptimized
flutter build apk --release  # Production, slower build
```

### Install on device
```bash
# USB connected device
flutter install

# Or specific APK
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 📊 Environment Configuration Details

### Debug (Local) Configuration
- **URL:** `http://10.0.2.2:8000` (Android emulator) or `http://YOUR_IP:8000` (physical device)
- **Use when:** 
  - Developing features locally
  - Running backend with `--reload` for hot-reload
  - Testing new API endpoints before cloud deployment
- **Pros:** Fast iteration, full control of backend logs
- **Cons:** Only works if backend running on your machine

### Live (Cloud) Configuration
- **URL:** `https://nutrilens-api-2ajzj2dbrq-uc.a.run.app`
- **Use when:**
  - Testing production behavior
  - Final validation before release
  - Checking cloud-specific features (CORS, auth tokens, etc.)
- **Pros:** Tests exact production environment
- **Cons:** Changes go to live database

---

## 🔄 How It Works Internally

### File Structure
```
lib/
├── core/
│   ├── config/
│   │   └── environment.dart          ← Define debug/live URLs
│   ├── services/
│   │   ├── meals_service.dart        ← Uses dynamic apiBaseUrl
│   │   └── meals_provider.dart       ← Injects URL from environment
│   └── api/
│       └── api_config.dart           ← Legacy constants
├── features/
│   └── settings/
│       └── settings_screen.dart      ← UI to switch modes
└── app/
    └── router.dart                   ← Route config
```

### Code Flow
1. **environment.dart** - Stores enum and URL constants
2. **environment.dart** - `EnvironmentNotifier` manages state & persistence
3. **SharedPreferences** - Remembers your choice between app restarts
4. **meals_provider.dart** - Passes dynamic URL to MealsService
5. **meals_service.dart** - All API calls use the selected URL
6. **settings_screen.dart** - UI to toggle between modes

### Persistence
```dart
// User selects "Debug" mode
// It's saved to SharedPreferences:
SharedPreferences.setString('app_environment', 'debug');

// On app restart:
// It's loaded back:
final savedEnv = prefs.getString('app_environment') ?? 'live';
```

---

## 🐛 Troubleshooting

### Problem: "Connection refused" on Debug mode
**Solution:** 
- Check backend is running: `curl http://localhost:8000/health`
- For physical device: Update IP in `environment.dart`
- For emulator: Ensure `10.0.2.2` is correct

### Problem: Settings don't apply immediately
**Solution:** 
- Settings require **app restart** to take effect
- Close app completely, then reopen

### Problem: Can't reach backend from physical device
**Solution:**
- Phone and computer must be on the **same WiFi network**
- Use `ipconfig` to find your computer's IP
- Update `environment.dart` with correct IP
- Rebuild APK
- Check firewall isn't blocking port 8000

### Problem: Getting 401 Unauthorized
**Solution:**
- User is not authenticated
- Sign up/login first in the app
- For debug backend, Firebase still validates tokens (must be logged in)

### Problem: Cloud backend returns 404
**Solution:**
- Verify backend URL is correct: `https://nutrilens-api-2ajzj2dbrq-uc.a.run.app`
- Check endpoint paths match backend routes
- View API docs: `https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/docs`

---

## 📋 Checklist

### Setting Up Debug Mode
- [ ] Backend running locally? `uvicorn app.main:app --reload`
- [ ] Using emulator or physical device?
  - Emulator: No changes needed
  - Physical device: Update IP in `environment.dart`
- [ ] Rebuilt APK after IP change?
- [ ] Settings screen shows correct mode?
- [ ] App restarted after switching modes?
- [ ] Backend logs show requests?

### Testing with Cloud
- [ ] Switched to Live mode in Settings
- [ ] App restarted
- [ ] Can confirm in API info panel (shows Cloud URL)
- [ ] No internet connectivity issues

---

## 🚀 Advanced Usage

### Testing Auth Flows
```bash
# Debug mode - local auth
Settings → Debug
→ Sign up with email
→ Check local backend logs for /auth/sync

# Live mode - cloud auth
Settings → Live
→ Sign in with Google
→ Check Cloud Run logs with gcloud
```

### Performance Testing
```bash
# Local (no network latency)
Settings → Debug
→ Capture meal (fast response)

# Cloud (with network latency)
Settings → Live
→ Capture meal (realistic latency)
```

### Database Testing
```bash
# Debug: Uses your local SQLite/Firestore
# Live: Uses cloud Firestore (real data)

# Switch carefully - don't mix test/production data!
```

---

## 📞 Quick Commands

```bash
# Terminal 1: Start backend
cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Check health
curl http://localhost:8000/health

# Build and run app
cd app_flutter
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk

# View Cloud logs
gcloud run logs read nutrilens-api --limit=50 --tail
```

---

**Happy testing!** 🎉 Toggle between Debug and Live modes to validate your app against both local and production backends.
