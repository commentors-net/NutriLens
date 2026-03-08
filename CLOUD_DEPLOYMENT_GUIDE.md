# FoodVision Cloud Deployment & Authentication Guide

**Status:** ✅ Cloud Backend Deployed | 🔄 Authentication Added | 📱 Ready for Android Testing

---

## 📊 What's Been Done

### 1. **Cloud Deployment** ✅
- **Backend URL:** `https://nutrilens-api-2ajzj2dbrq-uc.a.run.app`
- **API Docs:** `https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/docs`
- **Health Check:** `https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/health`
- Deployed on Google Cloud Run (leave-tracker-2025 project, us-central1 region)

### 2. **Authentication System Added** ✅
- ✅ Firebase Auth integration (email/password + Google Sign-In)
- ✅ Authentication service (`lib/core/auth/auth_service.dart`)
- ✅ Auth state management with Riverpod (`lib/features/auth/auth_provider.dart`)
- ✅ Login screen with email & Google authentication
- ✅ Sign-up screen with validation
- ✅ Automatic user sync to backend after authentication

### 3. **Recipe/Meal Saving Protection** ✅
- ✅ Custom `MealsService` that enforces authentication (`lib/core/services/meals_service.dart`)
- ✅ All meal logging/syncing operations require authenticated user
- ✅ Automatic token injection into API requests
- ✅ User-friendly error messages for unauthenticated access

### 4. **Router Updated** ✅
- ✅ Added login & signup flows
- ✅ Route protection - unauthenticated users redirected to login
- ✅ Auto-redirect authenticated users away from auth screens

### 5. **Dependencies Added** ✅
```yaml
firebase_core: ^2.24.0
firebase_auth: ^4.15.0
google_sign_in: ^6.2.0
```

---

## 🚀 What You Need to Do (NEXT STEPS)

### **Step 1: Create Firebase Project**

1. Go to https://console.firebase.google.com
2. Click "Create a New Project"
3. Name it: `foodvision-app`
4. Disable Google Analytics (can add later)
5. Click "Create Project"

### **Step 2: Enable Firebase Authentication**

1. In Firebase Console → **Authentication**
2. Click **"Get Started"**
3. Enable these sign-in methods:
   - ✅ Email/Password (click **Enable**)
   - ✅ Google (click **Enable** → Select your project from the list)

### **Step 3: Configure Android App in Firebase**

1. In Firebase Console → **Project Settings** (gear icon)
2. Click **"Add App"** → **Android**
3. Fill in:
   - **Android Package Name:** `com.foodvision.app`
   - **Debug Signing Certificate SHA-1:** (Get from: `cd android && ./gradlew signingReport` - copy `SHA1` value)
   - **App nickname:** `FoodVision Android`
4. Click **"Register App"**
5. **Download `google-services.json`**
6. Place file in: `android/app/google-services.json`

### **Step 4: Get Google OAuth2 Credentials for Google Sign-In**

1. Firebase Console → **Project Settings**
2. Go to **"Service Accounts"** tab
3. Click **"Generate New Private Key"** (this downloads a JSON file - keep it safe)
4. Use this file for backend OAuth verification (optional enhancement)

### **Step 5: Update Firebase Configuration in Code**

1. After downloading `google-services.json`, run in the Flutter project:
   ```bash
   flutterfire configure
   ```
   This auto-updates `lib/firebase_options.dart` with your actual Firebase credentials.

2. If you don't have flutterfire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### **Step 6: Build Android APK for Testing**

```bash
cd app_flutter

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release

# Output location: build/app/outputs/flutter-apk/app-release.apk
```

### **Step 7: Install on Android Device**

```bash
# Via USB/ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Or via:
flutter install
```

---

## 🔐 Authentication Flow for Android Users

### **First-Time User**
1. App opens → **Login/Sign Up Screen**
2. User can:
   - ✅ Sign up with email & password
   - ✅ Sign in with Google
