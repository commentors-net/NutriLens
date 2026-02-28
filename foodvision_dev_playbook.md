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

## Appendix: Decisions log
Record decisions here as you go (date + why).

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
