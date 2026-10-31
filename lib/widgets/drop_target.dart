import 'package:flutter/material.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

import 'package:vid2pdf/main.dart';
import 'package:vid2pdf/widgets/simple_alert.dart';

class SingleFileDropTarget extends StatefulWidget {
  const SingleFileDropTarget({super.key, this.onFileDrop, this.fileFilter, this.enabled = true});

  final void Function(String)? onFileDrop;
  final bool Function(String)? fileFilter;

  /// If `false`, drops & clicks are ignored, e.g. so the source can't change mid-conversion.
  final bool enabled;

  @override
  State<SingleFileDropTarget> createState() => _SingleFileDropTargetState();
}

class _SingleFileDropTargetState extends State<SingleFileDropTarget> {
  String? sourceFile;

  Color _borderColor = Colors.black;

  void _acceptFile(String filePath) {
    if (widget.fileFilter != null && !widget.fileFilter!(filePath)) {
      showDialog(
        context: context,
        builder: (ctx) => simpleAlert(ctx, 'This does not appear to be a video'),
      );
      return;
    }

    setState(() {
      sourceFile = filePath;
    });

    widget.onFileDrop?.call(filePath);
  }

  Future<void> _browse() async {
    final PlatformFile? result = await FilePicker.pickFile(
      dialogTitle: 'Select Source Video',
      type: FileType.video,
    );

    if (!mounted || result?.path == null) {
      return;
    }

    _acceptFile(result!.path!);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (d) {
        setState(() {
          _borderColor = Colors.green;
        });
      },
      onDragExited: (d) {
        setState(() {
          _borderColor = Colors.black;
        });
      },
      onDragDone: (d) {
        if (d.files.length > 1) {
          showDialog(
            context: context,
            builder: (ctx) =>
                simpleAlert(ctx, 'Multi-file drag is not supported', actionMsg: 'Sorry'),
          );
          return;
        }

        if (d.files.isEmpty) {
          return;
        }

        _acceptFile(d.files.single.path);
      },
      child: GestureDetector(
        onTap: widget.enabled ? _browse : null,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: BoxBorder.all(color: widget.enabled ? _borderColor : Colors.grey, width: 4),
          ),
          child: Center(
            child: Text(
              sourceFile == null
                  ? 'Drop source video here, or click to browse'
                  : baseContext.basename(sourceFile!),
            ),
          ),
        ),
      ),
    );
  }
}
