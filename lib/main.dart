import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

import 'package:vid2pdf/ui.dart';

final baseContext = p.Context(style: p.Style.posix);

void main() async {
  await dotenv.load(isOptional: true); // TODO: Handle case where .env file is empty
  runApp(MaterialApp(home: MainUI()));
}
