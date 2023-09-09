// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:de_train/src/screens/audio_player.dart';
import 'package:de_train/src/utils/const.dart';
import 'package:de_train/src/utils/web_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  late final Dio dio;
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

    dio = Dio();

    if (kIsWeb) {
      dio.httpClientAdapter = MyAdapter();
    }

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

          // final request = await client.get(Uri.parse(message.uri));
          // final bytes = request.bodyBytes;

          final request = await dio.get(message.uri);

          final bytes = request.data as List<int>; // List<int> of bytes

          // final request = await dio.get(message.uri);

          // final bytes = request.data as List<int>; // List<int> of bytes
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

    _sendTextRequest(trimmedText);
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

  Future<void> _sendTextRequest(String query) async {
    const String url = "http://212.41.27.225:6555";
    const String endpoint = "/api/text_query";

    final Map<String, dynamic> queryParams = {
      "text": query,
    };

    // final Response<Map<String, dynamic>> request = await dio.post(
    final Response<List<dynamic>> request = await dio.post(
      url + endpoint,
      queryParameters: queryParams,
      options: Options(
        contentType: "application/json",
        responseType: ResponseType.json,
      ),
    );

    print(request.data);

    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    String prettyprint = encoder.convert(request.data);
    print(prettyprint);

    if (request.data == null) {
      return;
    }

    // Concat the json into List of JSON
    // final List<dynamic> jsonList = [];

    // final Map<String, dynamic> N = request.data!['N'];

    // for (var element in N.keys) {
    //   Map<String, dynamic> q = {
    //     "N": element,
    //     "topic": request.data!['topic'][element],
    //     "malfunction": request.data!['malfunction'][element],
    //     "cause": request.data!['cause'][element],
    //     "elimination": request.data!['elimination'][element],
    //     "cos_sim": request.data!['cos_sim'][element],
    //   };

    //   jsonList.add(q);
    // }

    // jsonList.sort(
    //   (a, b) => b['cos_sim'].compareTo(a['cos_sim']),
    // );

    // Initialize the final list
    final List<dynamic> finalList = request.data!;

    // Init message list
    final List<types.Message> messageList = [];

    for (int i = 0; i < 3; i++) {
      // Cause
      final String cause = finalList[i]["cause"];

      // Elimination
      final String elimination = finalList[i]["elimination"];

      // Reglament number
      final String reglament = finalList[i]["N"].toString();

      // Solution
      final String solution =
          "Возможная причина: $cause\n\nРешение: $elimination\n\nСогласно пункту регламента №$reglament";

      await Future.delayed(Duration(milliseconds: 50));

      final textMessage = types.TextMessage(
        author: _assistant,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: solution,
      );

      messageList.add(textMessage);
    }

    await Future.delayed(
      Duration(
        milliseconds: Random().nextInt(2000) + 1000,
      ),
      () {
        for (var element in messageList) {
          _addMessage(element);
        }
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
