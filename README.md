# MedBuddy: Smart Healthcare Companion for the Elderly

**Empowering elderly individuals to manage their medications independently with voice guidance, offline functionality, and intuitive design.**

---

## 🌟 What is MedBuddy?

MedBuddy is an **offline-first mobile healthcare companion** specifically designed for elderly individuals with visual or cognitive impairments. Born from a BTech capstone project at MIT World Peace University, Pune, this Flutter application addresses the critical challenge of medication adherence among seniors through smart technology and accessible design.

Imagine an app that speaks to you, reminds you when to take your pills, reads prescription labels for you, and works perfectly even without internet—that's MedBuddy. It's not just another medication tracker; it's a compassionate digital companion that respects privacy, prioritizes accessibility, and operates entirely offline.

---

## 🎯 Why MedBuddy Exists

Every year, millions of elderly individuals struggle with medication management. Missed doses, confusion between pills, difficulty reading labels, and complex smartphone apps create barriers to proper healthcare. Many existing solutions require constant internet connectivity and fail to address the unique challenges faced by seniors.

**MedBuddy changes that.** It provides a comprehensive solution featuring large fonts, high-contrast themes, voice alerts, QR code scanning, and complete offline functionality—all designed with elderly users at the heart of every decision.

---

## ✨ Features That Make a Difference

### 🔍 **Smart Medication Identification**
- **QR Code Scanning**: Point your camera at medicine labels for instant identification
- **OCR Text Recognition**: Extract medication details from prescription images using Google ML Kit
- **Auto-Fill Magic**: Information automatically populates—no tedious typing required

### ⏰ **Intelligent Reminder System**
- **Scheduled Voice Alerts**: Text-to-Speech reads out medicine names and dosages at the right time
- **Persistent Notifications**: Reminders work even when the app is closed
- **Overdose Protection**: Smart alerts prevent taking medication at incorrect times
- **Never Miss a Dose**: AlarmManager ensures reliability across device reboots

### 📊 **Comprehensive Tracking**
- **Visual Calendar**: See your entire medication schedule at a glance
- **Detailed History**: Track taken, missed, and skipped doses with timestamps
- **Progress Monitoring**: Understand adherence patterns over time
- **Color-Coded System**: Instantly identify medication status

### 👴 **Designed for Seniors**
- **Extra Large Fonts**: No squinting required
- **High Contrast Themes**: Dark and light modes for better visibility
- **Simplified Navigation**: Reach any feature in minimal taps
- **Voice Guidance**: Optional audio prompts for every action
- **Haptic Feedback**: Physical confirmation for every interaction

### 🔒 **Privacy First**
- **100% Offline**: No internet required for core functionality
- **Encrypted Storage**: SQLite database with military-grade encryption
- **Local Data Only**: Your health information never leaves your device
- **Zero Cloud Dependency**: Complete privacy control

### 🆘 **Emergency Ready**
- **One-Tap Calling**: Reach caregivers instantly with emergency contacts
- **Prominent Access**: Red emergency button always visible on dashboard
- **Auto-Dial Support**: No need to remember phone numbers in critical moments

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have:
- **Flutter SDK** (v3.19 or higher)
- **Dart SDK** (v3.0 or higher)
- **Android Studio** or **VS Code**
- An **Android device** or emulator (API level 24+)
- **Git** installed on your machine

### Installation

```bash
# Clone this repository
git clone https://github.com/yourusername/medbuddy.git

# Navigate to project directory
cd medbuddy

# Install dependencies
flutter pub get

# Check your Flutter setup
flutter doctor

# Run the app
flutter run
```

### Building for Production

```bash
# Generate release APK
flutter build apk --release

# Install on connected device
flutter install
```

### Required Permissions

MedBuddy needs these permissions to serve you better:
- 📷 **Camera** - For QR scanning and OCR text recognition
- 🔔 **Notifications** - For medication alerts and reminders
- 📞 **Phone** - For emergency contact calling
- 💾 **Storage** - For local database (auto-granted)

---

## 🎨 My Contribution to MedBuddy

As **Atharva Thorat**, I played a pivotal role in bringing MedBuddy from concept to reality during my BTech Computer Science and Engineering program at MIT World Peace University.

### 🔬 Research & Analysis Phase

