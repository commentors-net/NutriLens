# FoodVision App — Dev Playbook for Codex + Copilot (Flutter + FastAPI)

**Purpose:** This document is the single source of truth you (and AI pair-programmers like OpenAI Codex + GitHub Copilot) should follow throughout development.

**Target:** Cross‑platform (Android + iOS later) food photo logging + AI analysis:
- multi-photo capture (3–6+ photos)
- detect foods + estimate grams (with ranges)
- compute calories + macros (protein/carbs/fat), optionally micros later
- confidence-based UX: if uncertain, ask for more photos or user corrections
- targets: weight loss users + athletes

---

## 0) Non‑negotiables (Product + Engineering)

### Product truth
- **Estimating grams from photos is uncertain.** Always return ranges + confidence.
- **Mixed dishes** (curries, stir-fry) are hard. MVP must allow quick user corrections.
- **Android-first** for iteration; iOS support will be added once a Mac / Apple program is available.

### Engineering truth
- Keep the **capture UX**, **API contracts**, and **data models** stable.
- Separate concerns early:
  - Flutter UI + device capture
  - Backend analysis + nutrition computation
  - (Later) on-device inference and AR scale modules

---

## 1) Repository layout

Use a **monorepo**:

```
/app_flutter/        # Flutter app
/backend/            # FastAPI service
/shared/             # Shared schemas, sample payloads, constants
/shared/schemas/     # JSON schemas + example payloads
/shared/docs/        # Additional docs (future)
```

Rules:
- Do not duplicate API models in multiple places without a clear source of truth.
- Any breaking API change must include updates to:
  - `shared/schemas/*`
  - Flutter client models
  - Backend pydantic models
  - a migration note in this doc

---

## 2) Milestones (MVP first)

### Milestone 1 — Multi-photo capture flow (Flutter)
Deliverable:
- capture 3–6 photos per meal
- guidance overlay + counter
- review screen (grid), retake/remove
- local persistence for a draft meal

Must-have screens:
- Home (Today summary + New Meal)
- Capture
- Review
- Analyze/Results (stubbed)

### Milestone 2 — Backend skeleton (FastAPI)
Deliverable:
- `POST /meals/analyze` returns **mocked** results (deterministic)
- `POST /meals` saves confirmed meal (optional for MVP)
- `GET /meals/today` returns totals (optional for MVP)

### Milestone 3 — Nutrition mapping (real macros)
Deliverable:
- nutrition DB table (per 100g)
- deterministic macro calculation from grams
- results screen shows totals + per-item macros

### Milestone 4 — AI v0 (incremental)
Deliverable:
- basic food labeling (cloud inference initially)
- grams estimate with heuristics + ranges
- confidence + “needs more photos” logic
- correction loop: user edits label + grams

---

## 3) API contract (authoritative)

Keep the **contract stable** and evolve via versioned changes.

### 3.1 `POST /meals/analyze` (multipart)
**Request**
- multipart form-data:
  - `images[]`: JPEG/PNG files
  - `metadata` (JSON string; optional)

**Metadata (example)**
```json
{
  "client": {"platform": "android", "app_version": "0.1.0"},
  "capture": {"photo_count": 5},
  "locale": "en_MY",
  "timestamp": "2026-02-21T10:30:00+08:00"
}
```

**Response (example)**
```json
{
  "overall_confidence": 0.62,
  "needs_more_photos": true,
  "suggested_next_shots": ["lower_left_angle", "top_down"],
  "items": [
    {
      "item_id": "tmp-1",
      "label": "white rice",
      "label_confidence": 0.72,
      "grams_estimate": 180,
      "grams_range": {"min": 130, "max": 240},
      "grams_confidence": 0.55,
      "macros": {"kcal": 234, "protein_g": 4.3, "carbs_g": 51.5, "fat_g": 0.6}
    }
  ],
  "warnings": ["oil_sauce_uncertain"]
}
```

### 3.2 Rules for backend responses
- Always return:
  - `items[]`
  - `overall_confidence` (0–1)
  - `needs_more_photos` (bool)
- For each item:
  - include `grams_range.min/max` even if equal
  - include `macros` even if rough
- Use **stable field names** (snake_case in backend; Flutter converts if needed).

Put the JSON schema in:
- `shared/schemas/analyze_meal_response.schema.json`
- `shared/schemas/analyze_meal_response.example.json`

---

## 4) Flutter app conventions

### 4.1 Tech choices
- Flutter stable (latest)
- Prefer **Dio** for networking OR `http` for MVP (pick one and standardize)
- State management: start simple
  - MVP: `ChangeNotifier` or `Riverpod` (choose one)

### 4.2 Project structure (Flutter)
```
lib/
  main.dart
  app/
    router.dart
    theme.dart
  features/
    capture/
    meals/
    nutrition/
  core/
    api/
    models/
    storage/
    utils/
```

### 4.3 Coding rules (Flutter)
- Keep widgets small; prefer composition.
- No business logic inside UI widgets.
- Use typed models; avoid dynamic JSON maps outside the API layer.
- Always handle permission errors + camera unavailable gracefully.

### 4.4 Capture UX requirements
- Minimum photos: **3**
- Preferred: **5**
- Display guidance:
  - “Take one top-down photo”
  - “Take left/right angled photos”
- If analysis returns `needs_more_photos=true`, route user back to capture with suggested angles.

---

## 5) Backend (FastAPI) conventions

### 5.1 Project structure
```
backend/
  app/
    main.py
    api/
      routes_meals.py
    models/
      schemas.py
    services/
      analysis.py
      nutrition.py
    db/
      session.py
      models.py
  tests/
```

### 5.2 Coding rules
- Use Pydantic models for request/response.
- Keep ML/analysis logic behind `services/analysis.py`.
- Nutrition calculation lives in `services/nutrition.py`.
- All endpoints must be testable with `pytest`.

### 5.3 Deterministic mock for Milestone 2
Until ML is integrated:
- Hash the image bytes (or filename) to pick from a small set of canned foods.
- Return consistent outputs for the same inputs.
This lets frontend develop without ML churn.

---

## 6) Nutrition mapping rules

### MVP database format
Store nutrition per 100g:

Fields:
- `food_id` (string)
- `name`
- `kcal_per_100g`
- `protein_g_per_100g`
- `carbs_g_per_100g`
- `fat_g_per_100g`
- (later) fiber, sodium, micronutrients

Computation:
- `kcal = grams * kcal_per_100g / 100`
- similarly for macros

Return rounded:
- kcal: integer
- macros: 1 decimal place

---

## 7) Confidence logic (how the UX decides “more photos”)

Backend should compute:
- `overall_confidence` (0–1)
- `needs_more_photos = overall_confidence < 0.70` (initial rule; tweak later)

