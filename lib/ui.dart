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

  String? tryDotenv = dotenv.maybeGet(varName, fallback: null);
  if (tryDotenv != null) {
    return tryDotenv;
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

  Future<bool>? _pipelineResult;
  bool _isPipelineRunning = false;

  Future<bool> _pdfPipeline({
    required String ffmpegPath,
    required String sourcePath,
    required String startTime,
    required String endTime,
  }) async {
    final Directory frameDir = await Directory(sourcePath).parent.createTemp('_frames');
    await frameDir.create();
    final String framePath = baseContext.canonicalize(frameDir.path);

    await extractFrames(
      ffmpegPath: ffmpegPath,
      source: sourcePath,
      outDir: framePath,
      start: (startTime.isEmpty) ? null : startTime,
      end: (endTime.isEmpty) ? null : endTime,
    );

    final pdfOutPath = baseContext.setExtension(sourcePath, '.pdf');
    await frames2pdf(framePath, pdfOutPath);

    await frameDir.delete(recursive: true);
    return true;
  }

  void _runPipeline() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Disable additional pipeline invocation while one is still running
    setState(() {
      _isPipelineRunning = true;
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
              .catchError((e) {
                setState(() {
                  _isPipelineRunning = false;
                });
                throw e;
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
                  ElevatedButton(
                    onPressed: (_isPipelineRunning || _sourcePath == null) ? null : _runPipeline,
                    child: Text('Generate PDF'),
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
                              return CircularProgressIndicator();
                            } else if (snapshot.hasError) {
                              return Text('Conversion Failed: ${snapshot.error}');
                            } else {
                              return Text('Conversion complete');
                            }
                          },
                        ),
                ],
              ),
              Row(children: [Text('Status updates here')]),
            ],
          ),
        ),
      ),
    );
  }
}
