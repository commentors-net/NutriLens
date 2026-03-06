/// API configuration.
/// Production: Cloud Run backend
/// Development: Local backend (use PC's local IP, e.g. 192.168.0.10)

// Production (Cloud Run)
const String kBackendBaseUrl = 'https://nutrilens-api-427212681311.us-central1.run.app';

// Development (Local) — uncomment to use local backend
// const String kBackendBaseUrl = 'http://192.168.0.10:8000';
