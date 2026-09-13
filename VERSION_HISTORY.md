# FoodVision Version History & Release Tracker

This log tracks all version increments across Android and iOS builds.

| Version | Version Name | Build Code | Date (Local) | Notes / Trigger | Previous Version |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 0.1.1+2 | 0.1.1 | 2 | 2026-09-13 13:16:07 | Hybrid Consensus AI (Gemini + Local Ollama), ATS LAN config, CI artifact workflow fix | `0.1.0+1` |
| 0.1.0+1 | 0.1.0 | 1 | 2026-09-13 | Initial mobile release baseline for Android and iOS | Initial Baseline |

---

### Release & Versioning Policy
- **Semantic Versioning:** `MAJOR.MINOR.PATCH+BUILD_NUMBER`
  - `MAJOR`: Breaking changes or major architectural redesigns.
  - `MINOR`: New features (e.g. multi-angle viewfinder, cloud photo sync, reports).
  - `PATCH`: Bug fixes, UI polishes, refactoring.
  - `BUILD_NUMBER`: Strictly incrementing integer required by Apple TestFlight/App Store and Google Play Console.
- **GitHub Actions Auto-Build:**
  - Every release workflow execution builds **both Android** (`.apk` and `.aab`) and **iOS** (`.ipa`).
  - Artifacts are automatically named with the version tag (e.g. `FoodVision-v0.1.0+1-Android-APK`).
