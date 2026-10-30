import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'package:vid2pdf/main.dart';

class FfmpegNotFoundException implements Exception {
  String msg;
  FfmpegNotFoundException(this.msg);

  @override
  String toString() {
    return 'Exception: $msg';
  }
}

class FfmpegExecutionException implements Exception {
  final int exitCode;
  final String stderr;
  FfmpegExecutionException(this.exitCode, this.stderr);

  @override
  String toString() {
    final details = stderr.trim();
    if (details.isEmpty) {
      return 'FFmpeg exited with code $exitCode';
    }
    return 'FFmpeg exited with code $exitCode:\n\n$details';
  }
}

/// Image formats available for frame extraction.
///
/// [ffmpegArgs] are format-specific output arguments appended to the extraction command.
enum FrameFormat {
  // Quality scale is 2-31, lower is better
  jpeg('JPEG', '.jpg', [CliArg(name: 'q:v', value: '2')]),
  png('PNG', '.png', []);

  const FrameFormat(this.name, this.extension, this.ffmpegArgs);
  final String name;
  final String extension;
  final List<CliArg> ffmpegArgs;

  static final List<DropdownMenuEntry<FrameFormat>> asMenuEntries = values
      .map((FrameFormat fmt) => DropdownMenuEntry(value: fmt, label: fmt.name))
      .toList();
}

const Column timeSpec = Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'Timestamp Specification Format',
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    SizedBox(height: 16),
    Text('''
FFmpeg supports two types of syntax for expressing time duration:

* [HH:]MM:SS[.m...]
* S+[.m...][s|ms|us]

For example, to specify 1 minute & 5 seconds, you can use 01:05.5 or 65.5'''),
  ],
);

/// Resolve the location of the FFmpeg binary relative to the provided base directory.
///
/// If [baseDir] is `'ffmpeg'`, it is returned as-is so the system PATH is used.
/// Otherwise, the FFmpeg binary location is assumed to be in a fixed location per operating system,
/// e.g. for Windows the binary is located at `baseDir/bin/ffmpeg.exe`.
String resolveFfmpeg(String baseDir) {
  if (baseDir == 'ffmpeg') {
    return baseDir;
  }

  switch (Platform.operatingSystem) {
    case 'windows':
      return baseContext.join(baseDir, 'bin', 'ffmpeg.exe');
    case 'macos':
    case 'linux':
      return baseContext.join(baseDir, 'bin', 'ffmpeg');
    default:
      throw UnimplementedError('Unsupported platform.');
  }
}

/// Verify that the FFmpeg binary at [ffmpegPath] (or on system PATH) can be executed.
///
/// Throws [FfmpegNotFoundException] if the binary cannot be found or fails to run.
Future<void> checkFfmpegAvailable(String ffmpegPath) async {
  try {
    final result = await Process.run(ffmpegPath, ['-version']);
    if (result.exitCode != 0) {
      throw FfmpegNotFoundException("FFmpeg executable failed check: '$ffmpegPath'");
    }
  } on ProcessException {
    throw FfmpegNotFoundException("FFmpeg executable does not exist: '$ffmpegPath'");
  }
}

/// Build a [FfmpegCommand] that can be invoked for frame extraction.
///
/// [outDir] must be a path to an existing directory. Note that any existing frames will be
/// overwritten on name collision.
///
/// [ffmpegPath] may be optionally specified as the path to the FFmpeg binary on the current system,
/// otherwise it is assumed that ffmpeg is in your system path.
///
/// [start] and [end] can be optionally specified according to FFmpeg's
/// [time duration specification syntax](https://www.ffmpeg.org/ffmpeg-utils.html#time-duration-syntax).
/// If not specified, the start and end of the source video, respectively, are used.
///
/// [frameFormat] may be used to specify the image type to use when extracting frames.
FfmpegCommand buildCommand({
  required String source,
  required String outDir,
  String? ffmpegPath,
  String? start,
  String? end,
  FrameFormat frameFormat = FrameFormat.jpeg,
}) {
  final cmd = FfmpegCommand.simple(
    ffmpegPath: ffmpegPath,
    inputs: [FfmpegInput.asset(source)],
    args: [
      CliArg(name: 'hide_banner'),
      if (start != null) CliArg(name: 'ss', value: start),
      if (end != null) CliArg(name: 'to', value: end),
      ...frameFormat.ffmpegArgs,
    ],
    outputFilepath: baseContext.join(outDir, 'frame%05d${frameFormat.extension}'),
  );

  return cmd;
}

/// Use ffmpeg to extract frames from the provided source video file.
///
/// [outDir] must be a path to an existing directory. Note that any existing frames will be
/// overwritten on name collision.
///
/// [ffmpegPath] may be optionally specified as the path to the FFmpeg binary on the current system,
/// otherwise it is assumed that ffmpeg is in your system path.
///
/// [start] and [end] can be optionally specified according to FFmpeg's
/// [time duration specification syntax](https://www.ffmpeg.org/ffmpeg-utils.html#time-duration-syntax).
/// If not specified, the start and end of the source video, respectively, are used.
///
/// [frameFormat] may be used to specify the image type to use when extracting frames.
Future<int> extractFrames({
  required FfmpegManager ffmpegManager,
  required String source,
  required String outDir,
  String? ffmpegPath,
  String? start,
  String? end,
  FrameFormat frameFormat = FrameFormat.jpeg,
  bool verbose = false,
}) async {
  if (!(await Directory(outDir).exists())) {
    log('Frame output directory does not exist: $outDir');
    return 1;
  }

  final cmd = buildCommand(
    source: source,
    outDir: outDir,
    ffmpegPath: ffmpegPath,
    start: start,
    end: end,
    frameFormat: frameFormat,
  );

  return await ffmpegManager.runCmd(cmd, verbose: verbose);
}

class FfmpegManager {
  Process? _process;
  bool sigterm = false;
  String lastStderr = '';

  /// Clear any prior cancellation request; call at the start of a pipeline run.
  void reset() {
    sigterm = false;
  }

  Future<int> runCmd(FfmpegCommand cmd, {bool verbose = false}) async {
    log('Executing FFmpeg command: ${cmd.toCli()}');
    lastStderr = '';
    _process = await Ffmpeg().run(cmd);

    // Cancellation may have been requested while the process was starting
    if (sigterm) {
      _process!.kill();
    }

    final stderrBuffer = StringBuffer();
    final stdoutFuture = verbose
        ? _process!.stdout
              .transform(utf8.decoder)
              .forEach(print) // ignore: avoid_print
        : _process!.stdout.drain<void>();
    final stderrFuture = _process!.stderr.transform(utf8.decoder).forEach((chunk) {
      stderrBuffer.write(chunk);
      if (verbose) {
        print(chunk); // ignore: avoid_print
      }
    });

    final exitCode = await _process!.exitCode;
    await Future.wait([stdoutFuture, stderrFuture]);
    _process = null;
    lastStderr = stderrBuffer.toString();

    if (exitCode != 0) {
      if (!sigterm) {
        throw FfmpegExecutionException(exitCode, lastStderr);
      }
      return 1;
    } else {
      return 0;
    }
  }

  void kill() {
    log('Attempting to kill FFmpeg process...');
    sigterm = true;

    if (_process != null) {
      log('Process found, PID: ${_process!.pid}');
      _process!.kill();
    } else {
      log('No running FFmpeg process found');
    }
  }
}
