import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  /// Path from where to play recorded audio
  final String source;

  const AudioPlayerWidget({
    Key? key,
    required this.source,
  }) : super(key: key);

  @override
  AudioPlayerWidgetState createState() => AudioPlayerWidgetState();
}

class AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  static const double _controlSize = 56;
  static const double _deleteBtnSize = 24;

  late final AudioPlayer _audioPlayer;
  Duration? _position;
  Duration? _duration;

  late Source source;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    init();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> init() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    source =
        kIsWeb ? UrlSource(widget.source) : DeviceFileSource(widget.source);

    _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

    await _audioPlayer.setSource(source);

    await _audioPlayer.getDuration().then(
          (value) => setState(() {
            if (kDebugMode) print('Duration: $value');
            _duration = value;
          }),
        );

    _audioPlayer.onPlayerComplete.listen((state) async {
      await stop();
      setState(() {});
    });

    _audioPlayer.onPositionChanged.listen(
      (position) => setState(() {
        _position = position;
      }),
    );

    _audioPlayer.onDurationChanged.listen(
      (duration) => setState(() {
        _duration = duration;
      }),
    );

    setState(() {
      _isLoading = false;
    });
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }

    return numberStr;
  }

  // Get the current position.
  String _getPositionAsString() {
    final position = _position;
    if (position == null) {
      return '--:--';
    }

    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;

    return '${_formatNumber(minutes)}:${_formatNumber(seconds)}';
  }

  // Get the total duration.
  String _getDurationAsString() {
    final duration = _duration;
    if (duration == null) {
      return '--:--';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '${_formatNumber(minutes)}:${_formatNumber(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildControl(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlider(constraints.maxWidth),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      '${_getPositionAsString()} / ${_getDurationAsString()}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControl() {
    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        if (_audioPlayer.state == PlayerState.playing) {
          pause();
        } else {
          play();
        }
      },
      icon: Icon(
        _audioPlayer.state == PlayerState.playing
            ? Icons.pause_circle_filled_outlined
            : Icons.play_circle_fill_outlined,
        size: 36,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildSlider(double widgetWidth) {
    bool canSetValue = false;
    final duration = _duration;
    final position = _position;

    if (duration != null && position != null) {
      canSetValue = position.inMilliseconds > 0;
      canSetValue &= position.inMilliseconds < duration.inMilliseconds;
    }

    double width = widgetWidth - _controlSize - _deleteBtnSize;
    width -= _deleteBtnSize;

    return SizedBox(
      width: width,
      child: Slider(
        activeColor: Theme.of(context).primaryColor,
        inactiveColor: Theme.of(context).colorScheme.secondary,
        onChanged: (v) {
          if (duration != null) {
            final position = v * duration.inMilliseconds;
            _audioPlayer.seek(Duration(milliseconds: position.round()));
          }
        },
        value: canSetValue && duration != null && position != null
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0,
      ),
    );
  }

  Future<void> play() {
    return _audioPlayer.play(source);
  }

  Future<void> pause() => _audioPlayer.pause();

  Future<void> stop() => _audioPlayer.stop();
}
