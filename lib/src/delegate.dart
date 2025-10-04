import 'dart:ui';

/// An abstract delegate class to provide translation capabilities.
/// Implement this class to define how translations are fetched, cached, and stored.
abstract class TranslatorDelegate {
  /// Translate a given [source] string to the target [locale].
  /// Returns the translated string asynchronously.
  Future<String> translate(String source, Locale locale);

  /// Optionally provide a cached JSON source of previously translated strings.
  /// Default implementation returns null.
  Future<String?> cache() async => null;

  /// Callback triggered when a translation is completed.
  /// [key] is the original string, [value] is the translated string.
  void translated(String key, String value) {}

  /// Save the serialized translation cache.
  /// [value] is the JSON-encoded string of all translations.
  void save(String value) {}
}
