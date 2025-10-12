## IN_APP_TRANSLATOR

A lightweight Flutter localization manager that provides multi-locale support, automatic caching,
background translations, fallback locales, and easy integration via a flexible delegate system.

## Features

- **Multi-Locale Support**: Manage translations for multiple locales with fallback support.
- **Background Translation**: Automatically translates missing keys asynchronously.
- **Caching**: Stores translated strings to avoid redundant translation requests.
- **Sequential Task Queue**: Ensures translation requests are processed in order.
- **Delegate-Based**: Flexible integration with any translation service via `TranslatorDelegate`.
- **Singleton Access**: Easy global access using `Translator.i`.
- **Fallback Locale**: Automatically falls back to a default locale if a translation is missing.
- **Automatic Notification**: Notifies listeners when new translations are available (suitable for
  Flutter widgets).
- **Persistent Storage**: Optionally saves cached translations using delegate’s `save()` method.
- **Prevent Duplicate Requests**: Ensures the same key is not translated multiple times
  concurrently.
- **Dynamic Locale Switching**: Allows changing the active locale at runtime.
- **Lightweight**: Minimal dependencies and optimized for Flutter apps.

## Usage

```dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:in_app_translator/in_app_translator.dart';

/// Example custom delegate implementation
class ExampleTranslatorDelegate extends TranslatorDelegate {
  final Map<String, Map<String, String>> _translations = {
    'en_US': {'hello': 'Hello', 'goodbye': 'Goodbye'},
    'bn_BD': {'hello': 'হ্যালো', 'goodbye': 'বিদায়'},
  };

  @override
  Future<String> translate(String key, Locale locale) async {
    await Future.delayed(
      const Duration(milliseconds: 200),
    ); // simulate network delay
    final lang = locale.toString();
    return _translations[lang]?[key] ?? key;
  }

  @override
  void translated(String key, String value) {
    debugPrint('Translated: $key -> $value');
  }

  @override
  Future<String?> cache() async {
    debugPrint('Loading cache...');
    return null;
  }

  @override
  Future<void> save(String source) async {
    debugPrint('Saving cache: $source');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the translator singleton
  Translator.init(
    delegate: ExampleTranslatorDelegate(),
    defaultLocale: const Locale('en', 'US'),
    fallbackLocale: const Locale('en', 'US'),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyHome());
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  void _translateAll() async {
    Translator.cached.translateAll(
      const Locale('bn', 'BD'),
      onProgress: (value) {
        log("progress: $value");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Translator.cached,
      builder: (context, child) {
        final locale = Translator.cached.currentLocale.toString();
        return Scaffold(
          appBar: AppBar(
            title: const Text('In-App Translator Example'),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _translateAll,
            child: const Icon(Icons.language),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Locale: $locale'),
                const SizedBox(height: 12),
                Text('hello → ${Translator.cached.tr('hello')}'),
                Text('goodbye → ${Translator.cached.tr('goodbye')}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      Translator.cached.locale =
                      Translator.cached.currentLocale.languageCode == 'en'
                              ? const Locale('bn', 'BD')
                              : const Locale('en', 'US');
                    });
                  },
                  child: const Text('Toggle Locale'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## FLUTTER TEST
```dart
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
```
