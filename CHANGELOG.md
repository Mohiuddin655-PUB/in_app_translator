## 1.0.0

# Translator Features

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

