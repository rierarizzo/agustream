import 'package:flutter/material.dart';

import '../ui/screens/home_screen.dart';
import '../ui/widgets/title_bar.dart';

/// Root widget of the application.
///
/// Owns the [MaterialApp], the theme, and the initial route. It is the app
/// shell only: no business logic belongs here.
class AgustreamApp extends StatelessWidget {
  const AgustreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agustream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      // The custom title bar lives above the Navigator so it stays put across
      // every route. It is transparent, letting the Mica backdrop show through.
      builder: (context, child) {
        return Column(
          children: [
            const TitleBar(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}
