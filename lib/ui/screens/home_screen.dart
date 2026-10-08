import 'package:flutter/material.dart';

/// Placeholder home screen.
///
/// Replaced in a later phase by the real catalog UI. It exists only to prove
/// that the layer skeleton compiles and the app boots. The app title is shown
/// by the custom title bar, not here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Agustream scaffold is running.'),
      ),
    );
  }
}
