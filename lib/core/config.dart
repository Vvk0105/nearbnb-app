/// Where the app talks to. Change at build time, never in code:
///   flutter run --dart-define=API_ORIGIN=http://10.0.2.2:8000   (Android emulator -> the API on your PC)
///   flutter build appbundle                                       (defaults to the live API)
class AppConfig {
  static const apiOrigin = String.fromEnvironment('API_ORIGIN', defaultValue: 'https://api.nearbnb.com');
  static const apiBase = '$apiOrigin/api/v1';

  /// The website, for pages the app does not have (legal documents, host tools).
  static const webOrigin = String.fromEnvironment('WEB_ORIGIN', defaultValue: 'https://nearbnb.com');

  /// Photo paths come back as "/api/v1/media/...": they live on the API's host.
  static String? media(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$apiOrigin$path';
  }
}
