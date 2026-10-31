import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:vid2pdf/utils/find_executable.dart';

void main() {
  group('findExecutable', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vid2pdf_find_exe_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    /// Creates an empty placeholder file at [parts] relative to the temporary directory.
    String touch(List<String> parts) {
      final file = File(p.joinAll([tmp.path, ...parts]));
      file.createSync(recursive: true);
      return file.path;
    }

    test('Mixed-case name matches a lowercase file', () async {
      final expected = touch(['bin', 'ffmpeg.exe']);
      expect(await findExecutable(tmp, 'FFmpeg.EXE', maxDepth: 1), equals(expected));
    });

    test('Lowercase name matches a mixed-case file, returned in its original case', () async {
      final expected = touch(['bin', 'FFmpeg.EXE']);
      final String? found = await findExecutable(tmp, 'ffmpeg.exe', maxDepth: 1);

      expect(found, equals(expected));
      expect(p.basename(found!), equals('FFmpeg.EXE'));
    });

    test('Returns null when no file matches', () async {
      touch(['bin', 'ffprobe.exe']);
      expect(await findExecutable(tmp, 'ffmpeg.exe', maxDepth: 1), isNull);
    });
  });
}
