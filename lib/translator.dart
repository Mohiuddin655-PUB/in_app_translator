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
  Translator._({
    bool? cachedMode,
    TranslatorDelegate? delegate,
    Locale? defaultLocale,
    Locale? fallbackLocale,
  })  : _cachedMode = cachedMode ?? false,
        _delegate = delegate,
        _currentLocale = defaultLocale ?? const Locale('en', "US"),
        _fallbackLanguage = fallbackLocale ?? const Locale('en', "US") {
    // Load cache from delegate if available
    if (delegate != null && _cachedMode) {
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

  Translator.create({
    TranslatorDelegate? delegate,
    Locale? defaultLocale,
    Locale? fallbackLocale,
  }) : this._(defaultLocale: defaultLocale, fallbackLocale: fallbackLocale);

  final bool _cachedMode;

  /// Optional delegate to handle actual translation operations.
  final TranslatorDelegate? _delegate;

  /// Fallback locale used when a translation is missing in the current locale.
  final Locale _fallbackLanguage;

  /// Currently active locale.
  Locale _currentLocale = const Locale("en", "US");

  /// Currently active locale.
  Locale get currentLocale => _currentLocale;

  /// Internal cache of translations: locale -> key -> translated string
  final Map<String, Map<String, String>> _cache = {};

  /// Internal cache of translations: locale -> key -> translated string
  Map<String, Map<String, String>> get cache => _cache;

  /// Singleton instance of Translator.
  static Translator? _cached, _shared;

  /// Access the singleton cached instance.
  static Translator get cached => _cached ??= Translator._();

  /// Access the singleton shared instance.
  static Translator get shared {
    return _shared ??= Translator._(
      cachedMode: false,
      defaultLocale: _cached?._currentLocale,
      fallbackLocale: _cached?._fallbackLanguage,
      delegate: _cached?._delegate,
    );
  }

  /// Initialize the singleton Translator instance.
  /// [translator] must implement [TranslatorDelegate].
  static void init({
    required TranslatorDelegate delegate,
    Locale? defaultLocale,
    Locale? fallbackLocale,
  }) {
    _cached = Translator._(
      cachedMode: true,
      defaultLocale: defaultLocale,
      fallbackLocale: fallbackLocale,
      delegate: delegate,
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
      if (_cachedMode) _delegate!.save(jsonEncode(_cache));
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

  /// Translates all cached keys into the given [locale].
  /// Calls [onProgress] with values between 0.0 and 1.0 as translation progresses.
  Future<void> translateAll(
    Locale locale, {
    bool changeLocale = true,
    ValueChanged<double>? onProgress,
  }) async {
    if (_delegate == null) return;
    final allKeys = _cache.values.expand((m) => m.keys).toSet();
    if (allKeys.isEmpty) return;

    final localeKey = locale.toString();
    final localeCache = _cache[localeKey] ?? {};

    int completed = 0;
    final total = allKeys.length;

    for (final key in allKeys) {
      if (localeCache.containsKey(key)) {
        completed++;
        onProgress?.call(completed / total);
        continue;
      }

      final translated = await _delegate!.translate(key, locale);
      if (translated.isNotEmpty && translated != key) {
        localeCache[key] = translated;
        _delegate!.translated(key, translated);
      }

      completed++;
      onProgress?.call(completed / total);
    }

    _cache[localeKey] = localeCache;
    if (_cachedMode) _delegate!.save(jsonEncode(_cache));
    if (changeLocale) _currentLocale = locale;
    notifyListeners();
  }

  /// Save cached translations to the delegate before disposal.
  @override
  void dispose() {
    if (_delegate != null) _delegate!.save(jsonEncode(_cache));
    super.dispose();
  }
}
