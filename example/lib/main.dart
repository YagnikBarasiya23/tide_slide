import 'package:flutter/material.dart';
import 'package:tide_slide/tide_slide.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;
  TextDirection _dir = TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2563EB);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'tide_slide',
      themeMode: _mode,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) =>
          Directionality(textDirection: _dir, child: child!),
      home: Scaffold(
        appBar: AppBar(title: const Text('tide_slide')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Demo(title: 'Default', child: _Basic()),
            const _Demo(title: 'Async action with a spinner', child: _Async()),
            const _Demo(
              title: 'Disabled',
              child: TideSlide(
                label: 'Slide to pay',
                onConfirmed: _noop,
                enabled: false,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                FilterChip(
                  label: const Text('Dark'),
                  selected: _mode == ThemeMode.dark,
                  onSelected: (v) => setState(
                    () => _mode = v ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
                FilterChip(
                  label: const Text('Right to left'),
                  selected: _dir == TextDirection.rtl,
                  onSelected: (v) => setState(
                    () => _dir = v ? TextDirection.rtl : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _Demo extends StatelessWidget {
  const _Demo({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Basic extends StatefulWidget {
  const _Basic();

  @override
  State<_Basic> createState() => _BasicState();
}

class _BasicState extends State<_Basic> {
  final _controller = TideSlideController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TideSlide(
      label: 'Slide to pay',
      controller: _controller,
      resetAfter: const Duration(seconds: 2),
      onConfirmed: () => debugPrint('confirmed'),
    );
  }
}

class _Async extends StatelessWidget {
  const _Async();

  @override
  Widget build(BuildContext context) {
    return TideSlide(
      label: 'Slide to send',
      confirmedLabel: 'Sent',
      resetAfter: const Duration(seconds: 2),
      onConfirmed: () => Future<void>.delayed(const Duration(seconds: 2)),
    );
  }
}
