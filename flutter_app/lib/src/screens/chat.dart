// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:de_train/src/screens/audio_player.dart';
import 'package:de_train/src/utils/const.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final Dio dio = Dio();
  String text = '';

  late final TextEditingController _textEditingController;

  List<types.Message> _messages = [];

  final _user = const types.User(
    id: '82091008-a484-4a89-ae75-a22bf8d6f3ac',
    firstName: "Машинист",
  );

  final _assistant = const types.User(
    id: 'ca3f6d8fb22a-57ea-98a4-484a-80019028',
    firstName: "Ассистент",
  );

  bool _isRecordingAudio = false;

  int _recordDuration = 0;
  Timer? _timer;
  late final Record _audioRecorder;

  StreamSubscription<RecordState>? _recordSub;
  RecordState _recordState = RecordState.stop;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;

  List<Widget> waveforms = [];

  @override
  void initState() {
    super.initState();

    _textEditingController = TextEditingController();
    _textEditingController.addListener(() {
      setState(() {
        text = _textEditingController.text;
      });
    });

    _audioRecorder = Record();

    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 300))
        .listen((amp) {
      setState(() {
        _amplitude = amp;

        if (waveforms.length > 36) {
          waveforms.removeAt(0);
        }

        waveforms.add(
          Container(
            // duration: const Duration(milliseconds: 100),
            height: max(1, 200 + _amplitude!.current * 4),
            width: 7,
            color: Colors.red,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start();

        bool isRecording = await _audioRecorder.isRecording();
        _startTimer();

        setState(() {
          _isRecordingAudio = isRecording;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<String> _stopRecording() async {
    final path = await _audioRecorder.stop();

    print(path);

    _timer?.cancel();
    _recordDuration = 0;

    setState(() => _isRecordingAudio = false);

    return path!;
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index = _messages.indexWhere(
            (element) => element.id == message.id,
          );

          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          final request = await dio.get(message.uri);

          final bytes = request.data as List<int>; // List<int> of bytes
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  void _sendTextMessage() {
    final trimmedText = text.trim();
    _textEditingController.clear();
    text = '';

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: trimmedText,
    );

    _addMessage(textMessage);

    // ToDO remove after testing
    // Add a fake response after 2 seconds
    Future.delayed(Duration(milliseconds: 2000), () {
      setState(() {
        _messages.insert(
          0,
          textMessage.copyWith(
            author: _assistant,
            id: const Uuid().v4(),
          ),
        );
      });
    });
  }

  void _handleMicrophoneButtonPressed() {
    setState(() {
      _isRecordingAudio = !_isRecordingAudio;
    });

    if (_isRecordingAudio) {
      _startRecording();
    } else {
      _stopRecording().then((path) {
        _addMessage(
          types.AudioMessage(
            author: _user,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: const Uuid().v4(),
            mimeType: 'audio/wav',
            name: 'Audio message',
            duration: Duration.zero,
            size: 0,
            uri: path,
          ),
        );
      });
    }
  }

  void _dismissRecording() {
    setState(() {
      _isRecordingAudio = false;
      _timer?.cancel();
      _recordDuration = 0;
    });
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: primaryColor,
          radius: 6,
        ),
        const SizedBox(width: 12),
        Text(
          '$minutes : $seconds',
          style: const TextStyle(color: Colors.red),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }

    return numberStr;
  }

  Widget? _buildLeading() {
    return _isRecordingAudio
        ? IconButton(
            onPressed: _dismissRecording,
            icon: Icon(
              Icons.delete_forever,
            ),
          )
        : null;
  }

  Widget? _buildTrailing() {
    return text.isNotEmpty
        ? IconButton(
            onPressed: _sendTextMessage,
            icon: Icon(Icons.send),
          )
        : IconButton(
            icon: Icon(Icons.mic),
            onPressed: _handleMicrophoneButtonPressed,
          );
  }

  Widget _buildTitle() {
    return _isRecordingAudio
        ? _buildTimer()
        : TextField(
            autofocus: true,
            canRequestFocus: true,
            autocorrect: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Type a message',
              // Hide underline
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
            controller: _textEditingController,
            onSubmitted: (_) {
              _sendTextMessage();
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('de_train'),
      ),
      body: Chat(
        onSendPressed: (_) {},
        theme: DefaultChatTheme(
          backgroundColor: Color(0xFFE5E8F2),
          // Change the color of the message bubbles
          primaryColor: Colors.white,
          receivedMessageBodyTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
          sentMessageBodyTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
        ),
        messages: _messages,
        customBottomWidget: Container(
          color: Colors.white,
          height: 66,
          child: SizedBox.expand(
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              child: Center(
                child: ListTile(
                  leading: _buildLeading(),
                  trailing: _buildTrailing(),
                  title: _buildTitle(),
                  onTap: null,
                ),
              ),
            ),
          ),
        ),
        audioMessageBuilder: (
          types.AudioMessage message, {
          required int messageWidth,
        }) {
          return Container(
            width: messageWidth.toDouble(),
            child: AudioPlayerWidget(
              source: message.uri,
            ),
          );
        },
        onMessageTap: _handleMessageTap,
        onPreviewDataFetched: _handlePreviewDataFetched,
        showUserAvatars: true,
        showUserNames: true,
        user: _user,
      ),
    );
  }
}