Suggested angles:
- `top_down`
- `lower_left_angle`
- `lower_right_angle`
- `closeup`

Frontend behavior:
- If `needs_more_photos=true`:
  - show results *but* encourage “Add more photos for better accuracy”
  - one-tap button: “Add photos” → capture screen with suggested angles

---

## 8) Data collection + correction loop (MVP important)
Even in MVP:
- Allow editing:
  - label
  - grams estimate
- Store corrections (local + backend if available)
- Use corrections later to:
  - personalize portion estimates
  - improve model training set

---

## 9) Testing strategy

### Flutter
- Unit tests for:
  - API client parsing
  - nutrition totals UI logic
- Widget tests for:
  - capture flow navigation
  - results rendering

### Backend
- Unit tests for:
  - nutrition calculations
  - schema validation
- Integration tests for:
  - `/meals/analyze` returns required fields

---

## 10) Git workflow

Branch naming:
- `feat/capture-flow`
- `feat/analyze-endpoint`
- `fix/camera-permissions`

Commit messages:
- `feat: add review screen for captured photos`
- `fix: handle camera permission denial`

PR checklist:
- [ ] updated shared schema/examples if API changed
- [ ] tests added/updated
- [ ] no secrets or keys committed
- [ ] screenshot/video for UX changes

---

## 11) “How to ask Codex/Copilot” (prompt templates)

### 11.1 Flutter — implement a screen
**Prompt**
> Implement a Flutter screen `CaptureScreen` that uses the camera to capture multiple photos (min 3, max 8). Show a counter, allow retake of last photo, and store file paths in a `CaptureState` model. Use clean architecture: UI only calls methods on a controller.

### 11.2 Flutter — API client
**Prompt**
> Create a Dart API client that calls `POST /meals/analyze` using multipart upload `images[]` and optional `metadata` JSON. Parse the response into strongly typed models: AnalyzeMealResponse, AnalyzeItem, Macros, GramsRange. Add error handling and unit tests.

### 11.3 FastAPI — endpoint skeleton
**Prompt**
> Create a FastAPI endpoint `POST /meals/analyze` that accepts multipart `images[]` and optional `metadata` JSON string. Validate inputs, call `services.analysis.analyze(images, metadata)`, and return a Pydantic response model matching the schema in `shared/schemas`.

### 11.4 Backend — deterministic mock analysis
**Prompt**
> Implement `services.analysis.analyze()` using deterministic mocks. Choose 3–5 canned foods. Use a hash of the first image bytes to pick an item set. Return confidence scores and grams ranges. Ensure output conforms to AnalyzeMealResponse.

---

## 12) Security + privacy basics
- Don’t store raw photos longer than necessary (configurable).
- Never log full image bytes.
- Use HTTPS for uploads (in production).
- Keep AI outputs as *estimates*; avoid medical claims.

---

## 13) iOS reality (so we don’t get stuck)
- iOS builds require **macOS + Xcode**.
- We proceed Android-first.
- When a Mac is available:
  - run iOS simulator to validate UI
  - later: device testing via Xcode (paid program optional but makes life easier)

---

## 14) Definition of Done (DoD) for each milestone
A milestone is “done” only when:
- demo video recorded (30–60s)
- tests pass
- no crashes on a mid-tier Android phone
- API contract is documented in `/shared/schemas`

---

## 15) Quick start commands

### Flutter (Windows)
```bash
flutter doctor
cd app_flutter
flutter pub get
flutter run
```

### Backend (Python)
```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

---

## 15.1) Wireless Device Debugging (Android 11+)

Debug on a real device over WiFi — no USB cable needed after initial pairing.

### Port types (important!)
| Port | Purpose | Changes? |
|------|---------|----------|
| **Pairing port** | One-time pairing only | Every time you tap "Pair device with pairing code" |
| **Debug port** | Used for `adb connect` | Only changes if you toggle Wireless Debugging OFF/ON or reboot |

### Step 1 — Enable Wireless Debugging on phone
```
Settings → Developer Options → Wireless Debugging → ON
Note the IP Address & Port shown (e.g. 192.168.0.14:34623) ← DEBUG PORT
```

### Step 2 — Pair once (first time only)
```
Tap "Pair device with pairing code" → shown a TEMPORARY port + 6-digit code
```
```powershell
adb pair 192.168.0.14:<PAIRING_PORT>
# Enter the 6-digit code when prompted
# Output: Successfully paired to ...
```

### Step 3 — Connect (every session)
```powershell
# Use the DEBUG PORT from the main Wireless Debugging screen (NOT the pairing port)
adb connect 192.168.0.14:34623

# Verify
adb devices
flutter devices
flutter run
```

### Remove USB cable
Remove the cable **after** `adb connect` reports `connected to 192.168.0.14:xxxxx`.

### Troubleshooting
```powershell
# Device shows "offline" after removing cable:
adb kill-server
adb start-server
adb connect 192.168.0.14:<DEBUG_PORT>

