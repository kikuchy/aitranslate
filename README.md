# aitranslate

**Minimal API. Maximum reach.**

`aitranslate` lets Flutter developers write UI labels in their own language and ship the app to every locale — without maintaining a single translation file.

Instead of `.arb` files, spreadsheets, or manual `Intl` wiring, you wrap text with `context.tr()` and an AI backend translates it at runtime. Translations are **cached per locale and persisted to disk**, so each string is translated only once — even across app restarts.

## Why aitranslate?

| Traditional i18n | aitranslate |
|---|---|
| Create & maintain `.arb` / `.json` files for every locale | Write labels once in your native language |
| Coordinate with translators for each release | AI translates automatically at runtime |
| Ambiguous terms produce wrong translations | Provide `meaning` and `description` per-text to disambiguate |
| Brand names get mistranslated | Define a `glossary` to protect specific terms |
| Translations lost on restart | Cache persisted to disk; instant display on relaunch |
| Locked into one translation service | Swap backends (Gemini, OpenAI, Anthropic…) with one line |

## Example

<img src="doc/auto_translating_example.gif" alt="Auto-translating example" width="400">

See [example](example). There are no pre-translated labels in Japanese, Chinese, Korean, or any other language!
No need to build translation files or maintain them at all!


## Quick Start

```bash
flutter pub add aitranslate
```

```dart
import 'package:aitranslate/aitranslate.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = TranslationController(
    sourceLanguage: 'en', // Language of your source text
    backend: GeminiTranslationBackend(
      apiKey: 'YOUR_GEMINI_API_KEY',
    ),
    cacheStore: JsonFileCacheStore(), // Persist translations to disk
  );

  // Restore cached translations before the first frame
  await controller.loadCache();

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

## Persistent Cache

Translations are expensive to generate but rarely change. `aitranslate` solves this with a **pluggable cache store**:

```dart
final controller = TranslationController(
  sourceLanguage: 'en',
  backend: GeminiTranslationBackend(apiKey: '...'),
  cacheStore: JsonFileCacheStore(), // Built-in JSON file persistence
);
await controller.loadCache(); // Restore before first build
```

- On the **first launch**, `tr()` calls trigger API requests. The results are cached in memory and automatically persisted to disk after a debounce interval.
- On **subsequent launches**, `loadCache()` restores everything instantly — **no network calls**, no loading spinners. The UI displays translated text from the very first frame.

### Pre-Populated Translations

Because the cache is just a JSON file, you can **ship pre-built translations** with your app. Prepare the cache file in advance with your own translations (or review and edit the AI-generated ones), and your users will never see untranslated text — even on first launch, even without network access.

## Architecture

```
context.tr('Hello')
    │
    ▼
TranslationController
    ├── merge global + per-text context
    ├── check in-memory cache (per locale)
    │     hit  → return immediately (no rebuild)
    │     miss → queue for batch translation
    ▼
TranslationBackend.translateBatch()   ← pluggable
    │
    ▼
  cache result → rebuild only affected widgets
    │
    ▼
  persist to CacheStore (debounced)   ← pluggable
```

- **Batching** — all `tr()` calls made during a single build frame are collected and sent in one API call, minimizing network overhead.  
- **Surgical rebuild** — the controller tracks the exact `Element` that requested each translation. When a result arrives, `markNeedsBuild()` is called on those elements alone — **no `notifyListeners()`, no subtree-wide rebuild**. Widgets that already have a cached translation are never touched.  
- **Locale-aware cache** — translations are stored per locale. Switching locales at runtime triggers re-translation only for strings not yet cached in the new locale.
- **Disk persistence** — after each translation batch, the cache is debounce-saved via `TranslationCacheStore`. On next launch, `loadCache()` restores it before the first frame.

## API Reference

### Core Classes

| Class | Role |
|---|---|
| `TranslationProvider` | `InheritedNotifier` that provides the controller to the widget tree |
| `TranslationController` | Manages cache, batching, persistence, and locale changes |
| `TranslationBackend` | Abstract interface for pluggable translation engines |
| `GeminiTranslationBackend` | Built-in backend — Google Gemini |
| `OpenAiTranslationBackend` | Built-in backend — OpenAI (and any compatible endpoint) |
| `AnthropicTranslationBackend` | Built-in backend — Anthropic Claude |
| `TranslationContext` | Optional context (description, meaning, glossary) to improve accuracy |
| `GlossaryEntry` | A term + instruction pair for the translator |
| `TranslationCacheStore` | Abstract interface for cache persistence |
| `JsonFileCacheStore` | Built-in file-based cache store |

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

| Backend | Service | Notes |
|---|---|---|
| `GeminiTranslationBackend` | Google Gemini | Default model: `gemini-2.0-flash` |
| `OpenAiTranslationBackend` | OpenAI and other compatible services (xAI Grok, Groq, Azure OpenAI, Ollama, etc. Set `baseUrl` to any OpenAI-compatible endpoint) | Default model: `gpt-4o-mini` |
| `AnthropicTranslationBackend` | Anthropic Claude | Default model: `claude-haiku-4-5-20251001` |

Switch providers with a single line:

```dart
// Google Gemini
backend: GeminiTranslationBackend(apiKey: '...')

// OpenAI
backend: OpenAiTranslationBackend(apiKey: '...')

// Anthropic Claude
backend: AnthropicTranslationBackend(apiKey: '...')

// xAI Grok (OpenAI-compatible)
backend: OpenAiTranslationBackend(
  apiKey: '...',
  model: 'grok-3-mini-fast',
  baseUrl: 'https://api.x.ai/v1',
)
```

All built-in backends support **structured JSON output** and **exponential backoff retry**:

```dart
backend: GeminiTranslationBackend(
  apiKey: '...',
  errorHandler: exponentialBackoff(maxRetries: 3),
)
```

### Creating a Custom Backend

Need DeepL, an on-device model, or your own translation service? Implement `TranslationBackend` — it's a single method:

```dart
class MyCustomBackend implements TranslationBackend {
  @override
  Future<List<String>> translateBatch(
    List<TranslationRequestItem> items, {
    required String from,
    required String to,
  }) async {
    // Each item has:
    //   item.text    — the string to translate
    //   item.context — optional TranslationContext with
    //                   description, meaning, and glossary
    return items.map((item) => yourTranslate(item.text, from, to)).toList();
  }

  @override
  void dispose() {}
}
```

## License

MIT License

See [LICENSE](LICENSE) for details.