I conducted extensive research analyzing over **20 scholarly papers and industry reports** to understand the medication management landscape. This deep dive revealed critical gaps in existing solutions—particularly the glaring absence of offline functionality and accessibility features designed specifically for elderly users. These insights became the foundation for MedBuddy's feature set and design philosophy.

### 🏗️ System Architecture & Design

I designed comprehensive **system-level diagrams** including:
- **Activity Diagrams**: Mapping real-world user scenarios like medication intake workflows
- **Sequence Diagrams**: Visualizing system interactions during emergency responses
- **Data Flow Diagrams**: Documenting how information moves through the application

These diagrams ensured our team had a clear blueprint before writing a single line of code.

### 💻 Frontend Development

I implemented and optimized critical user interfaces:

**Dashboard Screen**: The central hub where users see today's medications, upcoming doses, and quick access to all features. I designed it with extra-large tap targets and clear visual hierarchy to minimize cognitive load.

**Schedule Interface**: A calendar-based view that shows medication patterns over time. I integrated the `table_calendar` package and customized it for elderly users with color-coded dose status indicators.

**Responsive Design**: Ensured the app adapts seamlessly across different Android devices, screen sizes, and orientations—from budget smartphones to high-end tablets.

### ♿ Accessibility Engineering

Accessibility wasn't an afterthought—it was integral to every decision:

- **Text-to-Speech Integration**: Implemented using `flutter_tts` to read medication names, dosages, and instructions aloud
- **High Contrast Themes**: Developed dark and light modes that meet WCAG AAA standards for color contrast
- **Dynamic Font Scaling**: Built custom text widgets that scale from 18sp to 32sp based on user preferences
- **Voice Guidance System**: Created optional audio prompts for every action, making the app usable without looking at the screen

### 📸 Camera & OCR System

I developed robust camera handling logic supporting:
- **QR Code Recognition**: Using `barcode_scan2` for instant medication identification
- **OCR Fallback**: Integrated Google ML Kit text recognition when QR codes aren't available
- **Image Quality Optimization**: Implemented auto-focus and lighting adjustment suggestions
- **Error Handling**: Graceful fallbacks when camera access is denied or OCR fails

### 🏛️ Architecture & Code Quality

I structured the Flutter project following **clean architecture principles**:
- **MVVM Pattern**: Separated business logic from UI using Provider for state management
- **Modular Design**: Created reusable widgets and services for maintainability
- **Code Documentation**: Wrote comprehensive inline comments and documentation
- **Performance Optimization**: Ensured 60 FPS UI rendering and sub-100ms database queries

### 🧪 User Testing & Iteration

I conducted extensive **usability testing** with real elderly users:
- Organized testing sessions with 5+ participants aged 50-75
- Gathered qualitative feedback through interviews
- Measured task completion times and error rates
- Iterated on design based on user pain points

**Key improvements from testing:**
- Increased button sizes from 48dp to 72dp after users struggled with smaller targets
- Added confirmation dialogs for destructive actions like deleting medications
- Simplified navigation from 4 taps to 2 taps for common tasks
- Enhanced voice alerts with slower speech rate and clearer pronunciation

---

## 🛠️ Technology Stack

**Core Framework**
- Flutter 3.19+ (Cross-platform mobile development)
- Dart 3.0+ (Programming language)

**State Management**
- Provider (Lightweight and reactive)
- ChangeNotifier (Real-time UI updates)

**Local Storage**
- sqflite (SQLite database)
- sqflite_sqlcipher (Encrypted storage)
- shared_preferences (Settings persistence)

**Device Features**
- flutter_local_notifications (Scheduled alerts)
- flutter_tts (Text-to-speech)
- barcode_scan2 (QR scanning)
- google_mlkit_text_recognition (OCR)
- url_launcher (Emergency calling)

**UI Components**
- table_calendar (Schedule visualization)
- Material Design 3 (Modern, accessible UI)

**Development Tools**
- Android Studio (Primary IDE)
- Flutter DevTools (Performance profiling)
- GitHub Actions (CI/CD pipeline)

---

## 📊 Performance Metrics

MedBuddy is optimized for older Android devices:

| Operation | Performance | Details |
|-----------|------------|---------|
| QR Scan & Parse | ~1.5 seconds | Instant medication identification |
| Reminder Scheduling | <2 seconds | For up to 10 daily medications |
| Calendar Rendering | Real-time | Smooth 60 FPS scrolling |
| TTS Output | <1 second | Clear, natural voice |
| Database Query | <100ms | Lightning-fast data retrieval |

