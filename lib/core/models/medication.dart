class Medication {
  final int? id;
  final String name;
  final String dosage;
  final String schedule;
  final String? imagePath;
  final String? purpose;
  final String? notes;
  final String? frontImagePath;
  final String? backImagePath;
  final String frequency; // daily, weekly, custom
  final int? intervalDays; // for custom frequency (every X days)
  final List<int>? daysOfWeek; // for weekly frequency (1=Monday, 7=Sunday)

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.schedule,
    this.imagePath,
    this.purpose,
    this.notes,
    this.frontImagePath,
    this.backImagePath,
    this.frequency = 'daily',
    this.intervalDays,
    this.daysOfWeek,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'dosage': dosage,
      'schedule': schedule,
      'imagePath': imagePath,
      'purpose': purpose,
      'notes': notes,
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'frequency': frequency,
      'intervalDays': intervalDays,
      'daysOfWeek':daysOfWeek?.join(','),
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as int?,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      schedule: map['schedule'] as String,
      imagePath: map['imagePath'] as String?,
      purpose: map['purpose'] as String?,
      notes: map['notes'] as String?,
      frontImagePath: map['frontImagePath'] as String?,
      backImagePath: map['backImagePath'] as String?,
      frequency: map['frequency'] as String? ?? 'daily',
      intervalDays: map['intervalDays'] as int?,
      daysOfWeek: map['daysOfWeek'] != null
          ? (map['daysOfWeek'] as String)
              .split(',')
              .map((e) => int.parse(e))
              .toList()
          : null,
    );
  }

  Medication copyWith({
    int? id,
    String? name,
    String? dosage,
    String? schedule,
    String? imagePath,
    String? purpose,
    String? notes,
    String? frontImagePath,
    String? backImagePath,
    String? frequency,
    int? intervalDays,
    List<int>? daysOfWeek,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      schedule: schedule ?? this.schedule,
      imagePath: imagePath ?? this.imagePath,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      frequency: frequency ?? this.frequency,
      intervalDays: intervalDays ?? this.intervalDays,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }
}
