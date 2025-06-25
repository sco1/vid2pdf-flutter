import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'package:vid2pdf/ui.dart';

final baseContext = p.Context();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(isOptional: true); // TODO: Handle case where .env file is empty

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(size: Size(650, 600), center: true);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(MaterialApp(home: MainUI()));
}
