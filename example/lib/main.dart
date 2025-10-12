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
