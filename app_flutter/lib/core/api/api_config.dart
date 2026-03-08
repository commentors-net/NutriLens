/// API configuration.
/// Environment is now dynamically selected via environment provider.
/// See lib/core/config/environment.dart for details.

// Dynamic configuration - use apiBaseUrlProvider instead
// const String kBackendBaseUrl = 'https://nutrilens-api-2ajzj2dbrq-uc.a.run.app';

// Production (Cloud Run)
const String kBackendBaseUrlProd = 'https://nutrilens-api-2ajzj2dbrq-uc.a.run.app';

// Development (Local) — Change IP to your machine's IP if not using emulator
const String kBackendBaseUrlDebug = 'http://10.0.2.2:8000'; // For Android emulator
// const String kBackendBaseUrlDebug = 'http://192.168.0.10:8000'; // For physical device
