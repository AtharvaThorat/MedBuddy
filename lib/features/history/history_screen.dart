import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _doseHistory = [];
  List<Medication> _medications = [];
  Map<int, Medication> _medicationMap = {};

  // Filters
  int? _selectedMedicationId;
  bool? _selectedTakenStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load medications first
      final medications = await _databaseService.getMedications();

      // Create a map for easy lookup
      final medicationMap = {
        for (var medication in medications) medication.id!: medication,
      };

      // Load dose history with filters
      final doseHistory = await _databaseService.getDoseHistory(
        medicationId: _selectedMedicationId,
        taken: _selectedTakenStatus,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _medications = medications;
          _medicationMap = medicationMap;
          _doseHistory = doseHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _loadData();
  }

  void _resetFilters() {
    setState(() {
      _selectedMedicationId = null;
      _selectedTakenStatus = null;
      _startDate = null;
      _endDate = null;
    });
    _loadData();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Filter History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Medication filter
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Medication',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedMedicationId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Medications'),
                        ),
                        ..._medications.map((medication) {
                          return DropdownMenuItem<int?>(
                            value: medication.id,
                            child: Text(medication.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          _selectedMedicationId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Taken status filter
                    DropdownButtonFormField<bool?>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedTakenStatus,
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: true,
                          child: Text('Taken'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('Skipped'),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          _selectedTakenStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date range filter
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setModalState(() {
                                  _startDate = date;
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                controller: TextEditingController(
                                  text: _startDate != null
                                      ? DateFormat('MMM d, yyyy')
                                          .format(_startDate!)
                                      : '',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                // Set to end of day
                                final endDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  23,
                                  59,
                                  59,
                                );
                                setModalState(() {
                                  _endDate = endDateTime;
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                controller: TextEditingController(
                                  text: _endDate != null
                                      ? DateFormat('MMM d, yyyy')
                                          .format(_endDate!)
                                      : '',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _applyFilters();
                            },
                            icon: const Icon(Icons.filter_alt),
                            label: const Text('Apply Filters'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _selectedMedicationId = null;
                              _selectedTakenStatus = null;
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
            tooltip: 'Filter History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _doseHistory.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No dose history found';

    if (_selectedMedicationId != null ||
        _selectedTakenStatus != null ||
        _startDate != null ||
        _endDate != null) {
      message = 'No dose history matches your filters';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedMedicationId != null ||
                      _selectedTakenStatus != null ||
                      _startDate != null ||
                      _endDate != null
                  ? 'Try changing or removing your filters'
                  : 'Start logging your medication doses to see them here',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_selectedMedicationId != null ||
                _selectedTakenStatus != null ||
                _startDate != null ||
                _endDate != null)
              ElevatedButton.icon(
                onPressed: () {
                  _resetFilters();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    // Group history by date
    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};

    for (final dose in _doseHistory) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        dose['timestamp'] as int,
      );
      final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }

      groupedHistory[dateKey]!.add(dose);
    }

    // Sort dates in descending order
    final sortedDates = groupedHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final doses = groupedHistory[dateKey]!;
        final displayDate = DateFormat('EEEE, MMMM d, yyyy').format(
          DateTime.parse(dateKey),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                displayDate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...doses.map((dose) {
              final timestamp = DateTime.fromMillisecondsSinceEpoch(
                dose['timestamp'] as int,
              );
              final taken = dose['taken'] == 1;
              final medicationId = dose['medicationId'] as int;
              final medicationName = dose['medicationName'] as String? ??
                  _medicationMap[medicationId]?.name ??
                  'Unknown Medication';

              return Card(
                margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: taken
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      taken ? Icons.check_circle : Icons.cancel,
                      color: taken ? Colors.green : Colors.red,
                      size: 32,
                    ),
                  ),
                  title: Text(
                    medicationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dose['medicationDosage'] as String? ??
                            _medicationMap[medicationId]?.dosage ??
                            '',
                      ),
                      Text(
                        DateFormat('h:mm a').format(timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    taken ? 'Taken' : 'Skipped',
                    style: TextStyle(
                      color: taken ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
            if (index < sortedDates.length - 1) const Divider(height: 32),
          ],
        );
      },
    );
  }
}
