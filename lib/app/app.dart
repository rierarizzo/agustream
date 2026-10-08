import 'package:flutter/material.dart';

import '../ui/screens/home_screen.dart';

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
      home: const HomeScreen(),
    );
  }
}
