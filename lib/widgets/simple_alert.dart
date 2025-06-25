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
