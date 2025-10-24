import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medication.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medbuddy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        var tableInfo = await db.rawQuery('PRAGMA table_info(medications)');
        var columnNames =
            tableInfo.map((column) => column['name'] as String).toList();

        if (!columnNames.contains('schedule')) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN schedule TEXT DEFAULT "8:00 AM"');
        }

        if (!columnNames.contains('dosage')) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN dosage TEXT DEFAULT "1 tablet"');
        }

        if (!columnNames.contains('frontImagePath')) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN frontImagePath TEXT');
        }

        if (!columnNames.contains('backImagePath')) {
          await db
              .execute('ALTER TABLE medications ADD COLUMN backImagePath TEXT');
        }

        await db.execute('''
          CREATE TABLE IF NOT EXISTS overdose_alerts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medicationId INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            scheduledTime TEXT NOT NULL,
            message TEXT NOT NULL,
            acknowledged INTEGER DEFAULT 0,
            FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Migration error
      }
    }

    if (oldVersion < 4) {
      try {
        var tableInfo = await db.rawQuery('PRAGMA table_info(medications)');
        var columnNames =
            tableInfo.map((column) => column['name'] as String).toList();

        if (!columnNames.contains('frequency')) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN frequency TEXT DEFAULT "daily"');
        }

        if (!columnNames.contains('intervalDays')) {
          await db.execute(
              'ALTER TABLE medications ADD COLUMN intervalDays INTEGER');
        }

        if (!columnNames.contains('daysOfWeek')) {
          await db
              .execute('ALTER TABLE medications ADD COLUMN daysOfWeek TEXT');
        }
      } catch (e) {
        // Migration error (frequency fields)
      }
    }

    if (oldVersion < 5) {
      try {
        // Create emergency contacts table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS emergency_contacts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            priority INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        // Migration error (emergency contacts)
      }
    }

    if (oldVersion < 6) {
      try {
        // Create medication image features table for pill identification
        await db.execute('''
          CREATE TABLE IF NOT EXISTS medication_image_features(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication_id INTEGER NOT NULL,
            image_type TEXT NOT NULL,
            feature_data TEXT NOT NULL,
            feature_path TEXT NOT NULL,
            FOREIGN KEY (medication_id) REFERENCES medications (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Migration error (image features)
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        schedule TEXT NOT NULL,
        imagePath TEXT,
        purpose TEXT,
        notes TEXT,
        frontImagePath TEXT,
        backImagePath TEXT,
        frequency TEXT DEFAULT "daily",
        intervalDays INTEGER,
        daysOfWeek TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE dose_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicationId INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        taken INTEGER NOT NULL,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE overdose_alerts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicationId INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        scheduledTime TEXT NOT NULL,
        message TEXT NOT NULL,
        acknowledged INTEGER DEFAULT 0,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        priority INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_image_features(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        image_type TEXT NOT NULL,
        feature_data TEXT NOT NULL,
        feature_path TEXT NOT NULL,
        FOREIGN KEY (medication_id) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<List<Medication>> getMedications() async {
    final db = await instance.database;
    final maps = await db.query('medications');

    return List.generate(maps.length, (i) {
      return Medication.fromMap(maps[i]);
    });
  }

  Future<Medication?> getMedication(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Medication.fromMap(maps.first);
    }
    return null;
  }

  Future<Medication?> getMedicationById(String id) async {
    try {
      final medicationId = int.parse(id);
      return await getMedication(medicationId);
    } catch (e) {
      return null;
    }
  }

  Future<int> saveMedication(Medication medication) async {
    final db = await instance.database;
    return await db.insert(
      'medications',
      medication.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateMedication(Medication medication) async {
    final db = await instance.database;
    return await db.update(
      'medications',
      medication.toMap(),
      where: 'id = ?',
      whereArgs: [medication.id],
    );
  }

  Future<int> deleteMedication(int id) async {
    final db = await instance.database;
    return await db.delete(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> insertDoseHistory(
      int medicationId, DateTime timestamp, bool taken) async {
    final db = await instance.database;

    final medication = await getMedication(medicationId);
    if (medication == null) {
      throw Exception('Medication not found');
    }

    final schedule = medication.schedule;
    final isCorrectTime = isWithinDoseTimeWindow(schedule, timestamp);

    final isPotentialOverdose =
        await checkForPotentialOverdose(medicationId, timestamp);

    final doseId = await db.insert(
      'dose_history',
      {
        'medicationId': medicationId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'taken': taken ? 1 : 0,
      },
    );

    if (isPotentialOverdose && taken) {
      await db.insert(
        'overdose_alerts',
        {
          'medicationId': medicationId,
          'timestamp': timestamp.millisecondsSinceEpoch,
          'scheduledTime': schedule,
          'message': 'Potential overdose detected for ${medication.name}',
          'acknowledged': 0,
        },
      );
    }

    return {
      'id': doseId,
      'isCorrectTime': isCorrectTime,
      'isPotentialOverdose': isPotentialOverdose,
      'medication': medication.name,
    };
  }

  bool isWithinDoseTimeWindow(String schedule, DateTime timestamp) {
    final scheduledTimes =
        schedule.split(',').map((time) => time.trim()).toList();

    for (var scheduledTime in scheduledTimes) {
      try {
        final scheduledTimeItems = scheduledTime.split(':');
        final scheduledHour = int.parse(scheduledTimeItems[0]);
        final scheduledMinutes = int.parse(scheduledTimeItems[1]);

        final scheduledForToday = DateTime(
          timestamp.year,
          timestamp.month,
          timestamp.day,
          scheduledHour,
          scheduledMinutes,
        );

        final difference =
            timestamp.difference(scheduledForToday).inMinutes.abs();

        if (difference <= 30) {
          return true;
        }
      } catch (e) {
        // Error parsing scheduled time
      }
    }

    return false;
  }

  bool shouldTakeMedicationToday(Medication medication, DateTime date) {
    switch (medication.frequency) {
      case 'daily':
        return true;

      case 'weekly':
        if (medication.daysOfWeek == null || medication.daysOfWeek!.isEmpty) {
          return false;
        }
        // Convert DateTime weekday (1=Monday, 7=Sunday) to match our daysOfWeek list
        final weekday = date.weekday;
        return medication.daysOfWeek!.contains(weekday);

      case 'custom':
        if (medication.intervalDays == null || medication.intervalDays! <= 0) {
          return false;
        }

        // For interval-based medications (every X days)
        // We need a reference date (using medication creation date or first dose)
        final refDate = DateTime(2023, 1, 1); // Default reference

        // Calculate days since reference
        final daysSinceRef = date.difference(refDate).inDays;

        // Check if today falls on the interval pattern
        return daysSinceRef % medication.intervalDays! == 0;

      default:
        return true;
    }
  }

  Future<bool> checkForPotentialOverdose(
      int medicationId, DateTime timestamp) async {
    final db = await instance.database;
    final medication = await getMedication(medicationId);

    if (medication == null) return false;

    // Check if this medication should be taken today
    if (!shouldTakeMedicationToday(medication, timestamp)) {
      // If it shouldn't be taken today, it's definitely an overdose
      return true;
    }

    final startOfDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final dosesTaken = await db.query(
      'dose_history',
      where: 'medicationId = ? AND taken = 1 AND timestamp BETWEEN ? AND ?',
      whereArgs: [
        medicationId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );

    final scheduledDosesPerDay = medication.schedule.split(',').length;

    return dosesTaken.length >= scheduledDosesPerDay;
  }

  Future<List<Map<String, dynamic>>> getOverdoseAlerts(
      {bool? acknowledged}) async {
    final db = await instance.database;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (acknowledged != null) {
      whereClause = 'acknowledged = ?';
      whereArgs = [acknowledged ? 1 : 0];
    }

    final alerts = await db.query(
      'overdose_alerts',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    final results = <Map<String, dynamic>>[];

    for (final alert in alerts) {
      final medicationMaps = await db.query(
        'medications',
        where: 'id = ?',
        whereArgs: [alert['medicationId']],
      );

      if (medicationMaps.isNotEmpty) {
        final medication = medicationMaps.first;
        results.add({
          ...alert,
          'medicationName': medication['name'],
          'medicationDosage': medication['dosage'],
        });
      }
    }

    return results;
  }

  Future<int> acknowledgeOverdoseAlert(int alertId) async {
    final db = await instance.database;
    return await db.update(
      'overdose_alerts',
      {'acknowledged': 1},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  Future<List<Map<String, dynamic>>> getDoseHistoryForMedication(
      int medicationId) async {
    final db = await instance.database;
    final maps = await db.query(
      'dose_history',
      where: 'medicationId = ?',
      whereArgs: [medicationId],
      orderBy: 'timestamp DESC',
    );

    return maps;
  }

  Future<List<Map<String, dynamic>>> getDoseHistory({
    int? medicationId,
    bool? taken,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await instance.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (medicationId != null) {
      whereClause += 'medicationId = ?';
      whereArgs.add(medicationId);
    }

    if (taken != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'taken = ?';
      whereArgs.add(taken ? 1 : 0);
    }

    if (startDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final doseHistoryMaps = await db.query(
      'dose_history',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
    );

    final results = <Map<String, dynamic>>[];

    for (final dose in doseHistoryMaps) {
      final medicationMaps = await db.query(
        'medications',
        where: 'id = ?',
        whereArgs: [dose['medicationId']],
      );

      if (medicationMaps.isNotEmpty) {
        final medication = medicationMaps.first;
        results.add({
          ...dose,
          'medicationName': medication['name'],
          'medicationDosage': medication['dosage'],
        });
      }
    }

    return results;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Emergency Contact Methods
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final db = await instance.database;
    return await db.query('emergency_contacts', orderBy: 'priority ASC');
  }

  Future<int> saveEmergencyContact(Map<String, dynamic> contact) async {
    final db = await instance.database;
    return await db.insert(
      'emergency_contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateEmergencyContact(Map<String, dynamic> contact) async {
    final db = await instance.database;
    return await db.update(
      'emergency_contacts',
      contact,
      where: 'id = ?',
      whereArgs: [contact['id']],
    );
  }

  Future<int> deleteEmergencyContact(int id) async {
    final db = await instance.database;
    return await db.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getEmergencyContactsCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM emergency_contacts');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Medication Image Feature Methods

  Future<int> saveMedicationImageFeatures(int medicationId, String imageType,
      String featureData, String featurePath) async {
    final db = await instance.database;

    // Check if features already exist for this medication and image type
    final existingFeatures = await db.query(
      'medication_image_features',
      where: 'medication_id = ? AND image_type = ?',
      whereArgs: [medicationId, imageType],
    );

    if (existingFeatures.isNotEmpty) {
      // Update existing features
      return await db.update(
        'medication_image_features',
        {
          'feature_data': featureData,
          'feature_path': featurePath,
        },
        where: 'id = ?',
        whereArgs: [existingFeatures.first['id']],
      );
    } else {
      // Insert new features
      return await db.insert(
        'medication_image_features',
        {
          'medication_id': medicationId,
          'image_type': imageType,
          'feature_data': featureData,
          'feature_path': featurePath,
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> getMedicationImageFeatures(
      int medicationId,
      {String? imageType}) async {
    final db = await instance.database;

    if (imageType != null) {
      return await db.query(
        'medication_image_features',
        where: 'medication_id = ? AND image_type = ?',
        whereArgs: [medicationId, imageType],
      );
    } else {
      return await db.query(
        'medication_image_features',
        where: 'medication_id = ?',
        whereArgs: [medicationId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllMedicationImageFeatures() async {
    final db = await instance.database;
    return await db.query('medication_image_features');
  }

  Future<int> deleteMedicationImageFeatures(int id) async {
    final db = await instance.database;
    return await db.delete(
      'medication_image_features',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getMedicationsWithFeatures() async {
    final db = await instance.database;

    // Join medications and features to get only medications with image features
    final results = await db.rawQuery('''
      SELECT DISTINCT m.id, m.name, m.dosage, m.purpose 
      FROM medications m
      INNER JOIN medication_image_features f ON m.id = f.medication_id
      ORDER BY m.name
    ''');

    return results;
  }

  Future<int> insertMedicationWithId(
    int id,
    String name,
    String dosage,
    String schedule,
    String purpose,
    String? frontImagePath,
    String? backImagePath,
    String frequency,
  ) async {
    final db = await instance.database;

    // Check if medication with this ID already exists
    final List<Map<String, dynamic>> existingMeds = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (existingMeds.isNotEmpty) {
      // Update the existing medication
      return await db.update(
        'medications',
        {
          'name': name,
          'dosage': dosage,
          'schedule': schedule,
          'purpose': purpose,
          'frontImagePath': frontImagePath,
          'backImagePath': backImagePath,
          'frequency': frequency,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // Insert a new medication with specified ID
      return await db.insert(
        'medications',
        {
          'id': id,
          'name': name,
          'dosage': dosage,
          'schedule': schedule,
          'purpose': purpose,
          'frontImagePath': frontImagePath,
          'backImagePath': backImagePath,
          'frequency': frequency,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Checks if a dose is allowed (not overdose and at correct time) without recording it.
  Future<Map<String, dynamic>> checkDoseAllowed(int medicationId, DateTime timestamp) async {
    final medication = await getMedication(medicationId);
    if (medication == null) {
      throw Exception('Medication not found');
    }
    final schedule = medication.schedule;
    final isCorrectTime = isWithinDoseTimeWindow(schedule, timestamp);
    final isPotentialOverdose = await checkForPotentialOverdose(medicationId, timestamp);
    return {
      'isCorrectTime': isCorrectTime,
      'isPotentialOverdose': isPotentialOverdose,
      'medication': medication.name,
    };
  }
}
