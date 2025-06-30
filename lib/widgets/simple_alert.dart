import 'package:flutter/material.dart';

AlertDialog simpleAlert(BuildContext ctx, String msg, {String actionMsg = 'OK'}) {
  return AlertDialog(
    content: Text(msg, textAlign: TextAlign.center),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(actionMsg))],
    actionsAlignment: MainAxisAlignment.center,
  );
}

AlertDialog simpleWidgetAlert(BuildContext ctx, Widget body, {String actionMsg = 'OK'}) {
  return AlertDialog(
    content: body,
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(actionMsg))],
    actionsAlignment: MainAxisAlignment.center,
  );
}

class ScrollableAlertDialog extends StatefulWidget {
  const ScrollableAlertDialog(this.msg, {super.key, this.actionMsg = 'OK'});

  final String msg;
  final String actionMsg;

  @override
  State<ScrollableAlertDialog> createState() => _ScrollableAlertDialogState();
}

class _ScrollableAlertDialogState extends State<ScrollableAlertDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SelectableText(widget.msg),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.actionMsg)),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
