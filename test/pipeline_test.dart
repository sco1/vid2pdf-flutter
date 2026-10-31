import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:vid2pdf/utils/ffmpeg.dart';
import 'package:vid2pdf/utils/pipeline.dart';

void main() {
  late Directory tmp;
  late String video;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vid2pdf_pipeline_');
    video = p.join(tmp.path, 'clip.mp4');

    // 1 second @ 10 fps -> 10 frames
    final result = Process.runSync('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'testsrc=duration=1:size=320x240:rate=10',
      '-pix_fmt',
      'yuv420p',
      video,
    ]);
    if (result.exitCode != 0) {
      fail('Failed to generate test video: ${result.stderr}');
    }
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  /// Names of temporary frame directories currently present, for checking cleanup.
  Set<String> frameDirs() => Directory.systemTemp
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .where((name) => name.startsWith('vid2pdf_frames_'))
      .toSet();

  Future<bool> runPipeline(PdfPipeline pipeline, {String startTime = ''}) => pipeline.run(
    ffmpegPath: 'ffmpeg',
    sourcePath: video,
    startTime: startTime,
    endTime: '',
    frameFormat: FrameFormat.jpeg,
  );

  final String? skip = _ffmpegOnPath() ? null : 'FFmpeg is not available on PATH';

  test('Conversion writes a PDF next to the source & cleans up frames', () async {
    final before = frameDirs();

    expect(await runPipeline(PdfPipeline()), isTrue);

    final pdf = File(p.join(tmp.path, 'clip.pdf'));
    expect(pdf.existsSync(), isTrue);
    expect(pdf.readAsBytesSync().take(5), equals('%PDF-'.codeUnits));
    expect(frameDirs(), equals(before));
  }, skip: skip);

  test('Cancelling immediately writes no PDF & cleans up frames', () async {
    final before = frameDirs();
    final pipeline = PdfPipeline();

    final Future<bool> result = runPipeline(pipeline);
    pipeline.cancel();

    expect(await result, isFalse);
    expect(File(p.join(tmp.path, 'clip.pdf')).existsSync(), isFalse);
    expect(frameDirs(), equals(before));
  }, skip: skip);

  test('Starting a second conversion while one is running throws', () async {
    final pipeline = PdfPipeline();
    final Future<bool> first = runPipeline(pipeline);

    expect(() => runPipeline(pipeline), throwsStateError);
    await first;
  }, skip: skip);

  test('Pipeline can be reused after a conversion completes', () async {
    final pipeline = PdfPipeline();
    expect(await runPipeline(pipeline), isTrue);
    expect(await runPipeline(pipeline), isTrue);
  }, skip: skip);

  test('Start time beyond the video fails with NoFramesExtractedException', () async {
    final before = frameDirs();

    await expectLater(
      runPipeline(PdfPipeline(), startTime: '10'),
      throwsA(isA<NoFramesExtractedException>()),
    );
    expect(frameDirs(), equals(before));
  }, skip: skip);

  test('Shutdown cancels a running conversion & cleans up frames', () async {
    final before = frameDirs();
    final pipeline = PdfPipeline();

    final Future<bool> result = runPipeline(pipeline);
    await pipeline.shutdown();

    expect(await result, isFalse);
    expect(pipeline.isRunning, isFalse);
    expect(frameDirs(), equals(before));
  }, skip: skip);
}

/// Check whether FFmpeg can be run from the system PATH, for skipping tests that need it.
bool _ffmpegOnPath() {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
