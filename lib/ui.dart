import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';

import 'package:vid2pdf/main.dart';
import 'package:vid2pdf/utils/ffmpeg.dart';
import 'package:vid2pdf/utils/filter_files.dart';
import 'package:vid2pdf/utils/make_pdf.dart';
import 'package:vid2pdf/widgets/drop_target.dart';
import 'package:vid2pdf/widgets/simple_alert.dart';

/// Attempt to locate FFmpeg's base directory as defined by an environment variable.
///
/// Preference is given to the system's environment variable. If not defined by the system, or it is
/// defined as an empty string, a fallback attempt will be made to a `.env` file, as loaded by
/// `flutter_dotenv`.
///
/// If neither approach yields a value, an empty string is returned.
String _ffmpegPathFromEnv({String varName = 'FFMPEG_PATH'}) {
  final String? tryEnv = Platform.environment[varName];
  if (tryEnv != null && tryEnv.isNotEmpty) {
    return tryEnv;
  }

  try {
    final String? tryDotenv = dotenv.maybeGet(varName, fallback: null);
    if (tryDotenv != null) {
      return tryDotenv;
    }
  } on NotInitializedError {
    log('DotEnv not initialized, defaulting to empty value');
    return '';
  }

  return '';
}

class MainUI extends StatefulWidget {
  const MainUI({super.key});

  @override
  State<MainUI> createState() => _MainUIState();
}

class _MainUIState extends State<MainUI> with WindowListener {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ffmpegPathController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  String? _sourcePath;

  FrameFormat _selectedFrameFormat = FrameFormat.jpeg;

  final FfmpegManager _ffmpegManager = FfmpegManager();
  Future<bool>? _pipelineResult;
  Directory? _frameDir;
  bool _isPipelineRunning = false;
  Future<void>? _shutdownFuture;
  late final AppLifecycleListener _appLifecycleListener;

  /// Delete the temporary frame directory, if one exists.
  ///
  /// Safe to call multiple times, e.g. from both the pipeline & the window close handler.
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

  /// Run the full video to PDF pipeline.
  ///
  /// Returns `true` if the PDF was written, or `false` if the pipeline was cancelled by the user.
  Future<bool> _pdfPipeline({
    required String ffmpegPath,
    required String sourcePath,
    required String startTime,
    required String endTime,
    required FrameFormat frameFormat,
  }) async {
    _ffmpegManager.reset();

    await checkFfmpegAvailable(ffmpegPath);
    if (_ffmpegManager.sigterm) {
      log('Pipeline terminated by user');
      return false;
    }

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

  void _runPipeline() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Disable additional pipeline invocation while one is still running
    setState(() {
      _isPipelineRunning = true;
    });

    _pipelineResult =
        _pdfPipeline(
          ffmpegPath: resolveFfmpeg(_ffmpegPathController.text),
          sourcePath: _sourcePath!,
          startTime: _startTimeController.text,
          endTime: _endTimeController.text,
          frameFormat: _selectedFrameFormat,
        ).whenComplete(() {
          setState(() {
            _isPipelineRunning = false;
          });
        });
  }

  void _onFileDrop(String newFilePath) {
    setState(() {
      _sourcePath = newFilePath;
    });
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // Intercept window close so any running FFmpeg process can be shut down first by onWindowClose
    windowManager.setPreventClose(true);

    // App-level quit requests bypass window close, so handle them separately
    _appLifecycleListener = AppLifecycleListener(onExitRequested: _onExitRequested);

    final String ffmpegEnv = _ffmpegPathFromEnv();
    _ffmpegPathController.text = (ffmpegEnv.isEmpty) ? 'ffmpeg' : ffmpegEnv;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _appLifecycleListener.dispose();
    _ffmpegPathController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  /// Stop any running pipeline & clean up its temporary files.
  ///
  /// Shared by the window close & app exit handlers; repeat calls return the in-progress shutdown
  Future<void> _shutdown() => _shutdownFuture ??= _runShutdown();

  Future<void> _runShutdown() async {
    _ffmpegManager.kill();

    // Give the pipeline a chance to wind down & clean up after itself before closing
    if (_isPipelineRunning && _pipelineResult != null) {
      try {
        await _pipelineResult!.timeout(Duration(seconds: 3));
      } catch (e) {
        log('Pipeline did not shut down cleanly: $e');
      }
    }

    await _cleanupFrameDir();
  }

  @override
  Future<void> onWindowClose() async {
    try {
      await _shutdown();
    } finally {
      // Since we've intercepted window close, destroy must always be reached or the window sticks
      await windowManager.destroy();
    }
  }

  Future<AppExitResponse> _onExitRequested() async {
    try {
      await _shutdown();
    } catch (e) {
      // Never block the exit, even if cleanup fails
      log('Shutdown failed during exit request: $e');
    }
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('vid2pdf'), leading: Icon(Icons.rocket_launch)),
      body: Container(
        margin: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            spacing: 12,
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      String? d = await FilePicker.getDirectoryPath(
                        dialogTitle: 'Select Base FFmpeg Directory',
                      );

                      if (d != null) {
                        _ffmpegPathController.text = d;
                      }
                    },
                    child: Text('Locate ffmpeg'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ffmpegPathController,
                      decoration: InputDecoration(
                        labelText: "FFmpeg Base Dir (use 'ffmpeg' if in path)",
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Enter value.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SingleFileDropTarget(onFileDrop: _onFileDrop, fileFilter: isVideo),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      decoration: InputDecoration(labelText: 'Start (blank for start)'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      decoration: InputDecoration(labelText: 'End (blank for end)'),
                    ),
                  ),
                  SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => simpleWidgetAlert(ctx, timeSpec),
                      );
                    },
                    icon: Icon(Icons.help_outline),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  (_pipelineResult == null)
                      ? Text('')
                      : FutureBuilder(
                          future: _pipelineResult,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Row(
                                spacing: 24,
                                children: [
                                  CircularProgressIndicator(),
                                  ElevatedButton(
                                    onPressed: () => _ffmpegManager.kill(),
                                    child: Text('Cancel'),
                                  ),
                                ],
                              );
                            } else if (snapshot.hasError) {
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => ScrollableAlertDialog('${snapshot.error}\n'),
                                  );
                                },
                                child: Text('Conversion Failed. Click for more details.'),
                              );
                            } else {
                              final String msg = (snapshot.data ?? false)
                                  ? 'Conversion complete'
                                  : 'Pipeline terminated by user';
                              return Text(msg);
                            }
                          },
                        ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownMenu(
                    initialSelection: FrameFormat.jpeg,
                    enabled: !_isPipelineRunning,
                    dropdownMenuEntries: FrameFormat.asMenuEntries,
                    label: Text('Frame Type'),
                    onSelected: (FrameFormat? fmt) {
                      if (fmt != null) {
                        setState(() {
                          _selectedFrameFormat = fmt;
                        });
                      }
                    },
                  ),
                  SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: (_isPipelineRunning || _sourcePath == null) ? null : _runPipeline,
                    child: Text('Generate PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
