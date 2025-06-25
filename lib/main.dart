import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'package:vid2pdf/ui.dart';

final baseContext = p.Context();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(isOptional: true);
  } on EmptyEnvFileError {
    log('.env file present but empty');
  }

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(size: Size(650, 500), center: true);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(MaterialApp(home: MainUI()));
}
