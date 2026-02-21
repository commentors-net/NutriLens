# NutriLens / FoodVision

> Multi-photo food logging + AI analysis for weight loss and athletic performance

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

## Overview

FoodVision is an AI-powered food logging app that analyzes 3-6 photos of your meals to:
- 🔍 **Detect food items** with confidence scores
- ⚖️ **Estimate portion sizes** in grams (with uncertainty ranges)
- 📊 **Calculate nutrition** (calories, protein, carbs, fat)
- 🎯 **Request more photos** when confidence is low
- ✏️ **Allow corrections** for continuous improvement

**Target Users:** Weight loss journeys, athletes tracking macros, health-conscious individuals

---

## Project Structure

```
NutriLens/
├── app_flutter/           # Flutter mobile app (Android + iOS)
│   ├── lib/              # Dart source code
│   ├── android/          # Android platform config
│   ├── ios/              # iOS platform config
│   ├── app_config.yaml   # Centralized app configuration
│   ├── verify_sync.py    # Android/iOS sync verification
│   ├── QUICKSTART.md     # Quick start guide
│   └── CONFIG_SYNC.md    # Version management guide
│
├── backend/              # FastAPI backend service
│   ├── app/             # Python source code
│   │   ├── api/         # REST API routes
│   │   ├── models/      # Pydantic schemas
│   │   ├── services/    # Business logic (analysis, nutrition)
│   │   └── db/          # Database models
│   ├── tests/           # Backend tests (pytest)
│   └── .env.example     # Environment variables template
│
├── shared/              # Shared resources
│   ├── schemas/         # JSON schemas (source of truth)
│   └── docs/            # Additional documentation
│
├── foodvision_dev_playbook.md  # Complete development guide
└── README.md            # This file
```

---

## Quick Start

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio or VS Code
- Python 3.10+
- Xcode (macOS only, for iOS)

### Setup & Run

**1. Flutter App**
```bash
cd app_flutter
flutter pub get
flutter run  # Starts on connected device/emulator
```

**2. Backend**
```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
uvicorn app.main:app --reload
```

**3. API Documentation**
- Health: http://localhost:8000/health
- Swagger: http://localhost:8000/docs

See [app_flutter/QUICKSTART.md](app_flutter/QUICKSTART.md) for detailed setup instructions.

---

## Key Features

### Multi-Photo Capture
- Minimum 3 photos, recommended 5-6
- Guided angles (top-down, left, right, closeup)
- Review screen with retake/remove options

### AI Analysis (MVP: Deterministic Mocks)
- Detects food items with confidence scores
- Estimates grams with min/max ranges
- Suggests additional photos when confidence is low
- Returns warnings for uncertain elements (oil, sauce)

### Nutrition Calculation
- Per-item macros (calories, protein, carbs, fat)
- Total meal summary
- Based on per-100g nutrition database

### User Corrections
- Edit food labels
- Adjust gram estimates
- Corrections stored for model improvement

---

## Development Guide

### Version Management

All version info is centralized in `app_flutter/pubspec.yaml`:
```yaml
version: 0.1.0+1
       # ^^^^^^ ^
       # |      └─ Build number
       # └──────── Version name
```

**To update version:**
1. Edit `pubspec.yaml`
2. Run `flutter pub get`
3. Verify: `python verify_sync.py`

Both Android and iOS will auto-sync!

See [app_flutter/CONFIG_SYNC.md](app_flutter/CONFIG_SYNC.md) for details.

### Milestones

- [x] **M0: Project Setup** — Monorepo structure, Android + iOS config
- [ ] **M1: Capture UI** — Multi-photo capture flow (Flutter)
- [ ] **M2: Backend Skeleton** — Deterministic mock analysis (FastAPI)
- [ ] **M3: Nutrition DB** — Real nutrition data + calculations
- [ ] **M4: AI Integration** — Cloud inference for food detection

See [foodvision_dev_playbook.md](foodvision_dev_playbook.md) for complete milestones.

---

## API Contract

### POST /meals/analyze
**Request:** Multipart form-data
- `images[]`: 3-8 JPEG/PNG files
- `metadata`: Optional JSON string

**Response:** JSON
```json
{
  "overall_confidence": 0.75,
  "needs_more_photos": false,
  "suggested_next_shots": [],
  "items": [
    {
      "item_id": "tmp-1",
      "label": "white rice",
      "label_confidence": 0.85,
      "grams_estimate": 180,
      "grams_range": {"min": 130, "max": 240},
      "grams_confidence": 0.65,
      "macros": {"kcal": 234, "protein_g": 4.3, "carbs_g": 51.5, "fat_g": 0.6}
    }
  ],
  "warnings": []
}
```

Schema: [shared/schemas/analyze_meal_response.schema.json](shared/schemas/analyze_meal_response.schema.json)

---

## Testing

### Flutter
```bash
cd app_flutter
flutter test
```

### Backend
```bash
cd backend
pytest
# With coverage:
pytest --cov=app tests/
```

### Configuration Sync
```bash
cd app_flutter
python verify_sync.py
```

---

## Building for Release

### Android
```bash
flutter build appbundle --release  # Google Play Store
flutter build apk --release         # Direct install
```

### iOS (macOS only)
```bash
flutter build ios --release
# Then archive in Xcode: Product → Archive
```

See [app_flutter/platform/DEPLOYMENT.md](app_flutter/platform/DEPLOYMENT.md) for detailed deployment guide.

---

## Documentation

| Document | Description |
|----------|-------------|
| [foodvision_dev_playbook.md](foodvision_dev_playbook.md) | Complete development guide |
| [app_flutter/QUICKSTART.md](app_flutter/QUICKSTART.md) | Quick start guide |
| [app_flutter/CONFIG_SYNC.md](app_flutter/CONFIG_SYNC.md) | Version management |
| [app_flutter/platform/DEPLOYMENT.md](app_flutter/platform/DEPLOYMENT.md) | Deployment guide |
| [.gitignore.README.md](.gitignore.README.md) | Git configuration |
| [shared/schemas/](shared/schemas/) | API schemas |

---

## Architecture Decisions

### Why Flutter?
- Cross-platform (Android + iOS from single codebase)
- Fast development + hot reload
- Native camera integration

### Why FastAPI?
- Modern Python async framework
- Auto-generated API docs (Swagger)
- Pydantic validation
- Easy ML model integration

### Why Monorepo?
- Single source of truth for API contracts
- Easy to keep schemas in sync
- Simplified versioning

---

## Contributing

1. Clone the repository
2. Create a feature branch: `feat/your-feature-name`
3. Make changes and test
4. Verify config sync: `python verify_sync.py`
5. Run tests: `flutter test` and `pytest`
6. Commit with conventional commits: `feat: add capture guidance overlay`
7. Submit pull request

---

## License

Proprietary. All rights reserved.

---

## Contact

For questions or issues, refer to [foodvision_dev_playbook.md](foodvision_dev_playbook.md) or open an issue.

---

**Status:** ✅ Project structure complete, ready for Milestone 1 (Capture UI) and Milestone 2 (Backend skeleton)

