import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vid2pdf/utils/ffmpeg.dart';

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

/// Result of checking the user-provided FFmpeg location.
sealed class _FfmpegStatus {
  const _FfmpegStatus();
}

/// The location has been edited since it was last checked.
class _FfmpegUnchecked extends _FfmpegStatus {
  const _FfmpegUnchecked();
}

class _FfmpegChecking extends _FfmpegStatus {
  const _FfmpegChecking();
}

class _FfmpegFound extends _FfmpegStatus {
  final FfmpegInfo info;
  const _FfmpegFound(this.info);
}

class _FfmpegMissing extends _FfmpegStatus {
  final String message;
  const _FfmpegMissing(this.message);
}

/// Text field & directory picker for specifying the FFmpeg location, verified as it's edited.
///
/// The initial location is taken from the `FFMPEG_PATH` environment variable (see
/// [_ffmpegPathFromEnv]), falling back to `'ffmpeg'` on the system PATH. The location is checked on
/// startup, when the field loses focus or is submitted, and after a directory is picked.
class FfmpegLocationField extends StatefulWidget {
  const FfmpegLocationField({super.key, required this.onChanged, this.enabled = true});

  /// Called with the verified FFmpeg whenever the check status changes; `null` while the location is
  /// unchecked, being checked, or invalid.
  final void Function(FfmpegInfo?) onChanged;

  final bool enabled;

  @override
  State<FfmpegLocationField> createState() => _FfmpegLocationFieldState();
}

class _FfmpegLocationFieldState extends State<FfmpegLocationField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  _FfmpegStatus _status = const _FfmpegUnchecked();
  String? _lastCheckedLocation;
  int _checkId = 0;

  void _setStatus(_FfmpegStatus status) {
    setState(() {
      _status = status;
    });

    widget.onChanged(switch (status) {
      _FfmpegFound(:final info) => info,
      _ => null,
    });
  }

  /// Resolve & verify the FFmpeg location currently entered, updating [_status].
  ///
  /// Skipped if the location hasn't changed since it was last checked.
  Future<void> _check() async {
    final String location = _controller.text;
    if (location == _lastCheckedLocation && _status is! _FfmpegUnchecked) {
      return;
    }

    _lastCheckedLocation = location;
    final int checkId = ++_checkId;
    _setStatus(const _FfmpegChecking());

    _FfmpegStatus result;
    try {
      result = _FfmpegFound(await locateFfmpeg(location));
    } on FfmpegNotFoundException catch (e) {
      result = _FfmpegMissing(e.msg);
    } catch (e) {
      // e.g. unsupported platform
      result = _FfmpegMissing('$e');
    }

    // Discard the result if a newer check has started, or the location was edited in the meantime
    if (!mounted || checkId != _checkId || _controller.text != location) {
      return;
    }

    _setStatus(result);
  }

  Future<void> _pickDirectory() async {
    final String? d = await FilePicker.getDirectoryPath(dialogTitle: 'Select FFmpeg Directory');

    if (d != null) {
      // Programmatic edits don't change focus, so check explicitly
      _controller.text = d;
      _check();
    }
  }

  @override
  void initState() {
    super.initState();

    final String ffmpegEnv = _ffmpegPathFromEnv();
    _controller.text = (ffmpegEnv.isEmpty) ? 'ffmpeg' : ffmpegEnv;

    // Check the location once the user is done editing it
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        _check();
      }
    });

    // Check the initial location; deferred since setState can't be called during initState
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: widget.enabled ? _pickDirectory : null,
          child: Text('Locate ffmpeg'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _controller,
            focusNode: _focus,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: "FFmpeg location (folder, executable, or 'ffmpeg' if in PATH)",
              suffixIcon: switch (_status) {
                _FfmpegChecking() => Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                _FfmpegFound(:final info) => Tooltip(
                  message: 'Using ${info.path} (FFmpeg ${info.version})',
                  child: Icon(Icons.check_circle, color: Colors.green),
                ),
                _FfmpegUnchecked() || _FfmpegMissing() => null,
              },
            ),
            forceErrorText: switch (_status) {
              _FfmpegMissing(:final message) => message,
              _ => null,
            },
            // Any edit invalidates the previous result until the field is left & re-checked
            onChanged: (_) => _setStatus(const _FfmpegUnchecked()),
            onFieldSubmitted: (_) => _check(),
            // Desktop doesn't unfocus on outside clicks by default, which would skip the check
            onTapOutside: (_) => _focus.unfocus(),
          ),
        ),
      ],
    );
  }
}
