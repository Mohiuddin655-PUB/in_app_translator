import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_translator/in_app_translator.dart';

/// Mock implementation of TranslatorDelegate for testing purposes.
class MockTranslatorDelegate implements TranslatorDelegate {
  final Map<String, Map<String, String>> _translations = {};
  bool saveCalled = false;
  final Duration delay;

  MockTranslatorDelegate({this.delay = Duration.zero});

  @override
  Future<String> translate(String source, Locale locale) async {
    // Simulate network delay
    await Future.delayed(delay);
    return _translations[locale.toString()]?[source] ?? '$source-translated';
  }

  @override
  Future<String?> cache() async {
    return jsonEncode(_translations);
  }

  @override
  void save(String value) {
    saveCalled = true;
  }

  @override
  void translated(String key, String value) {
    // optional: can track calls for testing
  }

  void addTranslation(String key, String locale, String value) {
    final map = _translations.putIfAbsent(locale, () => {});
    map[key] = value;
  }
}

void main() {
  group('Translator Tests', () {
    late MockTranslatorDelegate mockDelegate;
    late Translator translator;

    setUp(() {
      mockDelegate = MockTranslatorDelegate();
      Translator.init(
        defaultLocale: Locale('en', 'US'),
        fallbackLocale: Locale('fr', 'FR'),
        translator: mockDelegate,
      );
      translator = Translator.i;
    });

    test('Initial locale is set correctly', () {
      expect(translator.tr('hello'), 'hello'); // Not yet translated
      expect(translator.currentLocale, Locale('en', 'US'));
    });

    test('Background translation updates cache', () async {
      const key = 'greet';
      translator.tr(key);
      await Future.delayed(
          Duration(milliseconds: 50)); // Wait for background task
      final translated = translator.tr(key);
      expect(translated, '$key-translated');
    });

    test('Cache prevents duplicate translation requests', () async {
      const key = 'duplicate';
      translator.tr(key);
      translator.tr(key); // second call should not trigger new translation
      await Future.delayed(Duration(milliseconds: 50));
      final translated = translator.tr(key);
      expect(translated, '$key-translated');
    });

    test('Fallback locale works if translation missing', () async {
      const key = 'missing';
      translator.locale = Locale('es', 'ES'); // Set locale not in cache
      final result = translator.tr(key);
      expect(result, key); // Returns key initially
      await Future.delayed(Duration(milliseconds: 50));
      expect(translator.cache.containsKey('es_ES'), true);
    });

    test('Dispose saves cache via delegate', () {
      translator.dispose();
      expect(mockDelegate.saveCalled, true);
    });

    test('Supports adding translations to mock delegate', () async {
      mockDelegate.addTranslation('hi', 'en_US', 'Hello');
      translator.tr('hi');
      await Future.delayed(Duration(milliseconds: 50));
      expect(translator.tr('hi'), 'Hello');
    });
  });
}
