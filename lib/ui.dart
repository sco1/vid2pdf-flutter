import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('vid2pdf')),
      body: Container(
        margin: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            spacing: 12,
            children: [
              Row(
                children: [
                  ElevatedButton(onPressed: () {}, child: Text('Locate ffmpeg')),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ffmpegPathController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: 'path/to/ffmpeg'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(onPressed: () {}, child: Text('Select Video')),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sourcePathController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: 'path/to/video'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
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
                  SizedBox(width: 12),
                  Flexible(
                    fit: FlexFit.tight,
                    child: DropdownButtonFormField(
                      value: 1,
                      items: [
                        DropdownMenuItem(value: 1, child: Text('Format 1')),
                        DropdownMenuItem(value: 2, child: Text('Format 2')),
                      ],
                      onChanged: null,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ElevatedButton(onPressed: () {}, child: Text('Generate PDF'))],
              ),
              Row(children: [Text('Status updates here')]),
            ],
          ),
        ),
      ),
    );
  }
}
