import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:vid2pdf/utils/ffmpeg.dart';

/// Check whether FFmpeg can be run from the system PATH, for skipping tests that need it.
bool _ffmpegOnPath() {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  group('buildCommand', () {
    test('JPEG frames include quality arg', () {
      final cmd = buildCommand(source: 'in.mp4', outDir: 'out', frameFormat: FrameFormat.jpeg);
      final args = cmd.toCli().args;

      final qIdx = args.indexOf('-q:v');
      expect(qIdx, isNot(-1));
      expect(args[qIdx + 1], equals('2'));
      expect(args.last, endsWith('.jpg'));
    });

    test('PNG frames do not include quality arg', () {
      final cmd = buildCommand(source: 'in.mp4', outDir: 'out', frameFormat: FrameFormat.png);
      final args = cmd.toCli().args;

      expect(args, isNot(contains('-q:v')));
      expect(args.last, endsWith('.png'));
    });

    test('Non-interactive & error-only logging args are included', () {
      final args = buildCommand(source: 'in.mp4', outDir: 'out').toCli().args;

      expect(args, contains('-nostdin'));
      final logIdx = args.indexOf('-loglevel');
      expect(logIdx, isNot(-1));
      expect(args[logIdx + 1], equals('error'));
    });

    test('Seek args are placed before the input & output args after it', () {
      final cmd = buildCommand(
        source: 'in.mp4',
        outDir: 'out',
        start: '5',
        end: '10',
        frameFormat: FrameFormat.jpeg,
      );
      final args = cmd.toCli().args;

      final inputIdx = args.indexOf('in.mp4');
      expect(args[inputIdx - 1], equals('-i'));
      expect(args.sublist(0, inputIdx - 1), equals(['-ss', '5', '-to', '10']));
      expect(args.indexOf('-q:v'), greaterThan(inputIdx));
    });

    test('Seek args are omitted when not specified', () {
      final args = buildCommand(source: 'in.mp4', outDir: 'out').toCli().args;

      expect(args, isNot(contains('-ss')));
      expect(args, isNot(contains('-to')));
      expect(args.take(2), equals(['-i', 'in.mp4']));
    });
  });

  group('resolveFfmpeg', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vid2pdf_resolve_');
      // Default to a fixed platform so results don't depend on the machine running the tests
      debugOperatingSystemOverride = 'linux';
    });

    tearDown(() {
      debugOperatingSystemOverride = null;
      tmp.deleteSync(recursive: true);
    });

    /// Create an empty placeholder file at [parts] relative to the temporary directory.
    String touch(List<String> parts) {
      final file = File(p.joinAll([tmp.path, ...parts]));
      file.createSync(recursive: true);
      return file.path;
    }

    for (final cmd in ['ffmpeg', 'FFmpeg', 'FFMPEG']) {
      test("Command name '$cmd' is passed through for PATH lookup", () async {
        expect(await resolveFfmpeg(cmd), equals(cmd));
      });
    }

    for (final (os, exe) in [('windows', 'ffmpeg.exe'), ('macos', 'ffmpeg'), ('linux', 'ffmpeg')]) {
      test('Base dir with bin/$exe resolves ($os)', () async {
        debugOperatingSystemOverride = os;
        final expected = touch(['bin', exe]);
        expect(await resolveFfmpeg(tmp.path), equals(expected));
      });

      test('Dir directly containing $exe resolves ($os)', () async {
        debugOperatingSystemOverride = os;
        final expected = touch([exe]);
        expect(await resolveFfmpeg(tmp.path), equals(expected));
      });
    }

    test('Executable at the maximum search depth resolves', () async {
      // e.g. the parent folder of an extracted release zip was selected
      debugOperatingSystemOverride = 'windows';
      final expected = touch(['ffmpeg-8.0-full_build', 'bin', 'ffmpeg.exe']);
      expect(await resolveFfmpeg(tmp.path), equals(expected));
    });

    test('Executable beyond the maximum search depth is not found', () async {
      touch(['a', 'b', 'c', 'ffmpeg']);
      await expectLater(resolveFfmpeg(tmp.path), throwsA(isA<FfmpegNotFoundException>()));
    });

    test('Shallowest match is preferred', () async {
      // Deeper match sorts first alphabetically, so this also checks depth takes priority
      touch(['a', 'bin', 'ffmpeg']);
      final expected = touch(['bin', 'ffmpeg']);
      expect(await resolveFfmpeg(tmp.path), equals(expected));
    });

    test('Matches at the same depth resolve deterministically', () async {
      final expected = touch(['a', 'ffmpeg']);
      touch(['b', 'ffmpeg']);
      expect(await resolveFfmpeg(tmp.path), equals(expected));
    });

    test('Symlinked executable resolves', () async {
      final target = touch(['Cellar', 'ffmpeg', '8.0', 'bin', 'ffmpeg']);
      final linkDir = Directory(p.join(tmp.path, 'brew', 'bin'))..createSync(recursive: true);
      final link = Link(p.join(linkDir.path, 'ffmpeg'));
      try {
        link.createSync(target);
      } on FileSystemException {
        markTestSkipped('Symlinks cannot be created in this environment');
        return;
      }

      expect(await resolveFfmpeg(p.join(tmp.path, 'brew')), equals(link.path));
    });

    test('Executable name is matched case-insensitively', () async {
      debugOperatingSystemOverride = 'windows';
      final expected = touch(['bin', 'FFmpeg.EXE']);
      expect(await resolveFfmpeg(tmp.path), equals(expected));
    });

    test('Path to the executable itself is returned as-is', () async {
      final exePath = touch(['bin', 'ffmpeg']);
      expect(await resolveFfmpeg(exePath), equals(exePath));
    });

    test('Executable with a non-standard name is returned as-is', () async {
      final exePath = touch(['ffmpeg-7.1']);
      expect(await resolveFfmpeg(exePath), equals(exePath));
    });

    test('Directory without an executable throws, naming the searched location', () async {
      touch(['bin', 'ffprobe']);
      await expectLater(
        resolveFfmpeg(tmp.path),
        throwsA(
          isA<FfmpegNotFoundException>().having((e) => e.toString(), 'message', contains(tmp.path)),
        ),
      );
    });

    test('Directory with the wrong platform executable throws', () async {
      debugOperatingSystemOverride = 'windows';
      touch(['bin', 'ffmpeg']);
      await expectLater(resolveFfmpeg(tmp.path), throwsA(isA<FfmpegNotFoundException>()));
    });

    test('Nonexistent path throws, naming the path', () async {
      final missing = p.join(tmp.path, 'does', 'not', 'exist');
      await expectLater(
        resolveFfmpeg(missing),
        throwsA(
          isA<FfmpegNotFoundException>().having((e) => e.toString(), 'message', contains(missing)),
        ),
      );
    });

    test('Empty location throws', () async {
      await expectLater(resolveFfmpeg(''), throwsA(isA<FfmpegNotFoundException>()));
    });

    test('Unsupported platform throws when searching a directory', () async {
      debugOperatingSystemOverride = 'android';
      touch(['bin', 'ffmpeg']);
      await expectLater(resolveFfmpeg(tmp.path), throwsA(isA<UnimplementedError>()));
    });
  });

  group('locateFfmpeg', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vid2pdf_locate_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('Resolved file that cannot be run throws', () async {
      final notAnExe = File(p.join(tmp.path, 'ffmpeg'))..createSync();
      await expectLater(locateFfmpeg(notAnExe.path), throwsA(isA<FfmpegNotFoundException>()));
    });

    test('Resolution failures propagate', () async {
      await expectLater(
        locateFfmpeg(p.join(tmp.path, 'missing')),
        throwsA(isA<FfmpegNotFoundException>()),
      );
    });

    test('FFmpeg on PATH reports its version', () async {
      final info = await locateFfmpeg('ffmpeg');
      expect(info.path, equals('ffmpeg'));
      expect(info.version, isNot(equals('unknown version')));
      expect(info.version, isNotEmpty);
    }, skip: _ffmpegOnPath() ? false : 'FFmpeg is not available on PATH');
  });
}
