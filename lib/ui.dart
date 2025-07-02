import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  String tryEnv = String.fromEnvironment(varName);
  if (tryEnv.isNotEmpty) {
    return tryEnv;
  }

  try {
    String? tryDotenv = dotenv.maybeGet(varName, fallback: null);
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

class _MainUIState extends State<MainUI> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ffmpegPathController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  String? _sourcePath;

  FrameFormat _selectedFrameFormat = FrameFormat.png;

  final FfmpegManager _ffmpegManager = FfmpegManager();
  Future<bool>? _pipelineResult;
  Directory? _frameDir;
  bool _isPipelineRunning = false;

  Future<bool> _pdfPipeline({
    required String ffmpegPath,
    required String sourcePath,
    required String startTime,
    required String endTime,
  }) async {
    final File ffmpegBin = File(ffmpegPath);
    if (!await ffmpegBin.exists()) {
      throw FfmpegNotFoundException("FFmpeg executable does not exist: '$ffmpegPath'");
    }

    _frameDir = await Directory(sourcePath).parent.createTemp('_frames');
    await _frameDir!.create();
    final String framePath = baseContext.canonicalize(_frameDir!.path);

    await extractFrames(
      ffmpegManager: _ffmpegManager,
      ffmpegPath: ffmpegPath,
      source: sourcePath,
      outDir: framePath,
      start: (startTime.isEmpty) ? null : startTime,
      end: (endTime.isEmpty) ? null : endTime,
      frameFormat: _selectedFrameFormat,
    );

    // Bail out early if the user has attempted to cancel the pipeline
    // Not sure if there's an easy way to cancel the PDF creation once it's been started
    if (_ffmpegManager.sigterm) {
      log('Pipeline terminated by user');
      await _frameDir!.delete(recursive: true);
      return false;
    }

    final pdfOutPath = baseContext.setExtension(sourcePath, '.pdf');
    await frames2pdf(framePath, pdfOutPath, frameFormat: _selectedFrameFormat);

    await _frameDir!.delete(recursive: true);
    return true;
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
            )
            .then((r) {
              setState(() {
                _isPipelineRunning = false;
              });
              return r;
            })
            .catchError((e) async {
              // Clean up frame directory if it's still lingering
              if (_frameDir != null && await _frameDir!.exists()) {
                _frameDir!.delete(recursive: true);
              }

              setState(() {
                _isPipelineRunning = false;
              });
              throw e;
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

    final String ffmpegEnv = _ffmpegPathFromEnv();
    _ffmpegPathController.text = (ffmpegEnv.isEmpty) ? 'ffmpeg' : ffmpegEnv;
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
                      String? d = await FilePicker.platform.getDirectoryPath(
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
                              final String msg = (_ffmpegManager.sigterm)
                                  ? 'Pipeline terminated by user'
                                  : 'Conversion complete';
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
                    initialSelection: FrameFormat.png,
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
