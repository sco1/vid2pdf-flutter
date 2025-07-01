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

enum FrameFormat {
  png('PNG', '.png'),
  jpeg('JPEG', '.jpg');

  const FrameFormat(this.name, this.extension);
  final String name;
  final String extension;

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
    Text('''\
    FFmpeg supports two types of syntax for expressing time duration:

    * [HH:]MM:SS[.m...]
    * S+[.m...][s|ms|us]

    For example, to specify 1 minute & 5 seconds, you can use 01:05.5 or 65.5
    '''),
  ],
);

/// Resolve the location of the FFmpeg binary relative to the provided base directory.
///
/// The FFmpeg binary location is assumed to be in a fixed location per operating system, e.g. for
/// Windows the binary is located at `baseDir/bin/ffmpeg.exe`.
String resolveFfmpeg(String baseDir) {
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
  FrameFormat frameFormat = FrameFormat.png,
}) {
  final cmd = FfmpegCommand.simple(
    ffmpegPath: ffmpegPath,
    inputs: [FfmpegInput.asset(source)],
    args: [
      CliArg(name: 'hide_banner'),
      if (start != null) CliArg(name: 'ss', value: start),
      if (end != null) CliArg(name: 'to', value: end),
    ],
    outputFilepath: baseContext.join(outDir, 'frame%05d${frameFormat.extension}'),
  );

  return cmd;
}

/// Use ffmpeg to extract PNG frames from the provided source video file.
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
  required String source,
  required String outDir,
  String? ffmpegPath,
  String? start,
  String? end,
  FrameFormat frameFormat = FrameFormat.png,
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

  log('Executing FFmpeg command: ${cmd.toCli()}');
  final proc = await Ffmpeg().run(cmd);
  if (verbose) {
    proc.stderr.transform(utf8.decoder).listen((data) {
      print(data); // ignore: avoid_print
    });
  } else {
    proc.stderr.drain();
  }

  if (await proc.exitCode != 0) {
    return 1;
  } else {
    return 0;
  }
}
