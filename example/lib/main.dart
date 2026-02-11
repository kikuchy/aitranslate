import 'package:aitranslate/aitranslate.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = TranslationController(
    sourceLanguage: 'en',
    globalContext: TranslationContext(
      description: 'Flutter Demo App',
      glossary: [
        GlossaryEntry(
          term: 'Flutter',
          instruction: 'Name of a framework, do not translate',
        ),
        GlossaryEntry(
          term: 'Dart',
          instruction: 'Programming language name, do not translate',
        ),
      ],
    ),
    backend: GeminiTranslationBackend(
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    ),
  );

  runApp(TranslationProvider(controller: controller, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr(context, 'Flutter Demo'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(context.tr('Flutter Demo Home Page')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.tr('Number of times the button has been pressed:')),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 20),

            // Description examples

            // expected: "住所:" in Japanese
            Text(
              context.tr(
                'Address:',
                translationContext: TranslationContext(
                  description: 'Address label',
                  meaning: 'The place where you live',
                ),
              ),
            ),
            // expected: "アドレス:" in Japanese
            Text(
              context.tr(
                'Address:',
                translationContext: TranslationContext(
                  description: 'Address label',
                  meaning:
                      'A unique identifier (a reference) that points to the location in memory',
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: context.tr(
          'Increment',
          translationContext: TranslationContext(
            description: 'Tooltip label of increment button',
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
