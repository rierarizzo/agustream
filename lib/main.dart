import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/window/window_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowController.initialize();
  runApp(const AgustreamApp());
}
