class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(
    this.position,
    this.bufferedPosition,
    this.duration,
  );

  // To String
  @override
  String toString() {
    return 'PositionData{position: $position, bufferedPosition: $bufferedPosition, duration: $duration}';
  }

  // To Map
  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'bufferedPosition': bufferedPosition,
      'duration': duration,
    };
  }

  // From Map
  factory PositionData.fromMap(Map<String, dynamic> map) {
    return PositionData(
      Duration(microseconds: map['position']),
      Duration(microseconds: map['bufferedPosition']),
      Duration(microseconds: map['duration']),
    );
  }

  // Equals
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PositionData &&
        other.position == position &&
        other.bufferedPosition == bufferedPosition &&
        other.duration == duration;
  }

  // Hash Code
  @override
  int get hashCode {
    return position.hashCode ^ bufferedPosition.hashCode ^ duration.hashCode;
  }
}
