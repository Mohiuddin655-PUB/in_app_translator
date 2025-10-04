import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_translator/translator.dart';

/// Example implementation of TranslatorDelegate
class MockTranslatorDelegate implements TranslatorDelegate {
  final Map<String, Map<String, String>> _translations = {
    'en_US': {
      'hello': 'Hello',
      'welcome': 'Welcome',
    },
    'fr_FR': {
      'hello': 'Bonjour',
      'welcome': 'Bienvenue',
    },
  };

  @override
  Future<String> translate(String source, Locale locale) async {
    await Future.delayed(Duration(milliseconds: 50)); // Simulate delay
    return _translations[locale.toString()]?[source] ?? source;
  }

  @override
  Future<String?> cache() async {
    return null; // No preloaded cache for this example
  }

  @override
  void save(String value) {
    print('Cache saved: $value'); // Optional save callback
  }

  @override
  void translated(String key, String value) {
    print('Translated "$key" -> "$value"');
  }
}

void main() {
  // Initialize Translator singleton
  Translator.init(
    defaultLocale: Locale('en', 'US'),
    fallbackLocale: Locale('fr', 'FR'),
    translator: MockTranslatorDelegate(),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Translator Example',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final translator = Translator.i;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translator Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(translator.tr('hello')),
            const SizedBox(height: 10),
            Text(translator.tr('welcome')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Switch locale dynamically
                  translator.locale = Locale('fr', 'FR');
                });
              },
              child: const Text('Switch to French'),
            ),
          ],
        ),
      ),
    );
  }
}
