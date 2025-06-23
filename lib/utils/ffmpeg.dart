import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'package:vid2pdf/main.dart';

enum TimeFormat {
  timestamp,
  totalSeconds;

  String get description {
    switch (this) {
      case TimeFormat.timestamp:
        return '[HH:]MM:SS[.m...]';
      case TimeFormat.totalSeconds:
        return 'S[.m...]';
    }
  }
}

String resolveFfmpeg(String baseDir) {
  switch (Platform.operatingSystem) {
    case 'windows':
      return baseContext.join(baseDir, 'bin', 'ffmpeg.exe');
    case 'macos':
      // TODO: Find macos path
      throw UnimplementedError();
    case 'linux':
      // TODO: Find macos path
      throw UnimplementedError();
    default:
      throw UnimplementedError('Unsupported platform.');
  }
}

/// Use ffmpeg to extract PNG frames from the provided source video file.
///
/// [outDir] must be a path to an existing directory. Note that any existing frames will be
/// overwritten on name collision.
///
/// [ffmpegPath] may be optionally specified as the path to the ffmpeg binary on the current system,
/// otherwise it is assumed that ffmpeg is in your system path.
///
/// [start] and [end] can be optionally specified according to ffmpeg's
/// [time duration specification syntax](https://www.ffmpeg.org/ffmpeg-utils.html#time-duration-syntax).
/// If not specified, the start and end of the source video, respectively, are used.
Future<int> extractFrames({
  required String source,
  required String outDir,
  String? ffmpegPath,
  String? start,
  String? end,
  bool verbose = false,
}) async {
  if (!(await Directory(outDir).exists())) {
    return 1;
  }

  final cmd = FfmpegCommand.simple(
    ffmpegPath: ffmpegPath,
    inputs: [FfmpegInput.asset(source)],
    args: [
      CliArg(name: 'hide_banner'),
      if (start != null) CliArg(name: 'ss', value: start),
      if (end != null) CliArg(name: 'to', value: end),
    ],
    outputFilepath: baseContext.join(outDir, 'frame%05d.png'),
  );

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
