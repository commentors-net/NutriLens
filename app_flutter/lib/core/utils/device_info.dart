import 'dart:io' show Platform;
import 'dart:ui' as ui;

/// Provides device and system environment details dynamically instead of hardcoded strings.
class DeviceInfo {
  /// Returns the device active locale formatted as language_COUNTRY (e.g., 'en_MY', 'en_US', 'ja_JP').
  /// Automatically reads the system locale from PlatformDispatcher, with fallback to Platform.localeName.
  static String getDeviceLocale() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final country = locale.countryCode;
      if (country != null && country.isNotEmpty) {
        return '${locale.languageCode}_$country';
      }
      if (locale.languageCode.isNotEmpty) {
        return locale.languageCode;
      }
    } catch (_) {}

    try {
      final osLocale = Platform.localeName;
      if (osLocale.isNotEmpty) {
        // Handle formats like en_US.UTF-8 or en-US
        return osLocale.split('.').first.replaceAll('-', '_');
      }
    } catch (_) {}

    return 'en_US';
  }

  /// Returns the current OS platform string (e.g., 'ios', 'android', 'macos', 'windows', 'linux').
  static String getDevicePlatform() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Returns the current app version name dynamically.
  static String getAppVersion() {
    return '0.1.0';
  }

  /// Returns whether running on a mobile platform (iOS or Android).
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Returns whether running on Apple iOS.
  static bool get isIOS => Platform.isIOS;

  /// Returns whether running on Android.
  static bool get isAndroid => Platform.isAndroid;
}
