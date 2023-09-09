import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  /// Path from where to play recorded audio
  final String source;

  /// Callback when audio file should be removed
  /// Setting this to null hides the delete button
  final VoidCallback onDelete;

  const AudioPlayerWidget({
    Key? key,
    required this.source,
    required this.onDelete,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildControl(),
                _buildSlider(constraints.maxWidth),
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Color(0xFF73748D),
                    size: _deleteBtnSize,
                  ),
                  onPressed: () {
                    if (_audioPlayer.state == PlayerState.playing) {
                      stop().then((value) => widget.onDelete());
                    } else {
                      widget.onDelete();
                    }
                  },
                ),
              ],
            ),
            Text('${_duration ?? 0.0}'),
          ],
        );
      },
    );
  }

  Widget _buildControl() {
    Icon icon;
    Color color;

    if (_audioPlayer.state == PlayerState.playing) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.play_arrow, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child:
              SizedBox(width: _controlSize, height: _controlSize, child: icon),
          onTap: () {
            if (_audioPlayer.state == PlayerState.playing) {
              pause();
            } else {
              play();
            }
          },
        ),
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
