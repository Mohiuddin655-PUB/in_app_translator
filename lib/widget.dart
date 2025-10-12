import 'package:flutter/material.dart';

import 'translator.dart';

class TranslatableTextBuilder extends StatelessWidget {
  final String data;
  final Locale? locale;
  final bool cached;
  final Widget Function(BuildContext context, String value) builder;

  const TranslatableTextBuilder(
    this.data, {
    super.key,
    this.locale,
    this.cached = false,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final translator = cached ? Translator.cached : Translator.shared;
    return ListenableBuilder(
      listenable: translator,
      builder: (context, child) {
        return builder(
          context,
          translator.tr(data, locale),
        );
      },
    );
  }
}
