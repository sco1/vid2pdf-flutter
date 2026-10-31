import 'dart:developer';
import 'dart:io';

import 'package:vid2pdf/main.dart';
import 'package:vid2pdf/utils/ffmpeg.dart';
import 'package:vid2pdf/utils/make_pdf.dart';

/// Video to PDF conversion pipeline.
///
/// Frames are extracted with FFmpeg into a temporary directory, then assembled into a PDF alongside
/// the source video.
///
/// NOTE: One conversion will run at a time. [cancel] & [shutdown] apply to the current conversion,
/// if any.
class PdfPipeline {
  final FfmpegManager _ffmpegManager = FfmpegManager();
  Directory? _frameDir;
  Future<bool>? _current;
  Future<void>? _shutdownFuture;

  bool get isRunning => _current != null;

  /// Convert [sourcePath] into a PDF of its frames, written next to the source video.
  ///
  /// [startTime] & [endTime] use FFmpeg's time duration syntax; empty strings use the start & end
  /// of the video, respectively.
  ///
  /// Returns `true` if the PDF was written, or `false` if the conversion was cancelled.
  Future<bool> run({
    required String ffmpegPath,
    required String sourcePath,
    required String startTime,
    required String endTime,
    required FrameFormat frameFormat,
  }) {
    if (_current != null) {
      throw StateError('A conversion is already running');
    }

    final Future<bool> conversion = _run(
      ffmpegPath: ffmpegPath,
      sourcePath: sourcePath,
      startTime: startTime,
      endTime: endTime,
      frameFormat: frameFormat,
    );
    _current = conversion;
    return conversion.whenComplete(() => _current = null);
  }

  /// Request cancellation of the current conversion, if any.
  void cancel() => _ffmpegManager.kill();

  /// Cancel any running conversion & clean up its temporary files, for use when the app is closing.
  ///
  /// Repeat calls return the in-progress shutdown rather than starting a new one.
  Future<void> shutdown() => _shutdownFuture ??= _runShutdown();

  Future<void> _runShutdown() async {
    cancel();

    // Give the conversion a chance to wind down & clean up after itself
    final Future<bool>? current = _current;
    if (current != null) {
      try {
        await current.timeout(Duration(seconds: 3));
      } catch (e) {
        log('Pipeline did not shut down cleanly: $e');
      }
    }

    await _cleanupFrameDir();
  }

  Future<bool> _run({
    required String ffmpegPath,
    required String sourcePath,
    required String startTime,
    required String endTime,
    required FrameFormat frameFormat,
  }) async {
    _ffmpegManager.reset();

    _frameDir = await Directory.systemTemp.createTemp('vid2pdf_frames_');
    final String framePath = baseContext.canonicalize(_frameDir!.path);

    try {
      await extractFrames(
        ffmpegManager: _ffmpegManager,
        ffmpegPath: ffmpegPath,
        source: sourcePath,
        outDir: framePath,
        start: (startTime.isEmpty) ? null : startTime,
        end: (endTime.isEmpty) ? null : endTime,
        frameFormat: frameFormat,
      );

      if (_ffmpegManager.sigterm) {
        log('Pipeline terminated by user');
        return false;
      }

      final pdfOutPath = baseContext.setExtension(sourcePath, '.pdf');
      final bool written = await frames2pdf(
        framePath,
        pdfOutPath,
        frameFormat: frameFormat,
        isCancelled: () => _ffmpegManager.sigterm,
      );

      if (!written) {
        log('Pipeline terminated by user');
      }
      return written;
    } finally {
      await _cleanupFrameDir();
    }
  }

  /// Delete the temporary frame directory, if one exists.
  ///
  /// Safe to call multiple times, e.g. from both a conversion & [shutdown].
  ///
  /// NOTE: Deletion failures are logged rather than thrown
  Future<void> _cleanupFrameDir() async {
    final Directory? dir = _frameDir;
    _frameDir = null;

    try {
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FileSystemException catch (e) {
      log('Failed to clean up frame directory: $e');
    }
  }
}
