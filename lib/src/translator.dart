import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'delegate.dart';

/// A Flutter [ChangeNotifier] that manages translations and caching.
/// Supports background translation, fallback locales, and sequential task queuing.
class Translator extends ChangeNotifier {
  /// Creates a new Translator instance.
  ///
  /// [delegate] is optional and handles the actual translation logic.
  /// [defaultLocale] is the initial locale used for translations.
  /// [fallbackLocale] is used when a translation is not found in the current locale.
  Translator({
    TranslatorDelegate? delegate,
    required Locale defaultLocale,
    required Locale fallbackLocale,
  })  : _delegate = delegate,
        _currentLocale = defaultLocale,
        _fallbackLanguage = fallbackLocale {
    // Load cache from delegate if available
    if (delegate != null) {
      delegate.cache().then((source) {
        if (source == null || source.isEmpty) return {};
        final x = jsonDecode(source);
        if (x is! Map) return {};
        final entries = x.entries.map((e) {
          final key = e.key;
          final value = e.value;
          if (value is! Map || key is! String) return null;
          final entries = value.entries.map((e) {
            final key = e.key;
            final value = e.value;
            if (value is! String || key is! String) return null;
            return MapEntry(key, value);
          }).whereType<MapEntry<String, String>>();
          return MapEntry<String, Map<String, String>>(
              key, Map.fromEntries(entries));
        }).whereType<MapEntry<String, Map<String, String>>>();
        final cache = Map.fromEntries(entries);
        _cache.addAll(cache);
        notifyListeners();
      });
    }
  }

  /// Optional delegate to handle actual translation operations.
  final TranslatorDelegate? _delegate;

  /// Fallback locale used when a translation is missing in the current locale.
  final Locale _fallbackLanguage;

  /// Currently active locale.
  Locale _currentLocale = Locale("en", "US");

  /// Currently active locale.
  Locale get currentLocale => _currentLocale;

  /// Internal cache of translations: locale -> key -> translated string
  final Map<String, Map<String, String>> _cache = {};

  /// Internal cache of translations: locale -> key -> translated string
  Map<String, Map<String, String>> get cache => _cache;

  /// Singleton instance of Translator.
  static Translator? _i;

  /// Access the singleton instance.
  static Translator get i => _i!;

  /// Initialize the singleton Translator instance.
  /// [translator] must implement [TranslatorDelegate].
  static void init({
    required Locale defaultLocale,
    required Locale fallbackLocale,
    required TranslatorDelegate translator,
  }) {
    _i = Translator(
      defaultLocale: defaultLocale,
      fallbackLocale: fallbackLocale,
      delegate: translator,
    );
  }

  /// Change the current active locale.
  set locale(Locale locale) => _currentLocale = locale;

  /// Sequential task queue to ensure translations are processed in order.
  Future<void> _taskQueue = Future.value();

  /// Tracks pending translations to prevent duplicate requests.
  final Map<String, Future<String>> _pendingTranslations = {};

  /// Internal method to queue a translation request in the background.
  void _translateInBackground(String key, Locale locale) {
    if (key.isEmpty || _delegate == null) return;

    final cacheKey = '${locale.toString()}::$key';

    // Skip if already queued/requested
    if (_pendingTranslations.containsKey(cacheKey)) return;

    // Chain the translation task
    final translationFuture = _taskQueue = _taskQueue.then((_) async {
      // Check if already cached
      if (_cache[locale.toString()]?.containsKey(key) ?? false) {
        return _cache[locale.toString()]![key]!;
      }

      final translated = await _delegate!.translate(key, locale);

      if (translated.isEmpty || translated == key) return key;

      // Update cache
      final localeCache = _cache[locale.toString()] ?? {};
      _cache[locale.toString()] = {...localeCache, key: translated};

      notifyListeners();
      _delegate!.translated(key, translated);

      return translated;
    }).whenComplete(() {
      _pendingTranslations.remove(cacheKey);
    });

    _pendingTranslations[cacheKey] = translationFuture;
  }

  /// Returns the translated string for the given [key] and optional [locale].
  /// If translation is not immediately available, returns [key] and translates in background.
  String tr(String key, [Locale? locale]) {
    locale ??= _currentLocale;
    final localeCache = _cache[locale.toString()] ?? {};
    if (localeCache.containsKey(key)) return localeCache[key] ?? key;
    if (_fallbackLanguage != locale) _cache[locale.toString()] = localeCache;
    _translateInBackground(key, locale);
    return key;
  }

  Future<String?> translate(String input, Locale locale) async {
    if (input.isEmpty || _delegate == null) return null;
    final translated = await _delegate!.translate(input, locale);
    if (translated.isEmpty || translated == input) return null;
    return translated;
  }

  /// Save cached translations to the delegate before disposal.
  @override
  void dispose() {
    if (_delegate != null) _delegate!.save(jsonEncode(_cache));
    super.dispose();
  }
}
