import 'package:flutter/material.dart';

/// Keeps the selected mode above the navigator so every route shares it.
class ThemedApp extends StatefulWidget {
  const ThemedApp({super.key, required this.home});

  final Widget home;

  @override
  State<ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<ThemedApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) => ThemeSettings(
    mode: _mode,
    onChanged: (mode) => setState(() => _mode = mode),
    child: MaterialApp(
      onGenerateTitle: (context) =>
          View.of(context).platformDispatcher.locale.languageCode == 'zh'
          ? '栖色'
          : 'VelaX',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF65745B)),
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF65745B),
          brightness: Brightness.dark,
        ),
      ),
      home: widget.home,
    ),
  );
}

class ThemeSettings extends InheritedWidget {
  const ThemeSettings({
    super.key,
    required this.mode,
    required this.onChanged,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static ThemeSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeSettings>()!;

  @override
  bool updateShouldNotify(ThemeSettings oldWidget) => mode != oldWidget.mode;
}
