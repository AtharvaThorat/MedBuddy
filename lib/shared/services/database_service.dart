import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:medbuddy/shared/models/medication.dart';
import 'package:medbuddy/shared/models/dose_history.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medbuddy.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medications(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        purpose TEXT NOT NULL,
        dosageInstructions TEXT NOT NULL,
        frequency TEXT NOT NULL,
        frontImagePath TEXT,
        backImagePath TEXT,
        additionalNotes TEXT,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        scheduledTimes TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dose_history(
        id TEXT PRIMARY KEY,
        medicationId TEXT NOT NULL,
        scheduledTime TEXT NOT NULL,
        actualTime TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (medicationId) REFERENCES medications (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 1 && newVersion == 2) {
      // Handle migration from version 1 to 2
      await db.execute(
        'ALTER TABLE medications ADD COLUMN frontImagePath TEXT',
      );
      await db.execute('ALTER TABLE medications ADD COLUMN backImagePath TEXT');
      await db.execute(
        'ALTER TABLE medications ADD COLUMN scheduledTimes TEXT',
      );

      // Migrate existing data
      final List<Map<String, dynamic>> medications = await db.query(
        'medications',
      );
      for (final med in medications) {
        final String? imagePath = med['imagePath'] as String?;
        final List<Map<String, dynamic>> times = [
          {'hour': 8, 'minute': 0},
        ];

        await db.update(
          'medications',
          {'frontImagePath': imagePath, 'scheduledTimes': jsonEncode(times)},
          where: 'id = ?',
          whereArgs: [med['id']],
        );
      }
    }
  }

  // Medication CRUD operations
  Future<String> insertMedication(Medication medication) async {
    final db = await database;
    final Map<String, dynamic> data = medication.toMap();

    // Convert scheduledTimes to JSON string for storage
    data['scheduledTimes'] = jsonEncode(data['scheduledTimes']);

    await db.insert(
      'medications',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return medication.id;
  }

  Future<List<Medication>> getAllMedications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('medications');

    return List.generate(maps.length, (i) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(maps[i]);

      // Parse scheduledTimes from JSON
      if (data['scheduledTimes'] != null) {
        try {
          data['scheduledTimes'] = jsonDecode(data['scheduledTimes']);
        } catch (e) {
          // If parsing fails, use default
          data['scheduledTimes'] = [
            {'hour': 8, 'minute': 0},
          ];
        }
      } else {
        data['scheduledTimes'] = [
          {'hour': 8, 'minute': 0},
        ];
      }

      return Medication.fromMap(data);
    });
  }

  Future<Medication?> getMedication(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final Map<String, dynamic> data = Map<String, dynamic>.from(maps.first);

    // Parse scheduledTimes from JSON
    if (data['scheduledTimes'] != null) {
      try {
        data['scheduledTimes'] = jsonDecode(data['scheduledTimes']);
      } catch (e) {
        // If parsing fails, use default
        data['scheduledTimes'] = [
          {'hour': 8, 'minute': 0},
        ];
      }
    } else {
      data['scheduledTimes'] = [
        {'hour': 8, 'minute': 0},
      ];
    }

    return Medication.fromMap(data);
  }

  Future<void> updateMedication(Medication medication) async {
    final db = await database;
    final Map<String, dynamic> data = medication.toMap();

    // Convert scheduledTimes to JSON string for storage
    data['scheduledTimes'] = jsonEncode(data['scheduledTimes']);

    await db.update(
      'medications',
      data,
      where: 'id = ?',
      whereArgs: [medication.id],
    );
  }

  Future<void> initialize() async {
    await database;
  }

  // ... existing dose history methods ...

  Future<void> deleteMedication(String id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  // Dose History CRUD operations
  Future<int?> insertDoseHistory(DoseHistory doseHistory) async {
    final db = await database;
    final id = await db.insert(
      'dose_history',
      doseHistory.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  // Compatibility method to match the core database service
  Future<Map<String, dynamic>> insertDoseHistoryWithParams(
      int medicationId, DateTime timestamp, bool taken) async {
    final doseHistory = DoseHistory(
      medicationId: medicationId.toString(),
      timestamp: timestamp,
      taken: taken,
    );

    final id = await insertDoseHistory(doseHistory);

    // Simple compatibility return object
    return {
      'id': id,
      'isCorrectTime': true,
      'isPotentialOverdose': false,
      'medication': 'Unknown', // We don't fetch the medication name here
    };
  }

  Future<List<DoseHistory>> getDoseHistoryForMedication(
    String medicationId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dose_history',
      where: 'medicationId = ?',
      whereArgs: [medicationId],
      orderBy: 'scheduledTime DESC',
    );
    return List.generate(maps.length, (i) => DoseHistory.fromMap(maps[i]));
  }

  Future<List<DoseHistory>> getDoseHistoryForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dose_history',
      where: 'scheduledTime BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'scheduledTime DESC',
    );
    return List.generate(maps.length, (i) => DoseHistory.fromMap(maps[i]));
  }

  Future<void> updateDoseHistory(DoseHistory doseHistory) async {
    final db = await database;
    await db.update(
      'dose_history',
      doseHistory.toMap(),
      where: 'id = ?',
      whereArgs: [doseHistory.id],
    );
  }

  Future<void> deleteDoseHistory(String id) async {
    final db = await database;
    await db.delete('dose_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<Medication?> getMedicationById(String id) async {
    try {
      final db = await database;
      final results = await db.query(
        'medications',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isNotEmpty) {
        return Medication.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving medication by ID: $e');
      return null;
    }
  }
}
