import 'package:flutter/material.dart';

class MainUI extends StatefulWidget {
  const MainUI({super.key});

  @override
  State<MainUI> createState() {
    return _MainUIState();
  }
}

class _MainUIState extends State<MainUI> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('vid2pdf')));
  }
}