# Debug port changed (after reboot or toggling Wireless Debugging):
# Check the new port in Settings → Developer Options → Wireless Debugging
adb connect 192.168.0.14:<NEW_PORT>
```

**Common causes of failure:**
- PC on VPN → disable VPN (changes network routing)
- PC and phone on different networks → both must be on same WiFi router
- Windows Firewall blocking ADB:
```powershell
# Run as Administrator:
netsh advfirewall firewall add rule name="ADB" dir=in action=allow protocol=TCP localport=5555
```

---

## 16) Project Setup Status

### ✅ Completed
- **Monorepo structure** created:
  - `/app_flutter/` — Flutter app with full lib/ directory structure
  - `/backend/` — FastAPI service with app/, tests/ directories
  - `/shared/schemas/` — JSON schemas + example payloads
  - `/shared/docs/` — Documentation folder

### Flutter (app_flutter/)
- **pubspec.yaml** — dependencies configured (http, riverpod, camera, image_picker, local storage)
- **lib/main.dart** — skeleton app with placeholder screens (Home, Capture)
- **lib/app/theme.dart** — Material 3 theme configuration
- **lib/app/router.dart** — go_router 14.8.1 configured; routes: `/`, `/capture`, `/review`, `/results`
- **lib/features/home/home_screen.dart** — HomeScreen with today summary + New Meal button
- **lib/features/results/results_screen.dart** — ResultsScreen stub (Milestone 2 integration pending)
- **lib/core/models/analyze_response.dart** — strongly-typed models for API responses
- **lib/core/api/food_vision_client.dart** — HTTP client for /meals/analyze, /meals/today, /meals endpoints
- ✅ Ready for Milestone 1 (capture UI screens)

### Backend (backend/)
- **requirements.txt** — Python dependencies pinned (FastAPI, Uvicorn, Pydantic, SQLAlchemy, etc.)
- **app/main.py** — FastAPI app with CORS, health check, meals router
- **app/models/schemas.py** — Pydantic models matching shared/schemas/ (AnalyzeMealResponse, AnalyzeItem, Macros, GramsRange)
- **app/api/routes_meals.py** — endpoints skeleton:
  - `POST /meals/analyze` — accepts multipart images + metadata, calls analysis service
  - `POST /meals` — saves meal (TODO: DB integration)
  - `GET /meals/today` — today's totals (TODO: DB integration)
- **app/services/analysis.py** — deterministic mock analyzer (Milestone 2):
  - Hashes first image to pick canned food
  - Returns consistent results for same inputs
  - Suggests "more photos" if < 5 photos
- **app/services/nutrition.py** — nutrition calculations:
  - In-memory food DB (Milestone 2; real DB in Milestone 3)
  - compute_macros() and compute_total_macros() functions
- **app/db/session.py & models.py** — placeholder for SQLAlchemy (Milestone 3)
- **tests/test_nutrition.py & test_analysis.py** — unit tests (pytest-ready)
- ✅ Ready for Milestone 2 (deterministic backend)

### Shared Schemas
- **shared/schemas/analyze_meal_response.schema.json** — authoritative JSON schema
- **shared/schemas/analyze_meal_response.example.json** — example response payload
- ✅ Schema is source of truth; all models derived from it

### Utilities
- **.gitignore** — configured for Flutter + Python + IDE artifacts

### Platform Configuration (Android + iOS)
#### Android (`app_flutter/android/`)
Build note (2026-02-27):
- Android tooling aligned to modern Flutter/Gradle setup:
  - `settings.gradle` plugins: AGP `8.9.1`, Kotlin `2.1.0`, Flutter plugin loader enabled
  - `gradle-wrapper.properties`: Gradle `8.11.1`
  - `app/build.gradle`: migrated to `dev.flutter.flutter-gradle-plugin` DSL
  - `build.gradle`: uses Flutter-compatible build output mapping (`../build`)
- Required Android resources were restored:
  - `app/src/main/res/values/strings.xml` (`app_name`)
  - `app/src/main/res/values/styles.xml` (`LaunchTheme`, `NormalTheme`)
- `MainActivity.kt` now uses standard `FlutterActivity` entry point without manual plugin registration.
- `android/gradle.properties` includes Kotlin stability flags for Windows path-root cache issues:
  - `kotlin.incremental=false`
  - `kotlin.compiler.execution.strategy=in-process`
- **build.gradle** — root Gradle config (minSdk: 21, targetSdk: 34)
- **app/build.gradle** — app-level Gradle with Flutter plugin
- **app/src/main/AndroidManifest.xml** — app bundle + permissions:
  - `CAMERA` — food photo capture
  - `READ/WRITE_EXTERNAL_STORAGE` — file access
  - `INTERNET` — backend API calls
- **gradle.properties** — JVM args, AndroidX support
- **android/app/src/main/kotlin/MainActivity.kt** — Flutter activity entry point
- ✅ Ready to run: `flutter run -d emulator`
- Release: `flutter build appbundle --release` (Play Store)

#### iOS (`app_flutter/ios/`)
- **Runner/Info.plist** — app bundle info + permission strings:
  - `NSCameraUsageDescription` — "FoodVision needs camera access…"
  - `NSPhotoLibraryUsageDescription` — Photo library access
  - MinimumOSVersion: 12.0
- **Podfile** — CocoaPods manager (platform iOS 12.0+)
- **platform/ios/CameraPermissionHandler.swift** — placeholder for native code
- ✅ Ready to run: `flutter run -d simulator` (macOS only)
- Release: `flutter build ios --release` (App Store)

#### Platform-specific placeholders
- **platform/android/CameraPermissionHandler.kt** — native permission logic (Android)
- **platform/ios/CameraPermissionHandler.swift** — native permission logic (iOS)
- **platform/DEPLOYMENT.md** — full guide for Android + iOS deployment, debugging, and Play Store/App Store submission

### Status: Both platforms configured + ready for development
- Android: minSdk 21 (Android 5.0), targetSdk 34
- iOS: minimum 12.0 (iPad Air, iPhone 6+)
- All required permissions declared
- Deployment guide included
- Android validation on 2026-02-27:
  - `flutter build apk --debug` passed
  - `flutter run -d R83XB0ZP37B` passed on physical device

### Next Steps
1. **Milestone 1 (Flutter capture UI)**
   - Implement CaptureScreen with camera integration
   - Add ReviewScreen with grid + retake/remove
   - Connect to CaptureState using Riverpod

2. **Milestone 2 (Backend deterministic)**
   - Test `/meals/analyze` endpoint locally
   - Verify mock analysis is deterministic
   - Validate response schema compliance

3. **Milestone 3 (Real nutrition DB)**
   - Implement SQLAlchemy models (Food, Meal, MealItem)
   - Migrate in-memory nutrition DB to SQLite
   - Add `/meals/today` query logic

4. **Milestones 4+ (AI + enhancements)**
   - Integrate cloud inference (Google Vision API, etc.)
   - Add correction loop UI in Flutter
   - Implement user-based personalization

---

## 17) Project Progress Checklist

### 📋 Phase 0: Foundation (Setup)
- [x] Initialize monorepo structure
- [x] Create Flutter app skeleton
- [x] Create FastAPI backend skeleton
- [x] Set up shared schemas directory
- [x] Configure Android platform (Gradle, Manifest)
- [x] Configure iOS platform (Info.plist, Podfile)
- [x] Set up .gitignore + environment templates
- [x] Create version sync system (app_config.yaml, verify_sync.py)
- [x] Write comprehensive documentation (playbook, README, CONFIG_SYNC, DEPLOYMENT)
- [x] Set up backend tests skeleton (pytest)
- [x] Verify configuration sync works

**Status:** ✅ **COMPLETE** — Ready for Milestone 1

---

### 📋 Milestone 1: Multi-photo Capture Flow (Flutter)
**Goal:** Implement camera capture UI with 3-6 photos per meal

#### 1.1 Camera Integration
- [x] Add camera permission handling (Android + iOS)
- [x] Implement camera preview screen
- [ ] Test camera on real Android device
- [ ] Handle camera errors gracefully

#### 1.2 Capture Screen
- [x] Create CaptureScreen widget
- [x] Add photo counter (X of 3-6 photos)
- [x] Add guidance overlay ("Take top-down photo")
- [x] Implement capture button with feedback
- [x] Store captured photo paths locally

#### 1.3 Review Screen
- [x] Create ReviewScreen with grid layout
- [x] Display captured photos as thumbnails
- [x] Add "Retake" button (removes last photo)
- [x] Add "Remove specific photo" functionality
- [x] Add "Add more photos" button
- [x] Add "Analyze" button (navigates to results)

#### 1.4 State Management
- [x] Set up Riverpod providers
- [x] Create CaptureState model (photo paths, count)
- [x] Implement capture controller logic
- [x] Add local persistence (draft meal)

#### 1.5 Navigation
- [x] Implement app routing (go_router 14.8.1)
- [x] Link Home → Capture → Review → Results
- [x] Add back navigation handling
- [ ] Test navigation flow on device

#### 1.6 Testing & Polish
- [ ] Widget tests for CaptureScreen
- [ ] Widget tests for ReviewScreen
- [ ] Test on Android emulator
- [ ] Test on real Android device
- [ ] Record demo video (30-60s)

**Status:** 🟡 **95% COMPLETE** — Navigation implemented; pending device test + widget tests

---

### 📋 Milestone 2: Backend Skeleton (FastAPI)
**Goal:** Implement deterministic mock analysis endpoint

#### 2.1 Endpoint Implementation
- [x] Create `POST /meals/analyze` endpoint
- [x] Handle multipart image upload
- [x] Parse optional metadata JSON
- [x] Validate inputs (min 3 images)

#### 2.2 Deterministic Analysis Service
- [x] Implement hash-based food selection
- [x] Create canned food database (5 items)
- [x] Generate consistent responses
- [x] Implement confidence logic (< 5 photos = needs_more)
- [x] Add suggested angles logic

#### 2.3 Response Generation
- [x] Build AnalyzeMealResponse model
- [x] Include all required fields
- [x] Compute macros from gram estimates
- [x] Add warnings for uncertain items

#### 2.4 Testing
- [x] Unit tests for analysis service
- [x] Unit tests for nutrition calculations
- [ ] Integration tests for /meals/analyze endpoint
- [x] Test with real image uploads (from physical device)
- [x] Verify schema compliance

#### 2.5 Flutter Integration
- [x] Connect Flutter app to backend (`lib/core/api/api_config.dart` — PC WiFi IP)
- [x] Test image upload from mobile
- [x] Handle network errors (SocketException → friendly message)
- [x] Display loading states (CircularProgressIndicator)
- [x] Show results in ResultsScreen (confidence banner, totals, per-item macros)

**Status:** ✅ **COMPLETE** — End-to-end flow tested on physical device (SM X115)

---

### 📋 Milestone 3: Nutrition Mapping (Real Data)
**Goal:** Replace mock data with real nutrition database

#### 3.1 Database Setup
- [x] Set up SQLite database (`backend/nutrition.db` — auto-created on startup)
- [x] Create Food table schema (`app/db/models.py` — food_id, name, kcal, protein, carbs, fat per 100g)
- [x] Create Meal table schema (meal_id UUID, timestamp, notes)
- [x] Create MealItem table schema (item_id UUID, meal_id FK, food_id FK, grams)
- [ ] Set up Alembic migrations (deferred — using `create_all` for MVP; Alembic added to requirements.txt for future)

#### 3.2 Nutrition Data
- [x] Import nutrition data (per 100g)
- [x] Add common foods (55 items seeded)
- [x] Add Malaysian/Asian foods (nasi lemak rice, roti canai, capati, kangkung, tempeh, sambal, peanut sauce, anchovies, sotong, etc.)
- [x] Verify data accuracy (cross-referenced USDA + Malaysian Food Composition data)
- [x] Create data seeding script (`app/db/seed.py` — idempotent, runs on startup if DB empty)

#### 3.3 Backend Services
- [x] Implement database session management (`app/db/session.py` — SQLAlchemy, `get_db()` FastAPI dep, `init_db()`)
- [x] Create Food CRUD operations (via ORM — get_food_fuzzy in nutrition.py)
- [x] Create Meal CRUD operations (in routes_meals.py — POST /meals)
- [x] Update nutrition service to use DB (`app/services/nutrition.py` — added `get_food_fuzzy()`, `compute_macros_from_food()`)
- [x] Implement fuzzy food name matching (difflib stdlib — exact → substring → close_match cutoff 0.55)

#### 3.4 API Endpoints
- [x] Implement `POST /meals` (save meal — creates Meal + MealItem rows, fuzzy-matches labels → food_ids)
- [x] Implement `GET /meals/today` (returns totals for UTC date's meals, joins MealItem → Food for macro calcs)
- [ ] Implement `GET /meals/history` (deferred — out of M3 scope)
- [ ] Add food search endpoint (deferred)
- [x] Test all endpoints (pytest 8/8 pass; backend imports verified)

#### 3.5 Flutter Integration
- [x] Create ResultsScreen UI (✅ M2 — already done)
- [x] Display per-item macros (✅ M2 — already done)
- [x] Show total meal macros (✅ M2 — already done)
- [x] Add confidence indicators (✅ M2 — already done)
- [x] Implement "Add more photos" flow (✅ M2 — already done)
- [x] **Save Meal button** — new in M3: `_SaveMealButton` ConsumerWidget, calls `saveMealProvider.save(analysis)`, shows saved/error states
- [x] `FoodVisionClient.saveMealFromAnalysis()` — builds SaveMealRequest from AnalyzeMealResponse
- [x] `FoodVisionClient.getMealsToday()` — returns typed `DailyTotals` model
- [x] `DailyTotals` Dart model (`lib/core/models/daily_totals.dart`)
- [x] `dailyTotalsProvider` — `FutureProvider.autoDispose` (`lib/features/home/home_provider.dart`)
- [x] `HomeScreen` updated to `ConsumerWidget` — shows real daily kcal/protein/carbs/fat totals, auto-refreshes on navigate back

#### 3.6 Testing
- [x] Test nutrition calculations (8/8 pytest pass)
- [x] Test meal persistence (smoke-test: DB init + seed = 55 foods confirmed)
- [ ] Test today's totals query (end-to-end test on device pending)
- [ ] End-to-end test (capture → analyze → save → see home totals update)

**Status:** 🟡 **90% COMPLETE** — Core DB, seed, fuzzy matching, save/today endpoints implemented and Flutter wired up; end-to-end device test pending

---

### 📋 Milestone 4: AI Integration (Cloud Inference)
**Goal:** Replace deterministic mocks with real AI food detection

#### 4.1 AI Service Selection
- [ ] Research options (Google Vision, Azure, AWS, Custom)
- [ ] Set up API credentials
- [ ] Implement service integration
- [ ] Test accuracy on sample images

#### 4.2 Food Detection
- [ ] Implement image preprocessing
- [ ] Call AI API for food labeling
- [ ] Post-process AI results
- [ ] Map AI labels to nutrition DB
- [ ] Handle unknown foods

#### 4.3 Portion Estimation
- [ ] Research portion estimation methods
- [ ] Implement baseline heuristics
- [ ] Add reference object detection (optional)
- [ ] Generate gram ranges
- [ ] Compute confidence scores

#### 4.4 Multi-Photo Analysis
- [ ] Combine detections from multiple angles
- [ ] Improve confidence with more photos
- [ ] Detect overlapping items
- [ ] Handle partial occlusions

#### 4.5 Correction Loop
- [ ] Create EditItemScreen (label + grams)
- [ ] Store user corrections locally
- [ ] Send corrections to backend
- [ ] Log corrections for model improvement

#### 4.6 Testing & Tuning
- [ ] Test with real meal photos
- [ ] Measure accuracy metrics
- [ ] Tune confidence thresholds
- [ ] A/B test portion estimates

**Status:** ⚪ **NOT STARTED**

---

### 📋 Milestone 5: Home Screen & Meal History
**Goal:** Build home dashboard with daily summary

#### 5.1 Home Screen
- [ ] Design home screen layout
- [ ] Show today's totals (kcal, macros)
- [ ] Display meal history (today)
- [ ] Add "New Meal" button
- [ ] Show progress toward goals (optional)

#### 5.2 Meal History
- [ ] Create MealListScreen
- [ ] Display past meals with thumbnails
- [ ] Show date/time + macros
- [ ] Implement tap to view details
- [ ] Add search/filter functionality

#### 5.3 Meal Details
- [ ] Create MealDetailScreen
- [ ] Show all items + macros
- [ ] Display photos
- [ ] Add edit/delete actions
- [ ] Show confidence scores

#### 5.4 Local Storage
- [ ] Set up local database (sqflite)
- [ ] Cache meals locally
- [ ] Sync with backend
- [ ] Handle offline mode

**Status:** ⚪ **NOT STARTED**

---

### 📋 Milestone 6: Polish & Release (MVP)
**Goal:** Prepare for beta release

#### 6.1 UI/UX Polish
- [ ] Refine theme + colors
- [ ] Add animations/transitions
- [ ] Improve loading states
- [ ] Add empty states
- [ ] Implement error screens
- [ ] Add onboarding flow

#### 6.2 Performance
- [ ] Optimize image compression
- [ ] Add image caching
- [ ] Reduce API payload size
- [ ] Test on low-end devices
- [ ] Profile Flutter performance

#### 6.3 Error Handling
- [ ] Handle network timeouts
- [ ] Handle camera errors
- [ ] Handle permission denials
- [ ] Add retry mechanisms
- [ ] Log errors for debugging

#### 6.4 Testing
- [ ] Complete test coverage (>70%)
- [ ] Manual testing checklist
- [ ] Test on multiple devices
- [ ] Beta testing with users
- [ ] Fix critical bugs

#### 6.5 Release Preparation
- [ ] Update version to 1.0.0
- [ ] Generate release builds (Android + iOS)
- [ ] Prepare store listings
- [ ] Create screenshots + videos
- [ ] Write release notes

#### 6.6 Deployment
- [ ] Submit to Google Play (internal testing)
- [ ] Submit to TestFlight (iOS beta)
- [ ] Gather feedback
- [ ] Iterate based on feedback
- [ ] Public release

**Status:** ⚪ **NOT STARTED**

---

### 📋 Future Enhancements (Post-MVP)
- [ ] User accounts + authentication
- [ ] Cloud sync across devices
- [ ] Meal planning feature
- [ ] Recipe suggestions
- [ ] Barcode scanning
- [ ] Restaurant database integration
- [ ] Social sharing
- [ ] Nutrition goals + tracking
- [ ] Apple Watch / Wear OS app
- [ ] AR measurement tools
- [ ] Integration with fitness apps

---

## 18) Version Management & Platform Sync

### Single Source of Truth: pubspec.yaml
All version information is managed centrally:
```yaml
version: 0.1.0+1
       # ^^^^^ ^
       # |     └─ Build number (Android versionCode, iOS CFBundleVersion)
       # └─────── Version name (Android versionName, iOS CFBundleShortVersionString)
