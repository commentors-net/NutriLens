/// API configuration.
/// On Android device, localhost doesn't work — use your PC's local WiFi IP.
/// Run `ipconfig` (Windows) or `ifconfig` (Mac/Linux) to find it.
///
/// For Android Emulator, use 10.0.2.2 (maps to host machine localhost).
/// For physical device on same WiFi, use PC's local IP (e.g. 192.168.0.10).

const String kBackendHost = '192.168.0.10';
const int kBackendPort = 8000;
const String kBackendBaseUrl = 'http://$kBackendHost:$kBackendPort';
