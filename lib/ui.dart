import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:window_manager/window_manager.dart';

import 'package:vid2pdf/utils/ffmpeg.dart';
import 'package:vid2pdf/utils/filter_files.dart';
import 'package:vid2pdf/utils/pipeline.dart';
import 'package:vid2pdf/widgets/drop_target.dart';
import 'package:vid2pdf/widgets/ffmpeg_location_field.dart';
import 'package:vid2pdf/widgets/simple_alert.dart';

class MainUI extends StatefulWidget {
  const MainUI({super.key});

  @override
  State<MainUI> createState() => _MainUIState();
}

class _MainUIState extends State<MainUI> with WindowListener {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  /// Verified FFmpeg executable, `null` if the entered location hasn't been verified.
  FfmpegInfo? _ffmpeg;

  String? _sourcePath;

  FrameFormat _selectedFrameFormat = FrameFormat.jpeg;

  final PdfPipeline _pipeline = PdfPipeline();
  Future<bool>? _pipelineResult;
  bool _isPipelineRunning = false;
  late final AppLifecycleListener _appLifecycleListener;

  void _runPipeline() {
    // Generate should only be enabled once FFmpeg has been found, but guard just in case
    final FfmpegInfo? ffmpeg = _ffmpeg;
    if (!_formKey.currentState!.validate() || ffmpeg == null) {
      return;
    }

    // Disable additional pipeline invocation while one is still running
    setState(() {
      _isPipelineRunning = true;
    });

    _pipelineResult = _pipeline
        .run(
          ffmpegPath: ffmpeg.path,
          sourcePath: _sourcePath!,
          startTime: _startTimeController.text,
          endTime: _endTimeController.text,
          frameFormat: _selectedFrameFormat,
        )
        .whenComplete(() {
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
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _appLifecycleListener.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    try {
      await _pipeline.shutdown();
    } finally {
      // Since we've intercepted window close, destroy must always be reached or the window sticks
      await windowManager.destroy();
    }
  }

  Future<AppExitResponse> _onExitRequested() async {
    try {
      await _pipeline.shutdown();
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
              FfmpegLocationField(
                enabled: !_isPipelineRunning,
                onChanged: (FfmpegInfo? ffmpeg) => setState(() {
                  _ffmpeg = ffmpeg;
                }),
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
                                    onPressed: _pipeline.cancel,
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
                    onPressed: (_isPipelineRunning || _sourcePath == null || _ffmpeg == null)
                        ? null
                        : _runPipeline,
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
