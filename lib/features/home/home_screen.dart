import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:medbuddy/core/constants/asset_paths.dart';
import 'package:medbuddy/features/emergency/emergency_contacts_screen.dart';
import 'package:medbuddy/features/history/history_screen.dart';
import 'package:medbuddy/features/medications/medication_list_screen.dart';
import 'package:medbuddy/features/pill_identification/pill_identification_screen.dart';
import 'package:medbuddy/features/schedule/schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speakButtonName(String name) async {
    await _tts.speak(name);
  }

  void _navigateWithSound(BuildContext context, String title, Widget screen) {
    _speakButtonName(title);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double shortestSide = size.shortestSide;
    final double boxSize = shortestSide * 0.44;
    final double iconSize = boxSize * 0.85;
    final double majorBoxSize = shortestSide * 0.60;
    final double majorIconSize = majorBoxSize * 0.85;
    final double padding = shortestSide * 0.03;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedBuddy'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // First row: Medications and Schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureCard(
                  context,
                  title: 'Medications',
                  icon: AssetPaths.medScan,
                  iconSize: iconSize,
                  boxSize: boxSize,
                  onTap: () => _navigateWithSound(
                    context, 'Medications', const MedicationListScreen()),
                ),
                SizedBox(width: padding),
                _buildFeatureCard(
                  context,
                  title: 'Schedule',
                  icon: AssetPaths.reminderHistory,
                  iconSize: iconSize,
                  boxSize: boxSize,
                  onTap: () => _navigateWithSound(
                    context, 'Schedule', const ScheduleScreen()),
                ),
              ],
            ),
            SizedBox(height: padding),
            // Second row: Emergency Contacts and History
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureCard(
                  context,
                  title: 'Emergency Contacts',
                  icon: AssetPaths.call,
                  iconSize: iconSize,
                  boxSize: boxSize,
                  onTap: () => _navigateWithSound(
                    context, 'Emergency Contacts', const EmergencyContactsScreen()),
                ),
                SizedBox(width: padding),
                _buildFeatureCard(
                  context,
                  title: 'History',
                  icon: AssetPaths.document,
                  iconSize: iconSize,
                  boxSize: boxSize,
                  onTap: () => _navigateWithSound(
                    context, 'History', const HistoryScreen()),
                ),
              ],
            ),
            SizedBox(height: padding * 1.2),
            // Major focus: Pill Identification
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureCard(
                  context,
                  title: 'Pill Identification',
                  icon: AssetPaths.pillIdentification,
                  iconSize: majorIconSize,
                  boxSize: majorBoxSize,
                  onTap: () => _navigateWithSound(
                    context, 'Pill Identification', const PillIdentificationScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String icon,
    required VoidCallback onTap,
    double iconSize = 100,
    double boxSize = 120,
  }) {
    const double labelFontSize = 16;
    final double enlargedIconSize = iconSize * 1.03;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      icon,
                      height: enlargedIconSize,
                      width: enlargedIconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
