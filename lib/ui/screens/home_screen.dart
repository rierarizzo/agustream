import 'package:flutter/material.dart';

/// Placeholder home screen.
///
/// Replaced in a later phase by the real catalog UI. It exists only to prove
/// that the layer skeleton compiles and the app boots.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agustream')),
      body: const Center(
        child: Text('Agustream scaffold is running.'),
      ),
    );
  }
}
