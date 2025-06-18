import 'package:flutter/material.dart';

import 'package:vid2pdf/ui.dart';
import 'package:path/path.dart' as p;

final baseContext = p.Context(style: p.Style.posix);

void main() async {
  runApp(MaterialApp(home: MainUI()));
}
