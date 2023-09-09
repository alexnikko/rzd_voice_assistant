import 'dart:async';

import 'package:de_train/src/screens/audio_player.dart';
import 'package:de_train/src/utils/audio_config.dart';
import 'package:de_train/src/utils/format_timer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorder extends StatefulWidget {
  const AudioRecorder({Key? key}) : super(key: key);

  @override
  State<AudioRecorder> createState() => AudioRecorderState();
}

class AudioRecorderState extends State<AudioRecorder> {
  // Recorder Screen
  bool showPlayer = false;
  String? audioPath;
  Duration lastDuration = const Duration(seconds: 0);

  int _recordDuration = 0;
  Timer? _timer;
  late final Record _audioRecorder;
  StreamSubscription<RecordState>? _recordSub;
  RecordState _recordState = RecordState.stop;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;

  @override
  void initState() {
    _audioRecorder = Record();

    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });

    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 300))
        .listen((amp) {
      setState(() => _amplitude = amp);
    });

    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        const AudioEncoder encoder = AudioEncoder.wav;
        const int numChannels = 1;

        final AudioConfig config = AudioConfig(
          encoder: encoder,
          numChannels: numChannels,
        );

        // We don't do anything with this but printing
        final bool isSupported = await _audioRecorder.isEncoderSupported(
          encoder,
        );

        debugPrint('${encoder.name} supported: $isSupported');

        final devs = await _audioRecorder.listInputDevices();
        debugPrint(devs.toString());

        // Record to file
        String path;
        if (kIsWeb) {
          path = '';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          path = p.join(
            dir.path,
            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );
        }

        await _audioRecorder.start(
          path: path,
          encoder: config.encoder,
          bitRate: config.bitRate,
          samplingRate: config.samplingRate,
          numChannels: config.numChannels,
          device: config.device,
        );

        // Record to stream
        // final file = File(path);
        // final stream = await _audioRecorder.startStream(config);
        // stream.listen(
        //   (data) {
        //     // ignore: avoid_print
        //     print(
        //       _audioRecorder.convertBytesToInt16(Uint8List.fromList(data)),
        //     );
        //     file.writeAsBytesSync(data, mode: FileMode.append);
        //   },
        //   // ignore: avoid_print
        //   onDone: () => print('End of stream'),
        // );

        _recordDuration = 0;

        _startTimer();
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> _stop() async {
    final String? path = await _audioRecorder.stop();

    if (path != null) {
      if (kDebugMode) print('Recorded file path: $path');

      setState(() {
        audioPath = path;
        showPlayer = true;
      });

      // if (kIsWeb) {
      //   await _downloadAudioWeb(path);
      // }
    }
  }

  // Future<void> _downloadAudioWeb(String path) async {
  //   // Simple download code for web testing
  //   final anchor = html.document.createElement('a') as html.AnchorElement
  //     ..href = path
  //     ..style.display = 'none'
  //     ..download = 'audio.wav';
  //   html.document.body!.children.add(anchor);

  //   // download
  //   anchor.click();
  // }

  Future<void> _pause() => _audioRecorder.pause();

  Future<void> _resume() => _audioRecorder.resume();

  void _updateRecordState(RecordState recordState) {
    setState(() => _recordState = recordState);

    switch (recordState) {
      case RecordState.pause:
        _timer?.cancel();
        break;
      case RecordState.record:
        _startTimer();
        break;
      case RecordState.stop:
        _timer?.cancel();
        lastDuration = getDurationFromInt(_recordDuration);
        _recordDuration = 0;
        break;
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  // create callback function to setstate showPlayer to false
  void onBack() {
    setState(() {
      showPlayer = !showPlayer;
    });
  }

  Widget _buildRecordStopControl() {
    late Icon icon;
    late Color color;

    if (_recordState != RecordState.stop) {
      icon = const Icon(Icons.stop, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (_recordState != RecordState.stop) ? _stop() : _start();
          },
        ),
      ),
    );
  }

  Widget _buildPauseResumeControl() {
    if (_recordState == RecordState.stop) {
      return const SizedBox.shrink();
    }

    late Icon icon;
    late Color color;

    if (_recordState == RecordState.record) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = const Icon(Icons.play_arrow, color: Colors.red, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (_recordState == RecordState.pause) ? _resume() : _pause();
          },
        ),
      ),
    );
  }

  Widget _buildText() {
    if (_recordState != RecordState.stop) {
      return _buildTimer();
    }

    return const Text("Waiting to record");
  }

  Widget _buildTimer() {
    final String minutes = getMinutes(_recordDuration);
    final String seconds = getSeconds(_recordDuration);

    return Text(
      '$minutes : $seconds',
      style: const TextStyle(color: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: showPlayer
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: AudioPlayerWidget(
                    path: audioPath!,
                    onBack: onBack,
                    duration: lastDuration,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _buildRecordStopControl(),
                        const SizedBox(width: 20),
                        _buildPauseResumeControl(),
                        const SizedBox(width: 20),
                        _buildText(),
                      ],
                    ),
                    if (_amplitude != null) ...[
                      const SizedBox(height: 40),
                      Text('Current: ${_amplitude?.current ?? 0.0}'),
                      Text('Max: ${_amplitude?.max ?? 0.0}'),
                    ],
                  ],
                ),
          // AudioRecorder(
          //   onStop: (path) {
          //     if (kDebugMode) print('Recorded file path: $path');

          //     setState(() {
          //       audioPath = path;
          //       showPlayer = true;
          //     });
          //   },
          // ),
        ),
      ),
    );
  }
}
