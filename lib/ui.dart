import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vid2pdf/main.dart';
import 'package:vid2pdf/utils/ffmpeg.dart';
import 'package:vid2pdf/utils/make_pdf.dart';

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
  State<MainUI> createState() {
    return _MainUIState();
  }
}

class _MainUIState extends State<MainUI> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ffmpegPathController = TextEditingController();
  final TextEditingController _sourcePathController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  TimeFormat _selectedTimeFormat = TimeFormat.timestamp;

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
    // TODO: Validate inputs

    // Disable additional pipeline invocation while one is still running
    setState(() {
      _isPipelineRunning = true;
      _pipelineResult =
          _pdfPipeline(
                ffmpegPath: resolveFfmpeg(_ffmpegPathController.text),
                sourcePath: _sourcePathController.text,
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

  @override
  void initState() {
    super.initState();

    _ffmpegPathController.text = _ffmpegPathFromEnv();
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
                      readOnly: true,
                      decoration: InputDecoration(labelText: 'FFmpeg Base Dir'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      FilePickerResult? r = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Select Source Video',
                        type: FileType.video,
                      );

                      if (r != null) {
                        _sourcePathController.text = r.files.single.path!;
                      }
                    },
                    child: Text('Select Video'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sourcePathController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: 'Video Path'), // TODO: Drag & drop?
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Flexible(
                    fit: FlexFit.tight,
                    child: DropdownButtonFormField(
                      value: _selectedTimeFormat,
                      items: TimeFormat.values
                          .map((f) => DropdownMenuItem(value: f, child: Text(f.description)))
                          .toList(),
                      onChanged: (f) {
                        setState(() {
                          _selectedTimeFormat = f!;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      decoration: InputDecoration(labelText: 'Start Time'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      decoration: InputDecoration(labelText: 'End Time'),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isPipelineRunning ? null : _runPipeline,
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
