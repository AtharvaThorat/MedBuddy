
# MedBuddy

## Offline-First Accessible Healthcare Companion for Elderly Users

A production-grade Flutter mobile application designed to improve medication adherence through offline reliability, accessibility-first design, and intelligent reminder systems.

---

## 🧠 Executive Summary

MedBuddy is a healthcare-focused mobile application built to address medication non-adherence among elderly individuals.

The system combines:

* Offline-first architecture
* Accessibility engineering
* Voice interaction
* Local encrypted storage
* Camera + OCR processing
* Scheduled background notifications

This project demonstrates strong capabilities in:

* Mobile system design
* State management architecture
* Privacy-first engineering
* Accessibility implementation
* Real-world usability validation

---

## 🎯 Core Engineering Problem

Medication management systems often fail elderly users due to:

* Internet dependency
* Small UI elements
* Complex workflows
* Poor accessibility compliance
* Weak notification reliability

MedBuddy was engineered to solve these constraints using:

* 100% offline capability
* High-contrast adaptive UI
* Voice guidance
* Local encrypted database
* OS-level alarm scheduling

---

## 🏗 System Architecture Overview

```text
User Input
   │
   ▼
Flutter UI Layer (Material 3)
   │
   ▼
State Management (Provider - MVVM Pattern)
   │
   ▼
Service Layer
   ├── Notification Service (AlarmManager)
   ├── TTS Service
   ├── OCR Service (ML Kit)
   └── Database Service (Encrypted SQLite)
   │
   ▼
Local Secure Storage
```

### Architectural Principles Used

* Clean separation of UI and business logic
* MVVM-based state isolation
* Service abstraction layer
* Local-first persistence model
* Dependency-injected modular services

---

## ⚙️ Key Engineering Decisions

### 1️⃣ Offline-First by Design

All core functionality works without internet:

* Medication storage
* Reminder scheduling
* OCR recognition
* Voice guidance

Reason:
Elderly users may not have stable connectivity.

---

### 2️⃣ Encrypted Local Database (SQLCipher)

Sensitive health data is encrypted at rest.

Why:
Healthcare data privacy compliance principles.

---

### 3️⃣ OS-Level Alarm Scheduling

Used Android AlarmManager via `flutter_local_notifications`.

Reason:
Ensures reminders trigger even:

* When app is closed
* After device reboot
* In battery optimization modes

---

### 4️⃣ Accessibility-Driven UI Engineering

Implemented:

* Minimum 72dp tap targets
* Large scalable typography
* WCAG AAA contrast compliance
* Slower TTS speech rate
* Haptic confirmations

Accessibility was treated as a first-class engineering constraint, not an afterthought.

---

## 📸 Computer Vision Pipeline

Two-tier recognition system:

1. QR Code Parsing
2. OCR fallback using Google ML Kit

Engineering considerations:

* Camera permission fallback
* Lighting condition handling
* Error recovery
* Graceful degradation

Performance:

* Typed text OCR accuracy: High reliability
* Handwritten recognition: Moderate reliability
* Blurry input: Controlled fallback behavior

---

## 🔔 Reminder Reliability Engineering

Designed to handle:

* Multiple medications per day
* Edge case: overlapping reminders
* Duplicate prevention logic
* Overdose time-window validation
* Persistent notification state tracking

---

## 📊 Performance Characteristics

* <100ms local database query time
* Sub-2 second reminder scheduling
* Smooth 60 FPS UI rendering
* Low memory footprint
* Minimal battery drain

Optimized for Android 8.0+

---

## 🧪 Testing Strategy

* Unit testing for services
* Reminder timing verification
* Database CRUD validation
* End-to-end medication flow testing
* Real elderly usability testing sessions

User testing led to:

* Larger tap areas
* Reduced navigation depth
* Slower voice delivery rate
* Confirmation dialogs for destructive actions

---

## 🛠 Tech Stack

**Framework**
Flutter (Material 3)

**Language**
Dart

**Architecture**
MVVM with Provider

**Local Storage**
SQLite (SQLCipher encryption)

**Device Integrations**

* Camera API
* Google ML Kit OCR
* TTS Engine
* AlarmManager
* Local Notifications

---

## 💼 Role Alignment

### For Software Development Roles

Demonstrates:

* Clean architecture
* Modular service abstraction
* UI + business logic separation
* Performance optimization
* OS-level integration

---

### For AI Engineer Roles

Demonstrates:

* Applied computer vision (OCR pipeline)
* Intelligent fallback systems
* Error-tolerant real-world inference
* Data privacy considerations

---

### For ML Engineer Roles

Demonstrates:

* Understanding of model reliability
* Edge-case handling in inference systems
* Real-world deployment constraints
* Evaluation of recognition performance

---

### For LLM / Advanced AI Roles

Demonstrates:

* System-level AI integration
* Voice interaction pipeline
* Human-centered AI deployment
* Responsible AI usage in healthcare context

---

## 🚀 Future Technical Extensions

* On-device ML pill recognition (CNN-based classifier)
* Drug interaction detection
* Predictive adherence modeling
* Voice-only navigation mode
* Federated privacy-preserving sync

---

## 👨‍💻 Author

Atharva Thorat
Master’s in Computer Science
University of Southern California

Focus Areas:

* AI Systems Engineering
* Applied Machine Learning
* Accessibility-Driven Software
* LLM-Integrated Applications



