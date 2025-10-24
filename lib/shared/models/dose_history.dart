enum DoseStatus { taken, skipped, missed }

class DoseHistory {
  final int? id;
  final String medicationId;
  final DateTime timestamp;
  final bool taken;

  DoseHistory({
    this.id,
    required this.medicationId,
    required this.timestamp,
    required this.taken,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medication_id': medicationId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'taken': taken ? 1 : 0,
    };
  }

  factory DoseHistory.fromMap(Map<String, dynamic> map) {
    return DoseHistory(
      id: map['id'] as int?,
      medicationId: map['medication_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      taken: (map['taken'] as int) == 1,
    );
  }

  DoseHistory copyWith({
    int? id,
    String? medicationId,
    DateTime? timestamp,
    bool? taken,
  }) {
    return DoseHistory(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      timestamp: timestamp ?? this.timestamp,
      taken: taken ?? this.taken,
    );
  }
}
