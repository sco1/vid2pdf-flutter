import 'package:flutter/material.dart';

AlertDialog simpleAlert(BuildContext ctx, String msg, {String actionMsg = 'OK'}) {
  return AlertDialog(
    content: Text(msg, textAlign: TextAlign.center),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(actionMsg))],
  );
}
