import 'package:test/test.dart';

import 'package:vid2pdf/utils/filter_files.dart';

void main() {
  group('isVideo', () {
    test('Video file should be true', () {
      final filePath = 'example.mp4';
      expect(isVideo(filePath), isTrue);
    });

    test('Non-video should be false', () {
      final filePath = 'example.mp3';
      expect(isVideo(filePath), isFalse);
    });

    test('Undetermined should default to false', () {
      final filePath = 'example.invalid';
      expect(isVideo(filePath), isFalse);
    });

    test('Pass through undetermined with flag', () {
      final filePath = 'example.invalid';
      expect(isVideo(filePath, failUnmatched: false), isTrue);
    });
  });
}
