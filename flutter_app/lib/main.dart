import 'package:flutter/material.dart';

import 'src/screens/recorder.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool showPlayer = false;
  String? audioPath;
  Duration duration = const Duration(seconds: 0);

  @override
  void initState() {
    showPlayer = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const AudioRecorder();
  }

  // create callback function to setstate showPlayer to false
  void onBack() {
    setState(() {
      showPlayer = !showPlayer;
    });
  }
}
