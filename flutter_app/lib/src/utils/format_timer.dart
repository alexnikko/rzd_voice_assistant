String getMinutes(int duration) {
  final String minutes = _formatNumber(duration ~/ 60);

  return minutes;
}

String getSeconds(int duration) {
  final String seconds = _formatNumber(duration % 60);

  return seconds;
}

Duration getDurationFromInt(int duration) {
  return Duration(seconds: duration);
}

Duration getDurationFromString(String duration) {
  final List<String> parts = duration.split(':');
  final int minutes = int.parse(parts[0]);
  final int seconds = int.parse(parts[1]);

  return Duration(minutes: minutes, seconds: seconds);
}

String _formatNumber(int number) {
  String numberStr = number.toString();
  if (number < 10) {
    numberStr = '0$numberStr';
  }

  return numberStr;
}
