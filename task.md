# Smart Attendance Ecosystem & Master Panel - Task Checklist

Project task breakdown organized by priority modules and operational requirements.

---

## 🛡️ Module 1: Master Control Panel (Standalone Web Application - `master_panel/`)

- [x] **Standalone Master Project (`master_panel/`)**: Dedicated Web/Desktop control plane built in separate sub-project directory.
- [x] **Master Login Interface**: Authenticates Super Admin into Master Control Panel.
- [x] **Public Shop Onboarding Form**: Web/Mobile registration form generating `PENDING` application requests (`APP-XXXXXXXX`).
- [x] **Master Control Dashboard**: SaaS overview metrics (Total Shops, Active Shops, Paused Shops, Pending Applications, Kiosks).
- [x] **Shop Approval & Provisioning Engine**: Approval wizard generating unique `shopId` (e.g. `ABC001`), provisioning `ABC001@admin.in` & `ABC001@kiosk.in` accounts in Firebase.
- [x] **Remote Shop Pause & Resume**: Remote kill-switch to pause/resume any shop with Master Audit Log recording.
- [x] **Gmail SMTP Notification Worker**: Automatic email alert service to notify Master (`akmtechofficial@gmail.com`) via Gmail SMTP upon new shop registration.
- [x] **Master Audit Log & Security**: Operational security log viewer for shop provisioning and status changes.

---

## 👤 Module 2: Biometric Face Engine (MobileFaceNet TFLite)

- [x] **Google ML Kit Integration**: Real-time face bounding box and landmark detection on camera stream.
- [x] **MobileFaceNet Model Asset**: Bundled `assets/mobile_facenet.tflite` model file.
- [x] **128D Embedding Generator**: Preprocess crop tensor (112x112 RGB), execute TFLite inference via `tflite_flutter`, and extract 128D feature vector.
- [x] **Cosine Similarity Matcher**: L2 normalization and Cosine distance matching with configurable confidence threshold (>0.70).
- [ ] **Liveness & Anti-Spoofing Check**: Multi-frame quality validation and liveness check to prevent photo/screen spoofing.

---

## 📱 Module 3: Entrance Kiosk Scanner (Device A)

- [x] **Kiosk Full-Screen UI**: Locked-down kiosk UI for entrance devices with live camera scanner overlay.
- [x] **Instant Match Feedback**: Real-time visual feedback (*"Welcome Ravi Kumar"* or *"Face Not Recognized"*).
- [x] **Text-To-Speech (TTS) Voice Engine**: Personalized voice announcements (*"Ravi Kumar, Good Morning. Attendance Marked."*).
- [x] **Offline Attendance Queueing**: SQLite database queue for logging offline check-ins instantly.
- [x] **Remote Pause Enforcement**: Displays *"Service Temporarily Paused"* notice when shop is paused by Master Admin.
- [x] **Admin Exit Modal**: PIN/Password protected modal to exit Kiosk mode.

---

## 💼 Module 4: Shop Admin Console (Device B)

- [x] **Workforce Overview Dashboard**: Today's present, late, absent, and pending checkout statistics.
- [x] **Employee Directory & Enrollment**: Staff management workspace with face embedding enrollment wizard.
- [x] **Shift Engine & Attendance Rules**: Configure Morning, Evening, Night shifts, grace periods, and late thresholds.
- [x] **Staff Advance (Udhaar) Ledger**: Indian shop advance tracking with automated monthly salary deductions.
- [x] **Announcements & Emergency Alerts**: Broadcast announcements and 1-click Emergency Alert trigger.
- [ ] **Monthly Payslip Generator**: Generate and download printable monthly payslips with attendance breakdown.

---

## ⚡ Module 5: Offline-First Synchronization Engine

- [x] **SQLite Local Database (`attendance_offline.db`)**: Schema for pending attendance queue and local employee embedding cache.
- [x] **Connectivity Listener**: Real-time network state monitoring via `connectivity_plus`.
- [x] **Auto-Sync Worker**: Asynchronous background worker pushing pending SQLite records to Cloud Firestore upon internet reconnection.
- [ ] **Conflict Resolution & Duplicate Prevention**: Safeguards to resolve timestamp conflicts and prevent duplicate attendance entries.