**App Specifications:**
- 📦 APK Size: <50MB
- 💾 Memory Usage: <120MB runtime
- 🔋 Battery Impact: Minimal (optimized notifications)
- 📱 Compatibility: Android 8.0 to 13+

**Test Results:**
- ✅ OCR Accuracy (Typed): **98%**
- ✅ OCR Accuracy (Handwritten): **83%**
- ⚠️ OCR Accuracy (Blurry): **70%**
- ✅ Offline Functionality: **100%**
- ✅ Notification Reliability: **100%**

---

## 🎬 How to Use MedBuddy

### For Patients (Elderly Users)

**First Time Setup:**
1. Open MedBuddy on your phone
2. Allow camera, notification, and phone permissions
3. You're ready—no account needed!

**Adding Medication (Two Easy Ways):**

*Method 1: Scan QR Code*
- Tap the big blue "Scan Medicine" button
- Point camera at medicine label
- Information fills in automatically
- Tap "Save"

*Method 2: Manual Entry*
- Tap "Add Medicine"
- Speak or type medicine name
- Set time for reminder
- Tap "Save"

**Taking Your Medicine:**
- When you hear the reminder, look at your phone
- MedBuddy shows which pill to take
- Take your medicine
- Tap "Mark as Taken"
- Done!

**Viewing Your Schedule:**
- Tap "Schedule" at bottom
- See calendar with colored dots (Green = Taken, Red = Missed)
- Tap any day to see details

**Emergency Help:**
- See the big red "Emergency" button?
- Tap it anytime
- Phone automatically calls your caregiver

### For Caregivers

**Setting Up for Your Loved One:**
1. Install MedBuddy on their phone
2. Add all their medications with photos
3. Set reminder times matching prescription
4. Add your phone number as emergency contact
5. Show them the "Emergency" button location
6. Hand them the phone—it works automatically!

**Monitoring Adherence:**
- Check "History" tab weekly
- Look for missed doses (red indicators)
- Adjust reminder times if needed
- Export report for doctor visits (coming soon)

---

## 🗂️ Project Structure

```
medbuddy/
│
├── lib/
│   ├── main.dart                  # App entry point
│   │
│   ├── models/                    # Data models
│   │   ├── medication_model.dart
│   │   ├── schedule_model.dart
│   │   └── history_model.dart
│   │
│   ├── screens/                   # UI screens 
│   │   ├── dashboard.dart         # Main screen
│   │   ├── schedule_screen.dart   # Calendar view
│   │   ├── add_medicine.dart
│   │   └── history_screen.dart
│   │
│   ├── services/                  # Business logic
│   │   ├── notification_service.dart
│   │   ├── tts_service.dart
│   │   └── ocr_service.dart
│   │
│   ├── providers/                 # State management
│   │   └── medication_provider.dart
│   │
│   └── widgets/                   # Reusable components
│       ├── medicine_card.dart
│       └── custom_button.dart
│
├── test/                          # Unit tests
├── android/                       # Android config
└── pubspec.yaml                   # Dependencies
```

---

## 🧪 Testing & Quality Assurance

### Comprehensive Test Coverage

**Unit Tests:**
- Database CRUD operations validation
- Reminder scheduling logic verification
- QR code parsing accuracy
- OCR text extraction reliability

**Integration Tests:**
- End-to-end medication workflow
- Notification trigger timing
- Calendar synchronization accuracy

**Accessibility Tests:**
- TTS pronunciation and clarity
- Font scaling across ranges
- Color contrast ratios (WCAG compliance)
- Touch target sizes (minimum 48dp)

**Real-World Testing:**
- Tested with 5 elderly users (ages 50-75)
- Scenarios: Adding meds, taking doses, emergency calls
- Measured: Task completion time, error rate, satisfaction
- Result: 95% task success rate, 4.5/5 average satisfaction

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage report
flutter test --coverage

