import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> frames2pdf(String sourceDir, String outFile) async {
  final outPdf = pw.Document();

  final frames = Directory(
    sourceDir,
  ).listSync().where((f) => f.path.toLowerCase().endsWith('.png'));

  for (FileSystemEntity f in frames) {
    final img = pw.MemoryImage(File(f.path).readAsBytesSync());

    outPdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        orientation: pw.PageOrientation.landscape,
        margin: pw.EdgeInsets.all(0),
        build: (pw.Context ctx) {
          return pw.Center(child: pw.Image(img));
        },
      ),
    );
  }

  await File(outFile).writeAsBytes(await outPdf.save());
}
