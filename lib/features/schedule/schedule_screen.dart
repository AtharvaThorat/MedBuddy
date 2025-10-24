import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/features/medication/medication_detail_screen.dart';
import 'package:table_calendar/table_calendar.dart';

enum DoseStatus {
  taken,
  skipped,
  missed,
}

class MedicationSchedule {
  final Medication medication;
  final DateTime scheduledTime;
  final TimeOfDay? medicationTime;
  DoseStatus? status;

  MedicationSchedule({
    required this.medication,
    required this.scheduledTime,
    this.medicationTime,
    this.status,
  });
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<MedicationSchedule>> _schedules = {};
  List<MedicationSchedule> _selectedDaySchedules = [];
  bool _isLoading = true;
  bool _showFrontImage = true; // Toggle for front/back image view
  
  // Cache for dose history to optimize database queries
  Map<int, List<Map<String, dynamic>>> _doseHistoryCache = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  // Extract schedule times from string like "Morning, Evening" or "8:00 AM, 8:00 PM"
  List<TimeOfDay> _parseScheduleTimes(String schedule) {
    List<TimeOfDay> times = [];

    // Simple schedule parsing
    List<String> parts = schedule.split(',').map((e) => e.trim()).toList();

    for (var part in parts) {
      if (part.toLowerCase() == 'morning') {
        times.add(const TimeOfDay(hour: 8, minute: 0));
      } else if (part.toLowerCase() == 'afternoon') {
        times.add(const TimeOfDay(hour: 13, minute: 0));
      } else if (part.toLowerCase() == 'evening') {
        times.add(const TimeOfDay(hour: 18, minute: 0));
      } else if (part.toLowerCase() == 'night' ||
          part.toLowerCase() == 'bedtime') {
        times.add(const TimeOfDay(hour: 21, minute: 0));
      } else {
        // Try to parse as time like "8:00 AM"
        try {
          final timeParts = part.split(' ');
          if (timeParts.length == 2) {
            final hourMinute = timeParts[0].split(':');
            int hour = int.parse(hourMinute[0]);
            int minute = int.parse(hourMinute[1]);

            if (timeParts[1].toLowerCase() == 'pm' && hour < 12) {
              hour += 12;
            } else if (timeParts[1].toLowerCase() == 'am' && hour == 12) {
              hour = 0;
            }

            times.add(TimeOfDay(hour: hour, minute: minute));
          }
        } catch (e) {
          // Default to morning if parsing fails
          times.add(const TimeOfDay(hour: 8, minute: 0));
        }
      }
    }

    // If no times could be parsed, default to morning
    if (times.isEmpty) {
      times.add(const TimeOfDay(hour: 8, minute: 0));
    }

    return times;
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final medications = await DatabaseService.instance.getMedications();
      final Map<DateTime, List<MedicationSchedule>> scheduleMap = {};

      // Date range for which to generate schedules
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 7));
      final endDate =
          DateTime(now.year, now.month, now.day).add(const Duration(days: 28));

      // Clear dose history cache
      _doseHistoryCache.clear();
      
      // Pre-load dose history for today to reduce database queries
      await _preloadDoseHistoryForDate(now);

      // Create a list of dates from start to end
      List<DateTime> datesInRange = [];
      for (DateTime date = startDate;
          date.isBefore(endDate);
          date = date.add(const Duration(days: 1))) {
        datesInRange.add(DateTime(date.year, date.month, date.day));
      }

      // Loop through each date in the range
      for (DateTime date in datesInRange) {
        List<MedicationSchedule> schedulesForDay = [];

        // Loop through all medications
        for (final medication in medications) {
          // Check if this medication should be taken on this day
          if (DatabaseService.instance
              .shouldTakeMedicationToday(medication, date)) {
            // Parse the schedule times
            final times = _parseScheduleTimes(medication.schedule);

            // Create a schedule for each time
            for (final time in times) {
              schedulesForDay.add(MedicationSchedule(
                medication: medication,
                scheduledTime: DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                ),
                status: await _getDoseStatus(medication, date, time),
              ));
            }
          }
        }

        if (schedulesForDay.isNotEmpty) {
          scheduleMap[date] = schedulesForDay;
        }
      }

      setState(() {
        _schedules = scheduleMap;
        _selectedDay = _focusedDay;
        _selectedDaySchedules = scheduleMap[_selectedDay] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New method to preload dose history for a specific date
  Future<void> _preloadDoseHistoryForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    
    final doseHistory = await DatabaseService.instance.getDoseHistory(
      startDate: startOfDay,
      endDate: endOfDay,
      taken: true,
    );
    
    // Group dose history by medication ID for faster lookups
    for (final dose in doseHistory) {
      final medicationId = dose['medicationId'] as int;
      if (!_doseHistoryCache.containsKey(medicationId)) {
        _doseHistoryCache[medicationId] = [];
      }
      _doseHistoryCache[medicationId]!.add(dose);
    }
  }

  Future<DoseStatus?> _getDoseStatus(
      Medication medication, DateTime date, TimeOfDay time) async {
    if (medication.id == null) return null;

    // Create the scheduled date time
    final scheduledDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final now = DateTime.now();
    if (scheduledDateTime.isBefore(now)) {
      // Check if we need to load dose history for this date
      if (date.day != _selectedDay.day || date.month != _selectedDay.month || date.year != _selectedDay.year) {
        if (!_doseHistoryCache.containsKey(medication.id)) {
          // Pre-load dose history for this medication on this date
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          
          final doseHistory = await DatabaseService.instance.getDoseHistory(
            medicationId: medication.id,
            startDate: startOfDay,
            endDate: endOfDay,
            taken: true,
          );
          
          _doseHistoryCache[medication.id!] = doseHistory;
        }
      }
      
      // Check if a dose was taken within +/- 30 minutes of the scheduled time
      final startWindow = scheduledDateTime.subtract(const Duration(minutes: 30));
      final endWindow = scheduledDateTime.add(const Duration(minutes: 30));
      
      // Use cached dose history if available
      final medicationDoses = _doseHistoryCache[medication.id!] ?? [];
      
      // Check if any dose in the cache falls within our time window
      bool doseTaken = false;
      for (final dose in medicationDoses) {
        final doseTime = DateTime.fromMillisecondsSinceEpoch(dose['timestamp'] as int);
        if (doseTime.isAfter(startWindow) && doseTime.isBefore(endWindow)) {
          doseTaken = true;
          break;
        }
      }
      
      if (doseTaken) {
        return DoseStatus.taken;
      } else {
        return DoseStatus.missed;
      }
    }
    // Future doses are scheduled
    return null;
  }

  // When changing the selected day, preload dose history for that day
  void _updateSelectedDaySchedules() {
    final dateKey = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    _selectedDaySchedules = _schedules[dateKey] ?? [];
    _selectedDaySchedules.sort(
      (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
    );
    
    // Preload dose history for the selected day
    _preloadDoseHistoryForDate(_selectedDay);
  }

  Future<void> _markDose(MedicationSchedule schedule, bool taken) async {
    final now = DateTime.now();

    try {
      final result = await DatabaseService.instance.insertDoseHistory(
        schedule.medication.id!,
        now,
        taken,
      );

      setState(() {
        schedule.status = taken ? DoseStatus.taken : DoseStatus.skipped;
      });

      // Check for warnings
      if (result['isPotentialOverdose'] == true && taken) {
        _showOverdoseWarning(schedule.medication.name);
      } else if (result['isCorrectTime'] == false) {
        _showWrongTimeWarning();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(taken ? 'Dose marked as taken' : 'Dose marked as skipped'),
            backgroundColor: taken ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording dose: $e')),
      );
    }
  }

  void _showOverdoseWarning(String medicationName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title:
            const Text('OVERDOSE WARNING', style: TextStyle(color: Colors.red)),
        content: Text(
          'You have already taken all scheduled doses of $medicationName today. Taking more could lead to an overdose!',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I UNDERSTAND',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWrongTimeWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Timing Alert', style: TextStyle(color: Colors.orange)),
        content: const Text(
          'This is not the scheduled time to take this medication. Are you sure you want to record it now?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dose recorded outside of scheduled time'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('RECORD ANYWAY'),
          ),
        ],
      ),
    );
  }

  void _navigateToMedicationDetail(Medication medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicationDetailScreen(medication: medication),
      ),
    ).then((_) => _loadSchedules());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medication Schedule')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const Divider(),
                Expanded(
                  child: _selectedDaySchedules.isEmpty
                      ? _buildEmptySchedule()
                      : _buildScheduleList(),
                ),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now().subtract(const Duration(days: 30)),
      lastDay: DateTime.now().add(const Duration(days: 60)),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) {
        final dateKey = DateTime(day.year, day.month, day.day);
        return _schedules[dateKey] ?? [];
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          _updateSelectedDaySchedules();
        });
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;

          return Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              width: 8,
              height: 8,
            ),
          );
        },
      ),
      calendarStyle: const CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: Colors.purple,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.purpleAccent,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildEmptySchedule() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No medications scheduled for\n${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    // Group schedules by time
    final Map<String, List<MedicationSchedule>> groupedSchedules = {};

    for (final schedule in _selectedDaySchedules) {
      final timeKey = DateFormat('h:mm a').format(schedule.scheduledTime);

      if (!groupedSchedules.containsKey(timeKey)) {
        groupedSchedules[timeKey] = [];
      }

      groupedSchedules[timeKey]!.add(schedule);
    }

    // Sort times
    final sortedTimes = groupedSchedules.keys.toList()
      ..sort((a, b) {
        final timeA = DateFormat('h:mm a').parse(a);
        final timeB = DateFormat('h:mm a').parse(b);
        return timeA.compareTo(timeB);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM d, yyyy').format(_selectedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_hasAnyMedicationWithBothImages())
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showFrontImage = !_showFrontImage;
                    });
                  },
                  icon: Icon(
                    _showFrontImage
                        ? Icons.flip_camera_android
                        : Icons.flip_camera_android_outlined,
                  ),
                  label: Text(_showFrontImage ? 'Show Back' : 'Show Front'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedTimes.length,
            itemBuilder: (context, index) {
              final timeKey = sortedTimes[index];
              final schedulesForTime = groupedSchedules[timeKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
                    child: Text(
                      timeKey,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  ...schedulesForTime.map((schedule) {
                    final isToday = isSameDay(_selectedDay, DateTime.now());

                    return Column(
                      children: [
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          child: InkWell(
                            onTap: () {
                              _navigateToMedicationDetail(schedule.medication);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _hasAnyMedicationWithBothImages()
                                            ? () {
                                                setState(() {
                                                  _showFrontImage =
                                                      !_showFrontImage;
                                                });
                                              }
                                            : null,
                                        child: Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: _getMedicationImage(
                                            schedule.medication,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              schedule.medication.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              schedule.medication.dosage,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Schedule: ${schedule.medication.schedule}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (schedule.status != null)
                                        _buildStatusIndicator(schedule.status!),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Dose action buttons - moved outside the card and made more prominent
                        if (isToday && schedule.status == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _markDose(schedule, true),
                                    icon: const Icon(
                                      Icons.check_circle,
                                      size: 24,
                                    ),
                                    label: const Text(
                                      'YES, TAKEN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _markDose(schedule, false),
                                    icon: const Icon(
                                      Icons.cancel,
                                      size: 24,
                                    ),
                                    label: const Text(
                                      'NO, SKIP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool _hasAnyMedicationWithBothImages() {
    for (final schedule in _selectedDaySchedules) {
      if (schedule.medication.frontImagePath != null &&
          schedule.medication.backImagePath != null) {
        return true;
      }
    }
    return false;
  }

  Widget _getMedicationImage(Medication medication) {
    // Determine which image to show
    String? imagePath;
    if (_showFrontImage) {
      imagePath = medication.frontImagePath;
    } else {
      imagePath = medication.backImagePath ?? medication.frontImagePath;
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath ?? ''),
            fit: BoxFit.cover,
            width: 70,
            height: 70,
          ),
        ),
        if (medication.frontImagePath != null &&
            medication.backImagePath != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                _showFrontImage ? 'F' : 'B',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusIndicator(DoseStatus status) {
    IconData iconData;
    Color color;
    String statusText;

    switch (status) {
      case DoseStatus.taken:
        iconData = Icons.check_circle;
        color = Colors.green;
        statusText = 'Taken';
        break;
      case DoseStatus.skipped:
        iconData = Icons.cancel;
        color = Colors.orange;
        statusText = 'Skipped';
        break;
      case DoseStatus.missed:
        iconData = Icons.error;
        color = Colors.red;
        statusText = 'Missed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to format TimeOfDay as a string
extension TimeOfDayExtension on TimeOfDay {
  String format(BuildContext context) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    final format = DateFormat.jm(); // "6:00 AM"
    return format.format(dt);
  }
}
