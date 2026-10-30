import 'package:test/test.dart';

import 'package:vid2pdf/utils/ffmpeg.dart';

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

    test('Output args are placed after the input', () {
      final cmd = buildCommand(
        source: 'in.mp4',
        outDir: 'out',
        start: '5',
        end: '10',
        frameFormat: FrameFormat.jpeg,
      );
      final args = cmd.toCli().args;

      final inputIdx = args.indexOf('in.mp4');
      expect(args.indexOf('-ss'), greaterThan(inputIdx));
      expect(args.indexOf('-to'), greaterThan(inputIdx));
      expect(args.indexOf('-q:v'), greaterThan(inputIdx));
    });
  });
}
