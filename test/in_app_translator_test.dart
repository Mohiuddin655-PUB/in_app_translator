import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_translator/in_app_translator.dart';

// Mock delegate for testing
class MockTranslatorDelegate extends TranslatorDelegate {
  final List<String> translatedCalls = [];
  String? _cachedSource;

  @override
  Future<String> translate(String key, Locale locale) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final lang = locale.languageCode;
    return '[${lang.toUpperCase()}] $key';
  }

  @override
  void translated(String key, String value) {
    translatedCalls.add('$key=$value');
  }

  @override
  Future<String?> cache() async => _cachedSource;

  @override
  Future<void> save(String source) async {
    _cachedSource = source;
  }
}

void main() {
  group('Translator', () {
    late MockTranslatorDelegate delegate;
    late Translator translator;

    setUp(() async {
      delegate = MockTranslatorDelegate();
      Translator.init(
          delegate: delegate, defaultLocale: const Locale('en', 'US'));
      translator = Translator.cached;
    });

    test('initialization works', () async {
      expect(translator.currentLocale.languageCode, 'en');
      expect(translator.cache, isA<Map>());
      expect(translator.cache.isEmpty, true);
    });

    test('locale setter/getter works', () {
      translator.locale = const Locale('bn', 'BD');
      expect(translator.currentLocale.toString(), 'bn_BD');
    });

    test('tr() should return key immediately and cache later', () async {
      const key = 'hello';
      final result = translator.tr(key);
      expect(result, key); // Immediate fallback

      // Wait for background translation
      await Future.delayed(const Duration(milliseconds: 30));

      final cached = translator.cache['en_US']?[key];
      expect(cached, isNotNull);
      expect(cached, '[EN] hello');
    });

    test('translate() returns proper translated text', () async {
      final translated =
          await translator.translate('world', const Locale('bn', 'BD'));
      expect(translated, '[BN] world');
    });

    test('translateAll() translates all keys and tracks progress', () async {
      // Preload some cache
      translator.tr('apple');
      translator.tr('banana');
      await Future.delayed(const Duration(milliseconds: 50));

      double? progress;
      await translator.translateAll(
        const Locale('bn', 'BD'),
        onProgress: (v) => progress = v,
      );

      // Verify all keys exist in the new locale
      final cache = translator.cache['bn_BD']!;
      expect(cache.keys, containsAll(['apple', 'banana']));
      expect(cache['apple'], '[BN] apple');
      expect(cache['banana'], '[BN] banana');
      expect(progress, 1.0);
    });

    test('translateAll() saves cache when cachedMode is enabled', () async {
      // Preload some data to ensure translateAll has something to translate
      translator.tr('dog');
      translator.tr('cat');
      await Future.delayed(const Duration(milliseconds: 40));

      // Perform translation for new locale
      await translator.translateAll(const Locale('fr', 'FR'));

      // After translation, save() should have been called and cache not empty
      final saved = await delegate.cache();
      expect(saved, isNotNull);
      expect(saved!.isNotEmpty, true);

      final decoded = jsonDecode(saved);
      expect(decoded, isA<Map>());
      expect(decoded['fr_FR'], isA<Map>());
      expect(decoded['fr_FR'].keys, containsAll(['dog', 'cat']));
    });

    test('dispose() saves cache before closing', () async {
      translator.tr('hello');
      await Future.delayed(const Duration(milliseconds: 50));
      translator.dispose();

      final saved = await delegate.cache();
      expect(saved, isNotEmpty);

      final decoded = jsonDecode(saved!);
      expect(decoded, isA<Map>());
    });
  });
}