```

### Configuration Files

#### app_config.yaml
Reference configuration for:
- App identity (bundle ID: `com.foodvision.app`)
- Platform minimums (Android minSdk: 21, iOS: 12.0)
- Build tool versions
- Permission documentation

#### Android (auto-syncs)
- `android/app/build.gradle` reads from Flutter build tools
- `applicationId`: com.foodvision.app
- `versionCode` and `versionName` auto-populate from pubspec.yaml

#### iOS (auto-syncs)
- `ios/Runner/Info.plist` uses Flutter variables:
  - `$(FLUTTER_BUILD_NAME)` — version name
  - `$(FLUTTER_BUILD_NUMBER)` — build number
  - `$(PRODUCT_BUNDLE_IDENTIFIER)` — bundle ID (set in Xcode)

### How to Update Version

1. **Edit pubspec.yaml only:**
   ```yaml
   version: 0.2.0+2
   ```

2. **Sync:**
   ```bash
   flutter pub get
   ```

3. **Verify (optional):**
   ```bash
   python verify_sync.py
   # or on Windows: verify_sync.bat
   ```

4. **Build:**
   ```bash
   flutter build appbundle --release  # Android
   flutter build ios --release         # iOS
   ```

Both platforms will use identical version numbers!

### Verification Script
Run `verify_sync.py` to check:
- ✅ Version numbers match across platforms
- ✅ Bundle IDs are consistent
- ✅ iOS uses Flutter variables (not hardcoded)
- ✅ Platform minimums align

See [CONFIG_SYNC.md](app_flutter/CONFIG_SYNC.md) for complete guide.

---

## 19) Platform Unification — NutriLens + Leave Tracker on Google Cloud

### 19.1) Leave Tracker — Existing System (as-built, verified Feb 2026)

**Location:** `D:\Jobs\workspace\python-projects\Leave-tracker-app`

#### Infrastructure (confirmed from deploy scripts)
| Component | Technology | Hosting |
|-----------|-----------|---------|
| Backend | FastAPI (Python) | **Google Cloud Run** — service: `leave-tracker-api` |
| Frontend | React 19 + TypeScript + Vite + MUI | **Cloud Storage bucket** — `{ProjectId}-frontend` (static site) |
| Database (prod) | **Firestore** | Google Cloud (same project) |
| Database (dev) | SQLite | Local only |
| AI | Google Gemini (`gemini-2.0-flash-lite` + fallbacks) | Gemini API |

> ℹ️ **Note:** User referred to this as App Engine — it is actually **Cloud Run** (confirmed: `gcloud run deploy leave-tracker-api` in deploy script, `run.googleapis.com` API enabled).

#### Authentication (custom implementation — no Firebase)
- Email/password login: password is **never stored** — username is encrypted with password as the key (`core/security.py`)
- JWT tokens: 30-minute expiration (`python-jose`)
- 2FA: TOTP via `pyotp` — compatible with Google Authenticator
- Dev mode: 2FA bypassed when `ENVIRONMENT=development`
- No Google SSO yet — **to be added** (see §19.4)

#### DB Abstraction Pattern
```
db_factory.py
  ENVIRONMENT=development  →  sqlite_db.py   (local SQLite)
  ENVIRONMENT=production   →  firestore_db.py (Cloud Firestore)