3. User syncs to backend
4. ✅ Redirected to home/capture screen

### **Saving Recipes/Meals**
- ✅ **Protected by Authentication**
- If user tries to save without login → **Error message**: "Authentication required to save recipes. Please sign in first."
- User is forced to authenticate before recipe saves are allowed

### **Syncing Data**
- ✅ **Protected by Authentication**
- Background sync requires valid user session
- Automatic token refresh via Firebase
- Failed sync shows user-friendly errors

---

## 📋 Testing Checklist

### **Before Testing**
- [ ] Firebase project created
- [ ] Authentication enabled (Email & Google)
- [ ] Android app registered in Firebase
- [ ] `google-services.json` placed in `android/app/`
- [ ] Backend URL verified in `lib/core/api/api_config.dart`
- [ ] APK built

### **During Testing on Android Device**
- [ ] App starts on login screen
- [ ] Can sign up with email/password
- [ ] Can sign in with Google
- [ ] User profile shows in home screen
- [ ] Can take photos and capture meals
- [ ] **Meal saving requires authentication** (prevents anon saves)
- [ ] Can view saved meals
- [ ] Can view nutrition stats
- [ ] Sign out works properly
- [ ] After sign out → redirected back to login

### **Error Scenarios to Test**
- [ ] Try saving meal without login → Error message shown
- [ ] Try syncing without login → Error message shown
- [ ] Try invalid email/password → Validation error
- [ ] Network error handling
- [ ] Firebase offline → Graceful handling

---

## 📱 Backend API Endpoints (With Auth Required)

All endpoints require `Authorization: Bearer {idToken}` header

```
POST   /nutrilens/meals/log           - Save meal with photos
GET    /nutrilens/meals/history       - Get user's meal history
GET    /nutrilens/meals/today-nutrition - Get today's nutrition
POST   /nutrilens/meals/sync          - Sync meals to backend
POST   /nutrilens/meals/{id}/evaluate - Evaluate meal nutrition
GET    /auth/me                       - Get user profile
POST   /auth/sync                     - Sync user to backend
```

---

## 🔧 Troubleshooting

### **Problem: "google-services.json" not found**
- Solution: Make sure you downloaded it from Firebase and placed it in `android/app/`

### **Problem: Firebase not initializing**
- Check: `firebase_core` is in pubspec.yaml
- Check: `google-services.json` is in correct location
- Check: `flutterfire configure` was run

### **Problem: Google Sign-In fails on Android**
- Check: SHA-1 fingerprint matches in Firebase Console
- Check: `google_sign_in` dependency is installed
- Check: AndroidManifest.xml has INTERNET permission

### **Problem: Can't save meals**
- Check: User is authenticated (check auth state in provider)
- Check: Backend URL is correct in `api_config.dart`
- Check: Backend is running (test: `curl https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/health`)

### **Problem: Token expired errors**
- Solution: Firebase auto-refreshes tokens - just ensure async/await
- If persists: Force re-auth via sign out → sign in

---

## 📞 Quick Commands

```bash
# Check backend health
curl https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/health

# View API docs
open https://nutrilens-api-2ajzj2dbrq-uc.a.run.app/docs

# Get Android signing certificate
cd android && ./gradlew signingReport

# Test local backend instead (if running locally)
# Uncomment in lib/core/api/api_config.dart:
# const String kBackendBaseUrl = 'http://192.168.0.10:8000';
```

---

## 🎯 Next Steps After Testing

1. ✅ Test auth flows on Android
2. ✅ Test meal saving with authentication
3. ✅ Test sync & evaluation
4. 📊 Monitor backend logs in Cloud Run console
5. 🔄 Iterate on UX based on feedback
6. 📦 Build release APK when satisfied

---

**You're all set!** 🚀 Once you complete the Firebase setup steps above, the Android app will be ready for testing with full authentication protection on recipe saves & syncing.
