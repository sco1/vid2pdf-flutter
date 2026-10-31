import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'package:vid2pdf/main.dart';
import 'package:vid2pdf/utils/find_executable.dart';

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

class NoFramesExtractedException implements Exception {
  final String details;
  NoFramesExtractedException([this.details = '']);

  @override
  String toString() {
    const msg =
        "No frames were extracted. Check that start and/or end time falls within the video's duration";

    final trimmed = details.trim();
    if (trimmed.isEmpty) {
      return msg;
    }
    return '$msg\n\nFFmpeg output:\n\n$trimmed';
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

/// Maximum number of directory levels below a user-selected directory that are searched for FFmpeg
const int ffmpegSearchDepth = 2;

/// Overrides the operating system used to determine FFmpeg's executable name, for testing only.
///
/// Uses the same values as [Platform.operatingSystem], e.g. `'windows'`; `null` uses the real OS.
@visibleForTesting
String? debugOperatingSystemOverride;

/// Resolve the FFmpeg executable from a user-provided [location].
///
/// [location] may be any of the following, checked in order:
///   1. `'ffmpeg'` (case-insensitive), to be resolved via the system PATH
///   2. A path to an existing file (e.g. `'some/dir/ffmpeg.exe'`)
///   3. A directory containing `ffmpeg[.exe]` at most [ffmpegSearchDepth] levels below it, e.g.
///      `dir/ffmpeg.exe`, `dir/bin/ffmpeg.exe`, or `dir/ffmpeg-8.0/bin/ffmpeg.exe`. If there are
///      multiple matches, the shallowest is used.
///
/// Throws [FfmpegNotFoundException] if [location] is empty or doesn't exist, or is a directory
/// without an FFmpeg executable within the search depth.
Future<String> resolveFfmpeg(String location) async {
  if (location.isEmpty) {
    throw FfmpegNotFoundException('No FFmpeg location specified');
  }

  if (location.toLowerCase() == 'ffmpeg') {
    return location;
  }

  if (await File(location).exists()) {
    return location;
  }

  final String os = debugOperatingSystemOverride ?? Platform.operatingSystem;
  final String exeName = switch (os) {
    'windows' => 'ffmpeg.exe',
    'linux' || 'macos' => 'ffmpeg',
    _ => throw UnimplementedError("Unsupported platform: '$os'"),
  };

  final dir = Directory(location);
  if (!(await dir.exists())) {
    throw FfmpegNotFoundException("'$location' does not exist");
  }

  final String? found = await findExecutable(dir, exeName, maxDepth: ffmpegSearchDepth);
  if (found == null) {
    throw FfmpegNotFoundException(
      "No '$exeName' found within $ffmpegSearchDepth levels below '$location'",
    );
  }

  return found;
}

/// A resolved & verified FFmpeg executable.
class FfmpegInfo {
  /// Path to the executable, or `'ffmpeg'` if it's resolved via the system PATH.
  final String path;

  /// Version string as reported by `ffmpeg -version`
  final String version;

  const FfmpegInfo(this.path, this.version);
}

/// Resolve [location] to an FFmpeg executable (see [resolveFfmpeg]) & verify that it can be run.
///
/// Throws [FfmpegNotFoundException] with a user-facing message if FFmpeg can't be found or run.
Future<FfmpegInfo> locateFfmpeg(String location) async {
  final String path = await resolveFfmpeg(location);

  final ProcessResult result;
  try {
    result = await Process.run(path, ['-version']);
  } on ProcessException {
    throw FfmpegNotFoundException("FFmpeg could not be run: '$path'");
  }

  if (result.exitCode != 0) {
    throw FfmpegNotFoundException("FFmpeg failed its version check: '$path'");
  }

  // First line should contain the version string
  // e.g. "ffmpeg version 9.0.1-full_build-www.gyan.dev Copyright (c) 2000-2026 ..."
  final String firstLine = LineSplitter.split(result.stdout as String).firstOrNull ?? '';
  final String version =
      RegExp(r'^ffmpeg version (\S+)').firstMatch(firstLine)?.group(1) ?? 'unknown version';

  return FfmpegInfo(path, version);
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
    inputs: [
      // Seek as input options so FFmpeg jumps to the nearest keyframe rather than decoding & then
      // discarding everything before the start time.
      // Both must be input options so the end time is measured against the source's timeline;
      // output timestamps are reset by input seeking.
      FfmpegInput([
        if (start != null) ...['-ss', start],
        if (end != null) ...['-to', end],
        '-i',
        source,
      ]),
    ],
    args: [
      CliArg(name: 'hide_banner'),
      // Keep stderr to actual errors so failure details aren't buried in progress output
      CliArg.logLevel(LogLevel.error),
      CliArg(name: 'nostdin'), // Don't listen for keypresses on stdin
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
///
/// Throws [NoFramesExtractedException] if FFmpeg was not cancelled but no frames were produced.
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
    throw FileSystemException('Frame output directory does not exist', outDir);
  }

  final cmd = buildCommand(
    source: source,
    outDir: outDir,
    ffmpegPath: ffmpegPath,
    start: start,
    end: end,
    frameFormat: frameFormat,
  );

  Future<bool> hasFrames() => Directory(
    outDir,
  ).list().any((e) => e is File && e.path.toLowerCase().endsWith(frameFormat.extension));

  final int result;
  try {
    result = await ffmpegManager.runCmd(cmd, verbose: verbose);
  } on FfmpegExecutionException catch (e) {
    // e.g. JPEG output fails with an encoder error rather than a clean exit when there are no frames
    if (!(await hasFrames())) {
      throw NoFramesExtractedException(e.stderr);
    }
    rethrow;
  }

  if (!ffmpegManager.sigterm && !(await hasFrames())) {
    throw NoFramesExtractedException(ffmpegManager.lastStderr);
  }

  return result;
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

    // FFmpeg should be verified before the pipeline can run, but guard just in case
    try {
      _process = await Ffmpeg().run(cmd);
    } on ProcessException {
      throw FfmpegNotFoundException("FFmpeg could not be started: '${cmd.ffmpegPath ?? 'ffmpeg'}'");
    }

    // Cancellation may have been requested while the process was starting
    if (sigterm) {
      _process!.kill();
    }

    // Output isn't guaranteed to be valid UTF-8, so replace bad bytes rather than throwing &
    // masking the actual FFmpeg error
    const decoder = Utf8Decoder(allowMalformed: true);
    final stderrBuffer = StringBuffer();
    final int exitCode;
    try {
      final stdoutFuture = verbose
          ? _process!.stdout
                .transform(decoder)
                .forEach(print) // ignore: avoid_print
          : _process!.stdout.drain<void>();
      final stderrFuture = _process!.stderr.transform(decoder).forEach((chunk) {
        stderrBuffer.write(chunk);
        if (verbose) {
          print(chunk); // ignore: avoid_print
        }
      });

      exitCode = await _process!.exitCode;
      await Future.wait([stdoutFuture, stderrFuture]);
    } finally {
      // Make sure we clear the process even if our decoding fails
      _process = null;
      lastStderr = stderrBuffer.toString();
    }

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