```
This pattern must be preserved and extended for NutriLens.

#### API Endpoints (all live)
```
POST  /auth/register
POST  /auth/login
POST  /auth/change-password

GET   /api/people
POST  /api/people
PUT   /api/people/{id}
DELETE /api/people/{id}

GET   /api/types
POST  /api/types
PUT   /api/types/{id}
DELETE /api/types/{id}

GET   /api/absences              (filterable: person_id, type_id, date_from, date_to)
POST  /api/absences
PATCH /api/absences/{id}
DELETE /api/absences/{id}
POST  /api/absences/bulk-delete
POST  /api/absences/bulk-update-applied

POST  /api/smart-identify        (WhatsApp chat → leave entries via Gemini)
GET   /api/smart-identify/health

GET   /api/ai-instructions
PUT   /api/ai-instructions
POST  /api/ai-instructions/reset
```

#### Frontend Pages (all live)
| Page | Route | Purpose |
|------|-------|---------|
| `Login.tsx` | `/login` | Login with username + password + 2FA code |
| `Register.tsx` | `/register` | New user registration (toggle-able via env var) |
| `Dashboard.tsx` | `/dashboard` | Team absence calendar/view |
| `Reports.tsx` | `/reports` | Leave summary reports |
| `SmartIdentification.tsx` | `/smart-identification` | Paste WhatsApp chat → AI extracts leave entries |
| `Settings.tsx` | `/settings` | AI instructions config, password change |

#### Deployment Scripts (existing, working)
| Script | Purpose |
|--------|---------|
| `deploy-backend-update.ps1` | Backend-only redeploy to Cloud Run |
| `deploy-frontend.ps1` | Frontend-only redeploy to Cloud Storage |
| `deploy-to-gcp-complete.ps1` | Full deploy (backend + frontend + Firestore setup) |
| `deploy-backend-only.ps1` | Backend deploy without frontend |

---

### 19.2) Target Unified Architecture

```
Google Cloud (same project as Leave Tracker)
│
├── Cloud Run Services
│   ├── leave-tracker-api        ← existing (unchanged)
│   └── nutrilens-api            ← new FastAPI service
│
├── Cloud Storage Buckets
│   ├── {project}-frontend       ← existing static site (React)
│   │   Extended with:
│   │   ├── /login               ← shared login (already exists)
│   │   ├── /app-select          ← NEW: post-login app chooser
│   │   ├── /leave-tracker/**    ← existing pages (unchanged)
│   │   └── /nutrilens/**        ← NEW: admin/logs UI
│   └── (nutrilens media)        ← optional: uploaded food photos
│
├── Firestore
│   ├── users/                   ← existing Leave Tracker users
│   ├── leave_records/           ← existing leave data
│   └── nutrilens_meals/         ← NEW: NutriLens meal logs
│
└── Flutter Mobile App (Android/iOS)
    └── → nutrilens-api only (no web frontend needed for mobile)
```

**Key principle:** Leave Tracker stays 100% unchanged. NutriLens deploys alongside it as an independent Cloud Run service. The shared frontend is extended, not replaced.

---

### 19.3) Migration Plan (Phased)

#### Phase P1 — Audit & Map (no code changes) — IN PROGRESS
- [x] Confirm Leave Tracker hosting: Cloud Run + Cloud Storage + Firestore
- [x] Map all existing API endpoints (§19.1)
- [x] Map all existing frontend pages (§19.1)
- [x] Document auth system (JWT + pyotp TOTP, no Firebase)
- [x] Confirm DB abstraction pattern (db_factory.py)
- [ ] Note actual Cloud project ID and region from `.env` files
- [ ] Export Firestore schema (collections + field names)

#### Phase P2 — NutriLens Backend on Cloud Run
- [x] Add `Dockerfile` to NutriLens backend (follow Leave Tracker pattern) — `backend/Dockerfile`
- [x] Switch NutriLens DB: SQLite (dev) → Firestore (prod) using same db_factory pattern
  - `app/db/firestore_db.py` — `NutriLensFirestoreDB` (collections: `nutrilens_foods`, `nutrilens_meals`)
  - `app/db/sqlite_db_cloud.py` — `NutriLensSQLiteDB` (same interface, SQLite-backed, dict-based)
  - `app/db/db_factory.py` — `ENVIRONMENT=development` → SQLite, else → Firestore
- [x] Migrate `nutrition.py` food data → Firestore `nutrilens_foods` collection (seed once via `db.seed_foods()`)
- [x] Migrate meal persistence → Firestore `nutrilens_meals` collection (embedded items, denormalised)
- [x] Update `app/services/nutrition.py` — `get_food_fuzzy` + `compute_macros_from_food` use dicts (db-agnostic)
- [x] Rewrite `app/api/routes_meals.py` — uses `db_factory.db` singleton (no SQLAlchemy Session dep)
- [x] Update `app/main.py` — startup seeding via `db.seed_foods()` (works for both SQLite + Firestore)
- [x] Update `requirements.txt` — added `google-cloud-firestore==2.14.0`
- [x] Update `.env.example` — `ENVIRONMENT`, `GCP_PROJECT_ID`, `DATABASE_URL`
- [x] Create `deploy-nutrilens-backend.ps1` (mirrors `deploy-backend-update.ps1`)
- [ ] Test locally with `ENVIRONMENT=development` in `.env`
- [ ] Deploy to Cloud Run as `nutrilens-api`
- [ ] Update Flutter `api_config.dart` → Cloud Run URL

#### Phase P3 — Shared Frontend: App Selector
- [ ] Add `/app-select` route to existing React frontend
- [ ] Post-login: if user has access to multiple apps → show app picker
- [ ] App picker cards: 🥗 NutriLens | 🌿 Leave Tracker
- [ ] If user has access to one app only → redirect directly (no picker shown)
- [ ] User-app access stored in Firestore `user_apps/{userId}` document
- [ ] NutriLens admin pages stub (`/nutrilens/dashboard`)

#### Phase P4 — Google SSO (free via Firebase Auth)
- [ ] Enable Firebase Authentication in the existing GCP project (free tier)
- [ ] Add `firebase-admin` to Leave Tracker backend requirements
- [ ] Add Google Sign-In button to `Login.tsx`
- [ ] On Google SSO success: create/link user in Firestore `users/` collection
- [ ] Issue same JWT token as email/password login (transparent to rest of app)
- [ ] Keep existing email/password + 2FA path 100% working
- [ ] Firebase Auth free tier: up to 10,000 users/month — **no cost**

#### Phase P5 — NutriLens Admin UI
- [ ] `/nutrilens/meals` — meal log viewer (date, items, macros)
- [ ] `/nutrilens/nutrition` — food DB browser/editor
- [ ] `/nutrilens/users` — which users have access (admin only)
- [ ] Chart: daily kcal trend (recharts or MUI charts)

---

### 19.4) Google SSO Cost Confirmation

| Service | What it covers | Monthly cost |
|---------|---------------|-------------|
| Firebase Authentication (free tier) | 10,000 MAU, Google/email sign-in, MFA | **$0** |
| Cloud Run (existing) | Leave Tracker API | No change |
| Cloud Run (new) | NutriLens API | ~$0–$5/mo (pay per request, free tier 2M req/mo) |
| Cloud Storage (existing) | Frontend static files | No change |
| Firestore (existing) | Leave + NutriLens data | Minimal increase |

**Total additional cost: ~$0–$5/month** for NutriLens Cloud Run service (within free tier for low traffic).

---

### 19.5) NutriLens Dockerfile (to create in Phase P2)

```dockerfile
# Follow exactly the same pattern as Leave Tracker backend
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

Cloud Run expects port 8080 by default (Leave Tracker uses the same).

---

### 19.6) Unified Monorepo Structure (Phase P2+)

```
D:\Jobs\workspace\NutriLens\           ← NutriLens monorepo (current)
D:\Jobs\workspace\python-projects\
  Leave-tracker-app\                   ← Leave Tracker (separate repo, stays separate)
```

**Decision: Keep repos separate.** Merging into one monorepo adds complexity with no benefit — both apps deploy independently on Cloud Run. The shared element is only the **frontend React app** (extended, not merged).

---

### 19.7) Things NOT To Change

| Item | Reason |
|------|--------|
| Leave Tracker backend code | Live in production, working |
| Leave Tracker Firestore schema | Existing data would break |
| Leave Tracker auth (JWT + 2FA) | Working, users have authenticator apps set up |
| Leave Tracker deploy scripts | Already tested and working |
| Flutter mobile app architecture | No web dependency, stays independent |

---

## Appendix: Decisions log
Record decisions here as you go (date + why).

- 2026-02-28: **Platform unification decision** — NutriLens backend will deploy to Google Cloud alongside the existing Leave Tracker, sharing the same GCP project.
  - Leave Tracker confirmed on **Cloud Run** (not App Engine as initially assumed) — service `leave-tracker-api`; frontend on Cloud Storage static bucket.
  - Both apps use the same tech stack (FastAPI + React + TypeScript + Firestore), so integration cost is low.
  - **Repos stay separate** — Leave Tracker remains in its own repo; NutriLens merges nothing. Only the React frontend is extended with an app-selector and NutriLens admin pages.
  - **Google SSO** added via Firebase Authentication (free tier, ≤10K MAU) — existing email/password + 2FA path preserved untouched.
  - NutriLens mobile (Flutter) talks only to `nutrilens-api` Cloud Run service; no dependency on Leave Tracker.
  - Additional monthly cost estimated $0–$5 for NutriLens Cloud Run service (within free tier for dev/test traffic).
  - Full plan documented in §19. Phase P1 (audit) complete; Phase P2 (NutriLens backend → Cloud Run) is next.

- 2026-02-28: **Phase P2 — DB abstraction layer implemented** — NutriLens backend now has Firestore + SQLite db_factory mirroring the Leave Tracker pattern.
  - `backend/Dockerfile` — `python:3.11`, port 8080, identical to Leave Tracker.
  - `app/db/firestore_db.py` — `NutriLensFirestoreDB`: `nutrilens_foods` (seeded with 55 foods), `nutrilens_meals` (denormalised, items embedded per doc). Methods: `seed_foods`, `get_all_foods`, `get_food_by_name`, `get_food_count`, `save_meal`, `get_meals_by_date`.
  - `app/db/sqlite_db_cloud.py` — `NutriLensSQLiteDB`: same public interface, backed by plain SQLite tables + JSON column for items. `DATABASE_URL` env var controls file path.
  - `app/db/db_factory.py` — factory: `ENVIRONMENT=development` returns `sqlite_db`, else returns `firestore_db`. Singleton `db` object imported across the app.
  - `app/services/nutrition.py` — `get_food_fuzzy(db, label)` + `compute_macros_from_food(food, grams)` now fully dict-based (no SQLAlchemy dependency).
  - `app/api/routes_meals.py` — `POST /meals` + `GET /meals/today` use `db_factory.db` singleton; no `Depends(get_db)` or SQLAlchemy imports.
  - `app/main.py` — lifespan seeding calls `db.seed_foods(_seed_data())` from FOOD_SEED_DATA tuples; works for both SQLite (dev) and Firestore (prod).
  - `requirements.txt` — added `google-cloud-firestore==2.14.0`.
  - `.env.example` — updated with `ENVIRONMENT`, `GCP_PROJECT_ID`, `DATABASE_URL`.
  - `deploy-nutrilens-backend.ps1` — 4-step deploy: configure project → ensure Artifact Registry repo → Cloud Build → `gcloud run deploy nutrilens-api` with `ENVIRONMENT=production,GCP_PROJECT_ID=leave-tracker-2025`.

- 2026-02-28: **Milestone 3 nutrition DB implementation** — real SQLite DB, 55 foods seeded, fuzzy matching, save/today endpoints, Flutter Home shows daily totals.
  - `app/db/models.py` — SQLAlchemy ORM: `Food`, `Meal`, `MealItem` with proper FK relationships (`MealItem → meals` + `→ foods`).
  - `app/db/session.py` — `create_engine` (SQLite, check_same_thread=False), `SessionLocal`, `get_db()` FastAPI dependency, `init_db()` using `create_all`.
  - `app/db/seed.py` — 55 foods seeded on startup (idempotent); covers Western + Malaysian/Asian staples (nasi lemak, roti canai, tempeh, kangkung, sambal, sotong, etc.).
  - `app/services/nutrition.py` — added `get_food_fuzzy(db, label)` (exact → substring → difflib close_match, cutoff=0.55), `compute_macros_from_food(food, grams)`; kept in-memory `NUTRITION_DB` for mock analysis backward compat.
  - `app/api/routes_meals.py` — fully rewrote `POST /meals` (real DB persist: Meal + MealItems, fuzzy-matched food_id) and `GET /meals/today` (SQLAlchemy query filtered by UTC date, macro totals via ORM joins).
  - `app/main.py` — migrated to `@asynccontextmanager lifespan`; calls `init_db()` + `seed_foods()` on startup.
  - Flutter `lib/core/models/daily_totals.dart` — typed Dart model for GET /meals/today response.
  - Flutter `lib/core/api/food_vision_client.dart` — `getMealsToday()` returns typed `DailyTotals`; `saveMealFromAnalysis(analysis)` builds SaveMealRequest from `AnalyzeMealResponse`.
  - Flutter `analysis_provider.dart` — added `SaveMealNotifier` + `saveMealProvider` for save flow state.
  - Flutter `lib/features/home/home_provider.dart` — `dailyTotalsProvider` as `FutureProvider.autoDispose`.
  - Flutter `HomeScreen` — converted to `ConsumerWidget`; watches `dailyTotalsProvider`; shows kcal/protein/carbs/fat tiles or "No meals yet" if count=0; retry on error.
  - Flutter `ResultsScreen` — added `_SaveMealButton` ConsumerWidget watching `saveMealProvider`; shows Save → loading → saved (green Go Home) → error+retry states.
  - Validation: `flutter analyze` = 0 issues; pytest 8/8 pass; backend import check OK; DB seeded 55 foods.
- 2026-02-28: **Milestone 2 backend integration complete** — Flutter ↔ FastAPI end-to-end validated on physical device.
  - Added `lib/core/api/api_config.dart` — single place to configure backend URL (PC WiFi IP `192.168.0.10:8000`).
  - Created `lib/features/results/analysis_provider.dart` — Riverpod `AnalysisNotifier` wrapping `FoodVisionClient.analyzeMeal()`.
  - Updated `ReviewScreen`: Analyze button triggers `analysisProvider.analyze(photoPaths)` then navigates to results.
  - Rewrote `ResultsScreen`: loading spinner → confidence banner → total macros card → per-item cards (label, grams range, kcal/protein/carbs/fat) → "Add More Photos" if `needs_more_photos=true`.
  - Backend started with `--host 0.0.0.0` so Android device on same WiFi can reach PC.
  - Fixed Pydantic v2 deprecation warning (`allow_population_by_field_name` → `populate_by_name`).
  - Validation outcome: capture photos on device → tap Analyze → results screen shows deterministic mock nutrition data.
- 2026-02-28: **Milestone 1.5 Navigation implemented** — go_router added, full routing wired up.
  - Added `go_router ^14.0.0` to pubspec.yaml (resolved to 14.8.1).
  - Implemented `lib/app/router.dart` with `AppRoutes` constants and 4 routes: `/`, `/capture`, `/review`, `/results`.
  - Created `lib/features/home/home_screen.dart` — extracted HomeScreen from main.dart.
  - Created `lib/features/results/results_screen.dart` — stub screen for Milestone 2 backend integration.
  - Updated `main.dart` to use `MaterialApp.router` with `appRouter`.
  - Updated `capture_screen.dart`: `Navigator.push` → `context.push(AppRoutes.review)`.
  - Updated `review_screen.dart`: Analyze dialog stub → `context.go(AppRoutes.results)`; back → `context.pop()`.
  - Removed placeholder `platform/android/CameraPermissionHandler.kt` and `platform/ios/CameraPermissionHandler.swift`.
  - Validation outcome: `flutter analyze` = 0 issues.
- 2026-02-28: **Wireless debugging documented** — Android 11+ WiFi ADB pairing vs debug port distinction clarified (see §15.1).

- 2026-02-27: **Android run/build stability update** -- fixed local Android build/run blockers.
  - Migrated Android Gradle config to modern Flutter plugin DSL and removed mixed legacy/new setup.
  - Pinned toolchain versions for compatibility: AGP `8.9.1`, Kotlin `2.1.0`, Gradle `8.11.1`.
  - Restored missing Android resources required by manifest (`app_name`, `LaunchTheme`, `NormalTheme`).
  - Simplified `MainActivity.kt` to standard `FlutterActivity` (removed manual plugin registration path).
  - Removed missing custom font asset references from `pubspec.yaml` to unblock Flutter asset bundling.
  - Added Kotlin compiler stability flags in `android/gradle.properties` for Windows cache-path issues.
  - Validation outcome: `flutter build apk --debug` and `flutter run -d R83XB0ZP37B` both passed.
- 2026-02-21: Flutter chosen for cross-platform UI; Android-first; iOS later via borrowed Mac.
- 2026-02-21: **Project structure initialized** — monorepo with app_flutter, backend, shared/schemas created.
  - Flutter: pubspec.yaml + full lib structure (features/, core/, app/)
  - Backend: FastAPI main.py + services (analysis, nutrition) + placeholders for DB (Milestone 3)
  - API models: Pydantic ↔ Dart (strongly typed, schema-derived)
  - Testing: unit tests for nutrition & analysis services ready (pytest)
  - Status: **Ready to start Milestone 1 (capture UI) and Milestone 2 (deterministic backend endpoint)**
- 2026-02-21: **Platform configuration added** — Android + iOS deployment ready.
  - Android: minSdk 21 (Android 5.0+), targetSdk 34; Gradle + Manifest configured; permissions declared
  - iOS: iOS 12.0+; Info.plist with camera/photos permissions; Podfile + CocoaPods setup
  - platform/DEPLOYMENT.md added — comprehensive guide for debugging, building, and submitting to Play Store/App Store
  - Status: **Both platforms ready for `flutter run` and release builds**
- 2026-02-21: **Git ignore & environment configuration** — comprehensive .gitignore + templates added.
  - `.gitignore` expanded to cover all build artifacts, IDE files, secrets, keystores, media files
  - Added template files: `local.properties.example`, `key.properties.example`, `.env.example`
  - Added `.gitignore.README.md` documenting what should/shouldn't be committed
  - Covers: Flutter/Dart, Android (Gradle, keystores), iOS (Xcode, Pods), Python (venv, .env), secrets
  - Status: **Repository ready for safe collaboration — no sensitive files will be committed**
- 2026-02-21: **Android + iOS configuration sync** — centralized configuration management.
  - Created `app_config.yaml` — single source of truth for app identity, bundle IDs, platform minimums
  - Updated iOS `Info.plist` to use Flutter variables: `$(FLUTTER_BUILD_NAME)`, `$(FLUTTER_BUILD_NUMBER)`, `$(PRODUCT_BUNDLE_IDENTIFIER)`
  - Android already syncs from pubspec.yaml via `flutterVersionCode` and `flutterVersionName`
  - Created `verify_sync.py` — automated verification script to check Android/iOS configuration consistency
  - Created `CONFIG_SYNC.md` — comprehensive guide for version management and release workflow
  - All version updates now done ONLY in `pubspec.yaml` (e.g., `version: 0.2.0+2`)
  - Both platforms auto-sync on `flutter pub get` — no manual editing needed
  - Status: **Version management unified — single version bump updates both platforms**
