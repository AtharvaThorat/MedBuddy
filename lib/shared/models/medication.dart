import 'package:uuid/uuid.dart';

class MedicationTime {
  final int hour;
  final int minute;

  MedicationTime(this.hour, this.minute);

  Map<String, dynamic> toMap() {
    return {'hour': hour, 'minute': minute};
  }

  factory MedicationTime.fromMap(Map<String, dynamic> map) {
    return MedicationTime(map['hour'] as int, map['minute'] as int);
  }

  String formatTime() {
    final hour12 = hour > 12 ? hour - 12 : hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }
}

class Medication {
  final String id;
  final String name;
  final String purpose;
  final String dosageInstructions;
  final String frequency;
  final String? frontImagePath;
  final String? backImagePath;
  final String? additionalNotes;
  final DateTime startDate;
  final DateTime endDate;
  final List<MedicationTime> scheduledTimes;

  Medication({
    String? id,
    required this.name,
    required this.purpose,
    required this.dosageInstructions,
    required this.frequency,
    this.frontImagePath,
    this.backImagePath,
    this.additionalNotes,
    required this.startDate,
    required this.endDate,
    List<MedicationTime>? scheduledTimes,
  }) : id = id ?? const Uuid().v4(),
       scheduledTimes = scheduledTimes ?? [MedicationTime(8, 0)];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'purpose': purpose,
      'dosageInstructions': dosageInstructions,
      'frequency': frequency,
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'additionalNotes': additionalNotes,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'scheduledTimes': scheduledTimes.map((time) => time.toMap()).toList(),
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    List<MedicationTime> times = [];
    if (map['scheduledTimes'] != null) {
      times =
          (map['scheduledTimes'] as List)
              .map(
                (item) => MedicationTime.fromMap(item as Map<String, dynamic>),
              )
              .toList();
    } else {
      times = [MedicationTime(8, 0)];
    }

    return Medication(
      id: map['id'],
      name: map['name'],
      purpose: map['purpose'],
      dosageInstructions: map['dosageInstructions'],
      frequency: map['frequency'],
      frontImagePath: map['frontImagePath'] ?? map['imagePath'],
      backImagePath: map['backImagePath'],
      additionalNotes: map['additionalNotes'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      scheduledTimes: times,
    );
  }

  Medication copyWith({
    String? name,
    String? purpose,
    String? dosageInstructions,
    String? frequency,
    String? frontImagePath,
    String? backImagePath,
    String? additionalNotes,
    DateTime? startDate,
    DateTime? endDate,
    List<MedicationTime>? scheduledTimes,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      dosageInstructions: dosageInstructions ?? this.dosageInstructions,
      frequency: frequency ?? this.frequency,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
    );
  }
}
