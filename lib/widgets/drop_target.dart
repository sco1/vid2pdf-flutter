import 'package:flutter/material.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

import 'package:vid2pdf/widgets/simple_alert.dart';

class SingleFileDropTarget extends StatefulWidget {
  const SingleFileDropTarget({super.key, this.onFileDrop, this.fileFilter});

  final void Function(String)? onFileDrop;
  final bool Function(String)? fileFilter;

  @override
  State<SingleFileDropTarget> createState() => _SingleFileDropTargetState();
}

class _SingleFileDropTargetState extends State<SingleFileDropTarget> {
  String? sourceFile;

  Color _borderColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
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
                simpleAlert(context, 'Multi-file drag is not supported', actionMsg: 'Sorry'),
          );
        } else {
          final String droppedFile = d.files[0].path;

          if (widget.fileFilter != null) {
            final bool filterResult = widget.fileFilter!(droppedFile);
            if (!filterResult) {
              showDialog(
                context: context,
                builder: (ctx) => simpleAlert(context, 'File does not appear to be a video'),
              );
              return;
            }
          }

          setState(() {
            sourceFile = droppedFile;
          });

          if (widget.onFileDrop != null) {
            widget.onFileDrop!(droppedFile);
          }
        }
      },
      // Click to open file prompt
      child: GestureDetector(
        onTap: () async {
          FilePickerResult? r = await FilePicker.platform.pickFiles(
            dialogTitle: 'Select Source Video',
            type: FileType.video,
          );

          if (r != null) {
            setState(() {
              sourceFile = r.files.single.path!;
            });
          }
        },
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: BoxBorder.all(color: _borderColor, width: 4),
          ),
          child: Center(
            child: Text(
              (sourceFile == null) ? 'Drop source video here, or click to browse' : sourceFile!,
            ),
          ),
        ),
      ),
    );
  }
}
