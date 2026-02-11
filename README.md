# aitranslate

**Minimal API. Maximum reach.**

`aitranslate` lets Flutter developers write UI labels in their own language and ship the app to every locale — without maintaining a single translation file.

Instead of `.arb` files, spreadsheets, or manual `Intl` wiring, you wrap text with `context.tr()` and an AI backend (currently Google Gemini) translates it at runtime. The result is cached per locale, so each string is translated only once.

## Why aitranslate?

| Traditional i18n | aitranslate |
|---|---|
| Create & maintain `.arb` / `.json` files for every locale | Write labels once in your native language |
| Coordinate with translators for each release | AI translates automatically at runtime |
| Ambiguous terms produce wrong translations | Provide `meaning` and `description` per-text to disambiguate |
| Brand names get mistranslated | Define a `glossary` to protect specific terms |

## Quick Start

```yaml
dependencies:
  aitranslate: ^0.0.1
```

```dart
import 'package:aitranslate/aitranslate.dart';
import 'package:flutter/material.dart';

void main() {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the controller with a backend
  final controller = TranslationController(
    sourceLanguage: 'en', // Language of the text to be translated
    backend: GeminiTranslationBackend(
      apiKey: 'YOUR_GEMINI_API_KEY',
    ),
  );

  runApp(
    TranslationProvider(
      controller: controller,
      child: const MyApp(),
    ),
  );
}
```

Then, anywhere in your widget tree:

```dart
Text(context.tr('Hello, World!'))
```

That's it. No `setState`, no `FutureBuilder`, no async boilerplate.

`tr()` returns the original text synchronously on the first call, then fires off a translation request in the background. Once the AI responds, **only the widgets that called `tr()` for that text are rebuilt** — the rest of the widget tree is completely untouched. From the developer's perspective the translated text simply "appears" in place.

## Context-Aware Translation

A single English word like **"Home"** can mean *home screen* or *home address*. Traditional i18n gives no way to distinguish them. `aitranslate` does:

```dart
// → ホーム (home screen in Japanese)
context.tr('Home',
  translationContext: TranslationContext(meaning: 'home screen'),
)

// → 自宅 (home address in Japanese)
context.tr('Home',
  translationContext: TranslationContext(meaning: 'user address'),
)
```

Each unique `(text, context)` pair is cached independently, so the same source string can produce different translations where needed.

### TranslationContext Fields

| Field | Purpose |
|---|---|
| `description` | Describes *where* or *how* the text is used (e.g. `'Navigation bar title'`) |
| `meaning` | Disambiguates the *sense* of the word (e.g. `'home screen'` vs `'user address'`) |
| `glossary` | A list of `GlossaryEntry` items that instruct the translator how to handle specific terms |

## Glossary — Protect Your Brand Names

Technical terms and brand names are often mistranslated. A `GlossaryEntry` tells the AI exactly how to treat them:

```dart
final controller = TranslationController(
  sourceLanguage: 'en',
  globalContext: TranslationContext(
    description: 'A fitness tracking app',
    glossary: [
      GlossaryEntry(term: 'Flutter', instruction: 'Framework name, do not translate'),
      GlossaryEntry(term: 'Dart',    instruction: 'Programming language, do not translate'),
    ],
  ),
  backend: GeminiTranslationBackend(apiKey: '...'),
);
```

- **Global glossary** — set on `TranslationController` and applied to every translation.  
- **Per-text glossary** — set on individual `tr()` calls; entries override the global glossary when the same term appears in both.

## Architecture

```
context.tr('Hello')
    │
    ▼
TranslationController
    ├── merge global + per-text context
    ├── check cache (per locale)
    │     hit  → return immediately
    │     miss → queue for batch translation
    ▼
TranslationBackend.translateBatch()   ← pluggable
    │
    ▼
  cache result → rebuild only affected widgets
```

- **Batching** — all `tr()` calls made during a single build frame are collected and sent in one API call, minimizing network overhead.  
- **Surgical rebuild** — the controller tracks the exact `Element` that requested each translation. When a result arrives, `markNeedsBuild()` is called on those elements alone — **no `notifyListeners()`, no subtree-wide rebuild**. Widgets that already have a cached translation are never touched.  
- **Locale-aware cache** — translations are stored per locale. Switching locales at runtime triggers re-translation only for strings not yet cached in the new locale.

## API Reference

### Core Classes

| Class | Role |
|---|---|
| `TranslationProvider` | `InheritedNotifier` that provides the controller to the widget tree |
| `TranslationController` | Manages cache, batching, and locale changes |
| `TranslationBackend` | Abstract interface for pluggable translation engines |
| `GeminiTranslationBackend` | Built-in backend powered by Google Gemini |
| `TranslationContext` | Optional context (description, meaning, glossary) to improve accuracy |
| `GlossaryEntry` | A term + instruction pair for the translator |

### Translation Functions

```dart
// Extension method (recommended)
context.tr('Text')
context.tr('Text', translationContext: TranslationContext(meaning: '...'))

// Top-level function (equivalent)
tr(context, 'Text')
tr(context, 'Text', translationContext: TranslationContext(meaning: '...'))
```

## Supported Backends

| Backend | Status |
|---|---|
| Google Gemini (`GeminiTranslationBackend`) | ✅ Built-in |
| Custom | Implement `TranslationBackend` |

### Creating a Custom Backend

`TranslationBackend` is a simple abstract class with a single method to implement. You can plug in any translation API — OpenAI, Grok, Anthropic, DeepL, or even an on-device model.

```dart
import 'package:aitranslate/aitranslate.dart';

class OpenAiTranslationBackend implements TranslationBackend {
  final String apiKey;

  OpenAiTranslationBackend({required this.apiKey});

  @override
  Future<List<String>> translateBatch(
    List<TranslationRequestItem> items, {
    required String from,
    required String to,
  }) async {
    // Build a prompt from items.
    // Each item has:
    //   item.text    — the string to translate
    //   item.context — optional TranslationContext with description,
    //                   meaning, and glossary
    final prompt = items.map((item) {
      var entry = item.text;
      if (item.context?.meaning != null) {
        entry += ' (meaning: ${item.context!.meaning})';
      }
      return entry;
    }).toList();

    // Call the OpenAI API (pseudo-code)
    final response = await callOpenAiApi(
      model: 'gpt-4o',
      systemPrompt: 'Translate the following texts from $from to $to. '
          'Return a JSON array of translated strings.',
      userMessage: jsonEncode(prompt),
      apiKey: apiKey,
    );

    return (jsonDecode(response) as List).cast<String>();
  }

  @override
  void dispose() {}
}
```

Then pass it to `TranslationController`:

```dart
final controller = TranslationController(
  sourceLanguage: 'en',
  backend: OpenAiTranslationBackend(apiKey: '...'),
);
```

## License

See [LICENSE](LICENSE) for details.
