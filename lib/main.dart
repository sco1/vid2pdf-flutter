import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import 'package:vid2pdf/ui.dart';

final baseContext = p.Context(style: p.Style.posix);

void main() async {
  runApp(MaterialApp(home: MainUI()));
}
