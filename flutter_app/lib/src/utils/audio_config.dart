import 'package:record/record.dart';

class AudioConfig {
  final AudioEncoder encoder;
  final int bitRate;
  final int samplingRate;
  final int numChannels;
  final InputDevice? device;

  AudioConfig({
    this.encoder = AudioEncoder.wav,
    this.bitRate = 128000,
    this.samplingRate = 44100,
    this.numChannels = 2,
    this.device,
  });
}