# Run specific test file
flutter test test/services/notification_service_test.dart
```

---

## 🔮 Future Roadmap

### Phase 1: Enhanced Accessibility (Q3 2025)
- [ ] iOS version deployment
- [ ] Multi-language support (Hindi, Marathi, Tamil, Bengali)
- [ ] Voice-activated navigation (hands-free control)
- [ ] Braille display support

### Phase 2: Smart Features (Q4 2025)
- [ ] AI-powered pill recognition (shape + color)
- [ ] Drug interaction warnings
- [ ] Refill reminders with pharmacy integration
- [ ] Wearable device sync (smartwatch alerts)

### Phase 3: Connected Care (2026)
- [ ] Optional cloud sync (privacy-preserving)
- [ ] Caregiver dashboard (remote monitoring)
- [ ] Healthcare provider portal
- [ ] Telemedicine appointment booking
- [ ] Integration with health records (HL7 FHIR)

### Long-term Vision
- [ ] Predictive adherence analytics using machine learning
- [ ] Multi-patient support for care facilities
- [ ] Medication delivery coordination
- [ ] Integration with smart home devices
- [ ] Global expansion with WHO collaboration

---

## 👨‍💻 About Me

Hi! I'm **Atharva Thorat**, a Master's Computer Science **University of Soutern California**.

**What Drives Me:**
I'm passionate about creating technology that genuinely improves people's lives—especially for underserved populations. MedBuddy represents my belief that good design isn't just about aesthetics; it's about empathy, accessibility, and solving real human problems.

**My Focus Areas:**
- 📱 Mobile Application Development (Flutter, React Native)
- 🎨 User Experience Design for Accessibility
- 🏥 Healthcare Technology & Digital Health
- ♿ Assistive Technology Engineering
- 🔊 Voice Interface Design

**Academic Journey:**
This capstone project was developed under the expert guidance of **Prof. Laxmi Bhagwat** and program coordinator **Dr. Balaji M. Patil** during the 2024-2025 academic year. It represents countless hours of research, design iterations, user testing, and refinement—all driven by the goal of making healthcare more accessible.

---

## 🙏 Acknowledgments

This project wouldn't exist without incredible support:

**Academic Mentors:**
- **Prof. Laxmi Bhagwat** - For invaluable guidance, technical insights, and pushing me to think beyond conventional solutions
- **Dr. Balaji M. Patil** - For providing resources, infrastructure, and unwavering academic support
- **MIT-WPU Faculty** - For creating an environment that encourages innovation

**Real Heroes:**
- **Elderly Test Participants** - For patiently testing prototypes and providing honest, constructive feedback
- **My Family** - For supporting late-night coding sessions and believing in this project's mission

**Open Source Community:**
- Google ML Kit team for exceptional OCR capabilities
- Flutter team for incredible documentation
- SQLCipher team for robust encryption
- Material Design team for accessibility guidelines
- Every package maintainer whose code powers MedBuddy


---

## 📬 Connect & Contribute

**Found a bug?** Open an issue with detailed steps to reproduce.

**Have a feature idea?** Share it in discussions—I'd love to hear from you!

**Want to contribute?** Fork the repo, make your changes, and submit a pull request.

**Questions?** Reach out through:
- 📧 [atharvathorat03@gmail.com]
- 💼 [[LinkedIn Profile](https://www.linkedin.com/in/atharva-thorat-604146239/)]

---

## 🌟 Star This Project

If MedBuddy resonates with you, please give it a ⭐️ on GitHub! Your support motivates continued development and helps others discover this project.

---

<div align="center">

**Built with ❤️ for the elderly community**

*Because everyone deserves accessible healthcare*

[![Made with Flutter](https://img.shields.io/badge/Made%20with-Flutter-blue.svg?style=flat-square&logo=flutter)](https://flutter.dev)
[![Offline First](https://img.shields.io/badge/Offline-First-green.svg?style=flat-square)](https://offlinefirst.org/)
[![Accessibility](https://img.shields.io/badge/Accessibility-AAA-purple.svg?style=flat-square)](https://www.w3.org/WAI/WCAG2AAA-Conformance)

**MedBuddy** | Empowering Independence Through Technology

[⬆ Back to Top](#medbuddy-smart-healthcare-companion-for-the-elderly)

</div>

---

## 📚 Additional Resources

Want to dive deeper?
- 📖 [Full Project Report](docs/FINAL_MEDBUDDY_REPORT.pdf) - Comprehensive 69-page documentation
- 🎓 [Research Paper](docs/research_paper.pdf) - Academic findings and methodology
- 🎨 [Design System](docs/design_guidelines.md) - UI/UX principles and patterns
- 🧪 [Testing Documentation](docs/testing.md) - Quality assurance procedures
- 📊 [System Architecture](docs/architecture.md) - Technical deep dive

---

*Last Updated: May 2025 | Version 1.0.0 | Academic Year 2024-2025*

