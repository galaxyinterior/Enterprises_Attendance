# INDIAN STAFF MANAGEMENT & SMART ATTENDANCE ECOSYSTEM

## 1. PRODUCT VISION

Build a production-ready Flutter application ecosystem for Indian shops, offices, restaurants, warehouses, clinics, factories, retail stores and other businesses.

The product is NOT only an attendance application.

It must become a complete:

* Employee Management System
* Face-Based Attendance System
* Shift Management System
* Attendance Calendar
* Salary Management System
* Leave Management System
* Announcement System
* Voice Announcement System
* Offline-First Attendance System
* Staff Analytics System
* Business Workforce Management System

The product should be extremely simple for Indian business owners who may not be technically sophisticated.

Primary design principle:

> "Admin should be able to manage the entire staff from one phone, while another dedicated device continuously handles attendance."

---

# 2. DEVICE ARCHITECTURE

There are two primary devices.

## DEVICE A — ATTENDANCE DEVICE

This device is normally installed at:

* Shop entrance
* Office entrance
* Factory gate
* Restaurant entrance
* Reception
* Staff entry point

Responsibilities:

* Camera continuously available
* Detect employee face
* Identify registered employee
* Validate employee's assigned shift
* Validate attendance time window
* Mark check-in
* Validate checkout window
* Mark checkout
* Work offline
* Store pending attendance locally
* Synchronize when internet returns
* Receive admin announcements
* Play text-to-speech announcements
* Play recorded voice announcements
* Show employee name/status
* Prevent duplicate attendance

The attendance device should have a dedicated kiosk-style UI.

---

# 3. DEVICE B — ADMIN DEVICE

The admin can use:

* Android phone
* Android tablet
* iPhone where supported

Responsibilities:

* Admin authentication
* Add employees
* Edit employees
* Delete/deactivate employees
* Capture employee profile
* Capture face data
* Assign employee ID
* Assign shift
* Configure attendance windows
* Configure checkout windows
* Manage multiple shifts
* View attendance
* Calendar
* Today
* This week
* This month
* Custom date range
* Employee-wise attendance
* Salary management
* Leave management
* Late/early tracking
* Overtime
* Announcements
* Text-to-speech announcements
* Record voice announcements
* Send announcement to attendance device
* Manage business settings
* Manage attendance device
* View synchronization status
* Export reports

---

# 4. AUTHENTICATION

Use Firebase Authentication.

Admin login:

* Email/username based identity
* Password
* Business/company association
* Admin role

Do NOT use a shared hardcoded admin password.

Every admin account must belong to a business/organization.

Suggested structure:

users/{userId}

Fields:

* uid
* businessId
* name
* email
* role
* createdAt
* updatedAt
* active

Roles:

ADMIN
MANAGER
OWNER

Employee does NOT need Firebase Authentication.

Employees are records managed by the business.

---

# 5. BUSINESS STRUCTURE

Firestore:

businesses/{businessId}

Example:

{
"businessId": "...",
"businessName": "ABC Store",
"ownerName": "...",
"phone": "...",
"address": "...",
"timezone": "Asia/Kolkata",
"currency": "INR",
"createdAt": "...",
"updatedAt": "..."
}

Every business-owned document must contain businessId or be nested under the business.

Never allow one business to read another business's data.

Firestore Security Rules must enforce tenant isolation.

---

# 6. EMPLOYEE MANAGEMENT

Firestore:

businesses/{businessId}/employees/{employeeId}

Employee fields:

* employeeId
* employeeCode
* fullName
* phone
* alternatePhone
* email
* profilePhotoUrl
* faceEnrollmentStatus
* faceEmbedding/reference
* department
* designation
* assignedShiftId
* joiningDate
* salaryType
* monthlySalary
* dailySalary
* hourlyRate
* bankAccountLast4
* emergencyContact
* address
* active
* createdAt
* updatedAt

Avoid storing unnecessary sensitive information.

Employee deletion should preferably be soft deletion:

active = false

This preserves historical attendance and salary records.

---

# 7. FACE ENROLLMENT

The admin should be able to enroll an employee's face.

Flow:

1. Admin opens Add Employee.
2. Enter employee details.
3. Open camera.
4. Ask employee to look at camera.
5. Capture multiple suitable frames.
6. Detect face.
7. Validate image quality.
8. Generate face representation/embedding locally.
9. Store only the minimum required biometric representation.
10. Associate it with employeeId.
11. Confirm enrollment.

IMPORTANT:

Do not send every camera frame to Firebase.

Do not continuously upload camera footage.

Face recognition should preferably happen on the attendance device locally.

The system must include:

* face detection
* face quality validation
* liveness/anti-spoofing where technically feasible
* confidence threshold
* duplicate face detection
* unknown face handling

If confidence is below the configured threshold:

DO NOT mark attendance.

Show:

"Face not recognized"

Never automatically assign an unknown face to an employee.

Because biometric information is sensitive, include appropriate consent, privacy notice, retention and deletion controls appropriate to the business and applicable Indian law.

---

# 8. ATTENDANCE ENGINE

Attendance should be event based.

Basic event types:

CHECK_IN
CHECK_OUT

Attendance document:

businesses/{businessId}/attendance/{attendanceId}

Suggested fields:

* attendanceId
* employeeId
* date
* shiftId
* checkInTime
* checkOutTime
* checkInDeviceId
* checkOutDeviceId
* status
* source
* confidence
* createdAt
* updatedAt
* syncStatus

Possible status:

PRESENT
LATE
EARLY
ABSENT
HALF_DAY
LEAVE
HOLIDAY
WEEK_OFF
OVERTIME

Source:

ONLINE
OFFLINE
SYNCED

---

# 9. ATTENDANCE TIME WINDOW

Admin must configure attendance windows.

Example:

Business opening:
10:00 AM

Attendance window:

10:00 AM → 10:30 AM

Employees assigned to this shift can check in only during this window.

If employee appears at:

09:45 AM

Do not mark attendance.

If employee appears at:

10:15 AM

Mark attendance.

If employee appears at:

10:31 AM

Do not mark normal attendance.

Instead show:

"Attendance window closed"

Optionally provide a manager/admin override mechanism.

Admin should be able to configure:

* attendance start
* attendance end
* grace period
* late threshold
* auto-absent time
* checkout start
* checkout end

---

# 10. LATE ATTENDANCE

Admin setting:

Late threshold

Example:

Shift:
10:00 AM

Grace period:
10 minutes

10:00–10:10:

PRESENT

10:11 onwards:

LATE

However, whether late employees are allowed to mark attendance or not should be configurable.

Settings:

allowLateAttendance = true/false

If false:

Attendance window closes at configured time.

If true:

attendance can still be marked as LATE.

---

# 11. CHECKOUT

Checkout must be independently configurable.

Example:

Checkout window:

7:00 PM → 8:00 PM

Employee can check out only during this period.

If employee attempts checkout before window:

"Checkout has not started yet."

If after window:

"Checkout window has closed."

Admin may configure:

* allow early checkout
* allow late checkout
* auto checkout
* mandatory checkout
* overtime calculation

---

# 12. MULTIPLE SHIFTS

The system MUST support multiple shifts.

Example:

SHIFT A:

Name:
Morning Shift

Start:
06:00 AM

Check-in window:
06:00 AM → 06:20 AM

Checkout:
02:00 PM → 03:00 PM

SHIFT B:

Name:
Evening Shift

Start:
02:00 PM

Check-in:
02:00 PM → 02:20 PM

Checkout:
10:00 PM → 11:00 PM

SHIFT C:

Night Shift

Start:
10:00 PM

Check-in:
10:00 PM → 10:20 PM

Checkout:
06:00 AM → 07:00 AM

Employee:

Ravi → Morning Shift

If Ravi appears during Evening Shift:

DO NOT mark attendance.

Show:

"Ravi is assigned to Morning Shift."

The system must validate:

employee.assignedShiftId

against

current shift.

---

# 13. OVERNIGHT SHIFTS

This is extremely important.

Support shifts where checkout happens on the next calendar day.

Example:

Shift starts:

10:00 PM — 11 September

Checkout:

06:00 AM — 12 September

Attendance engine must understand that this is one shift, not two separate days.

Use proper shift instance/date logic.

Never determine shift solely from calendar date.

---

# 14. SHIFT ASSIGNMENT

Employee can have:

* one default shift
* future shift assignment
* temporary shift assignment
* shift change history

Recommended structure:

employeeShiftAssignments

Fields:

* employeeId
* shiftId
* effectiveFrom
* effectiveTo
* active

This allows:

Ravi:

Morning Shift:
01 Sep → 15 Sep

Night Shift:
16 Sep → 30 Sep

---

# 15. ATTENDANCE DEVICE

Device registration:

businesses/{businessId}/devices/{deviceId}

Fields:

* deviceId
* deviceName
* deviceType
* active
* lastSeen
* appVersion
* assignedLocation
* createdAt

Device types:

ATTENDANCE_KIOSK
ADMIN_DEVICE

Attendance device should pair with a business.

Suggested pairing process:

Admin generates temporary pairing code.

Attendance device enters code.

Backend validates code.

Device becomes linked to business.

Do not hardcode business credentials inside the application.

---

# 16. KIOSK UI

Attendance device should have a very simple interface.

Top:

Business Name

Center:

LIVE CAMERA PREVIEW

Below:

"Please look at the camera"

When recognized:

"Welcome, Ravi"

Then:

"Attendance marked successfully."

Voice:

"Ravi, your attendance has been marked."

After a few seconds:

Return automatically to camera screen.

Unknown:

"Face not recognized."

Wrong shift:

"You are not scheduled for this shift."

Outside window:

"Attendance window is closed."

---

# 17. DUPLICATE ATTENDANCE PREVENTION

Employee must not receive multiple check-ins on the same shift.

Example:

Ravi checks in at 10:05.

At 10:08 camera sees Ravi again.

Do NOT create another attendance record.

Instead:

"Attendance already marked."

Similarly checkout must be idempotent.

Use Firestore transactions/server-side validation where appropriate.

---

# 18. OFFLINE-FIRST ARCHITECTURE

This is a core requirement.

Attendance must continue working even if:

* Wi-Fi is disconnected
* Mobile data is disconnected
* Firebase temporarily unavailable
* Internet is unstable

Local database/cache should be used.

Do NOT rely only on a plain JSON file for the production implementation.

Recommended:

* local SQLite/Drift or Hive/Isar
* local queue
* optional JSON export/debug backup

Architecture:

Camera
↓
Face Recognition
↓
Attendance Engine
↓
Local Attendance Database
↓
Sync Queue
↓
Firebase Firestore

If online:

Local → Firestore immediately

If offline:

Local → Queue

When connection returns:

Queue → Firestore

After successful synchronization:

Mark local record:

SYNCED

---

# 19. OFFLINE DATA MODEL

Local attendance:

{
"localId": "...",
"employeeId": "...",
"date": "...",
"shiftId": "...",
"eventType": "CHECK_IN",
"timestamp": "...",
"deviceId": "...",
"faceConfidence": 0.94,
"syncStatus": "PENDING"
}

Never lose attendance because internet is unavailable.

Use unique event IDs so synchronization is idempotent.

If the same event is uploaded twice, Firestore must not create duplicates.

---

# 20. DEVICE CLOCK SECURITY

Offline attendance introduces clock manipulation risk.

Therefore:

* Record device time.
* Record last known trusted server time.
* Track clock offset.
* Warn if device clock changes significantly.
* Admin can see suspicious time changes.
* When online, synchronize trusted time.
* Do not blindly trust a modified system clock.

For highly sensitive businesses, consider requiring periodic online validation.

---

# 21. FIREBASE SERVICES

Minimum backend:

Firebase Authentication
Firebase Firestore
Firebase Storage

Optional:

Firebase Cloud Messaging
Firebase App Check
Cloud Functions

Storage should be used for:

* Employee profile photos
* Voice announcements
* Other explicitly uploaded media

Do NOT upload camera video continuously.

---

# 22. FIRESTORE STRUCTURE

Recommended:

businesses/
{businessId}/

```
    employees/
        {employeeId}

    shifts/
        {shiftId}

    attendance/
        {attendanceId}

    leaveRequests/
        {leaveId}

    salaryRecords/
        {salaryRecordId}

    announcements/
        {announcementId}

    devices/
        {deviceId}

    holidays/
        {holidayId}

    settings/
        general

    auditLogs/
        {logId}

    adminUsers/
        {uid}
```

---

# 23. ATTENDANCE CALENDAR

Admin dashboard must include calendar.

Views:

TODAY
THIS WEEK
THIS MONTH
CUSTOM RANGE

Calendar indicators:

Present
Absent
Late
Leave
Holiday
Half Day
Week Off

Clicking a date:

Show:

Employee
Shift
Check-in
Check-out
Working hours
Late status
Overtime
Attendance source

---

# 24. EMPLOYEE ATTENDANCE PROFILE

When admin opens employee:

Display:

Name
Photo
Employee ID
Department
Designation
Assigned Shift

Statistics:

Present days
Absent days
Late days
Leave days
Half days
Overtime hours
Total working hours

Monthly attendance calendar.

---

# 25. ATTENDANCE SUMMARY

Dashboard cards:

Today's Staff

Present

Absent

Late

On Leave

Not Checked Out

Total Working

Overtime

Example:

TODAY

Total Staff: 35
Present: 29
Absent: 4
Late: 2
Leave: 2

---

# 26. SALARY MANAGEMENT

Salary system should support:

MONTHLY
DAILY
HOURLY

Employee salary configuration:

* salaryType
* basicSalary
* monthlySalary
* dailyRate
* hourlyRate
* overtimeRate

Salary calculation should be configurable.

Example:

Monthly salary:
₹18,000

Working days:
26

Per-day calculation:

₹18,000 / 26

But the business should be able to configure the calculation method.

Do NOT hardcode one Indian payroll formula.

---

# 27. SALARY COMPONENTS

Support:

Basic salary
Attendance deductions
Late deductions
Leave deductions
Overtime
Bonus
Advance
Commission
Other allowance
Other deduction

Salary record:

salaryMonth
employeeId
grossSalary
attendanceDeduction
leaveDeduction
overtime
bonus
advance
otherDeduction
netSalary
status

Status:

DRAFT
FINALIZED
PAID

---

# 28. SALARY DASHBOARD

Admin can select:

September 2026

Then employee list:

Employee
Working Days
Present
Absent
Leave
Late
Overtime
Gross
Deduction
Bonus
Net Salary
Payment Status

---

# 29. SALARY PAYMENT TRACKING

Allow:

Unpaid
Partially Paid
Paid

Fields:

* paymentDate
* paymentMethod
* transactionReference
* amountPaid
* notes

Payment methods:

CASH
UPI
BANK_TRANSFER
OTHER

Do not integrate actual banking initially.

This is record keeping, not a payment gateway.

---

# 30. LEAVE MANAGEMENT

Admin can create:

Casual Leave
Sick Leave
Paid Leave
Unpaid Leave
Other

Employee attendance should automatically consider approved leave.

If employee has approved leave:

Status = LEAVE

No false ABSENT entry.

---

# 31. HOLIDAY MANAGEMENT

Admin can configure holidays.

Example:

15 August
26 January
2 October
Diwali
Business-specific holidays

Holiday calendar:

date
name
type

Attendance engine should recognize holidays.

---

# 32. WEEKLY OFF

Support employee/business weekly off.

Examples:

Sunday
Monday
Rotating weekly off

For rotating staff:

store weekly-off rules per employee/shift.

---

# 33. ANNOUNCEMENT SYSTEM

Admin can send announcement to attendance device.

Types:

TEXT
TEXT_TO_SPEECH
RECORDED_VOICE

Example:

"Everyone please report to the manager."

Attendance device receives announcement.

---

# 34. TEXT TO SPEECH

Admin enters:

"Ravi please report to the manager."

System sends text.

Attendance device:

* receives announcement
* displays text
* converts to speech locally
* plays audio

Use native Flutter-compatible TTS.

Do not unnecessarily generate and upload audio for every text announcement.

---

# 35. RECORDED VOICE

Admin can:

1. Tap Record.
2. Record voice.
3. Preview.
4. Send.

Audio is uploaded to Firebase Storage.

Attendance device receives announcement metadata.

Downloads audio.

Plays it.

After successful delivery/playback and according to retention policy, temporary audio can be deleted.

Never keep unnecessary recordings forever.

---

# 36. ANNOUNCEMENT DOCUMENT

announcements/{announcementId}

Fields:

* announcementId
* businessId
* type
* text
* audioUrl
* createdBy
* createdAt
* targetDeviceIds
* status
* expiresAt

Status:

PENDING
DELIVERED
PLAYED
EXPIRED

---

# 37. NOTIFICATION

For instant announcement delivery, use Firebase Cloud Messaging where appropriate.

Flow:

Admin
↓
Create announcement
↓
Firestore
↓
FCM notification
↓
Attendance device
↓
Fetch announcement
↓
Display/play

If offline:

Device receives it after reconnecting.

---

# 38. ADMIN DASHBOARD

Home screen should show:

Business name

Today:

Total Staff
Present
Absent
Late
Leave
Not Checked Out

Quick actions:

* Add Employee
  Attendance
  Employees
  Salary
  Shifts
  Leave
  Announcements
  Reports
  Settings

---

# 39. EMPLOYEE LIST

Search by:

Name
Employee ID
Phone
Department

Filters:

All
Active
Inactive
Shift
Department

Employee card:

Photo
Name
ID
Shift
Today's status

---

# 40. REPORTS

Generate:

Daily Attendance
Weekly Attendance
Monthly Attendance
Employee Attendance
Shift Attendance
Salary Report
Late Report
Absent Report
Overtime Report
Leave Report

Export:

CSV
PDF

Do not load huge datasets directly into UI.

Use pagination and aggregated queries.

---

# 41. SEARCH AND FILTERS

Admin must be able to filter:

Date
Employee
Shift
Department
Attendance status
Late
Absent
Leave

---

# 42. AUDIT LOG

Every important administrative operation should be logged.

Examples:

Employee created
Employee edited
Employee deactivated
Shift changed
Salary changed
Attendance manually modified
Announcement sent
Device paired
Settings changed

Fields:

* actorUid
* businessId
* action
* targetId
* timestamp
* metadata

This protects against disputes.

---

# 43. MANUAL ATTENDANCE OVERRIDE

Admin should be able to correct attendance.

Example:

Employee forgot to check out.

Admin can add:

Check-out:
7:12 PM

But the system must show:

"Manually modified by Admin"

Never silently change historical records.

---

# 44. ATTENDANCE DISPUTE PROTECTION

For each attendance event maintain:

* original timestamp
* device
* source
* face confidence
* sync status
* modification history

This is important for salary disputes.

---

# 45. MULTIPLE ATTENDANCE DEVICES

Initially support one attendance device.

But architecture should support multiple.

Example:

Shop entrance
Warehouse entrance
Back entrance

Admin can manage:

Device A
Device B
Device C

All belong to the same business.

Avoid designing the backend in a way that assumes only one device forever.

---

# 46. DEVICE STATUS

Admin should see:

Attendance Device

Online
Offline

Last seen:
2 minutes ago

App version:
1.0.0

Battery:
optional

Storage:
optional

Camera:
Available / Error

Sync:

Synced
Pending events: 4

---

# 47. CAMERA FAILURE

If camera fails:

Display:

"Camera unavailable"

Admin should receive device warning.

Attendance device must NOT falsely mark attendance.

---

# 48. INTERNET FAILURE

Display small non-intrusive indicator:

OFFLINE

Attendance continues locally.

When internet returns:

SYNCING...

Then:

ALL DATA SYNCED

---

# 49. FACE RECOGNITION PERFORMANCE

Do not continuously run expensive processing on every full-resolution frame.

Optimize:

* camera resolution
* frame sampling
* face detection interval
* embedding comparison
* recognition threshold
* CPU/GPU usage

Example architecture:

Camera frame
↓
Detect face
↓
If face exists
↓
Crop face
↓
Quality check
↓
Liveness
↓
Embedding
↓
Compare with local employee embeddings
↓
Confidence threshold
↓
Attendance validation
↓
Mark attendance

---

# 50. LOCAL EMPLOYEE DATA

Attendance device needs employee recognition data offline.

Therefore when admin adds/updates employee:

Cloud
↓
Sync
↓
Attendance device
↓
Local employee index

Store minimum necessary information locally.

For example:

employeeId
displayName
photo/reference
face representation
assigned shift
active status

Do not download unnecessary employee information to the kiosk.

---

# 51. EMPLOYEE DATA SYNC

When employee is added:

Firestore employee created.

Attendance device detects change.

Downloads required recognition data.

Updates local database.

If employee is deactivated:

Attendance device removes/deactivates recognition locally.

---

# 52. PRIVACY

Implement:

* Consent during face enrollment
* Privacy policy screen
* Biometric data purpose disclosure
* Employee deletion/deactivation
* Data retention settings
* Secure storage
* Encryption where appropriate
* Role-based access
* Audit logging

Do not expose face representations through client-side queries unnecessarily.

Do not expose all employees to every authenticated user.

---

# 53. SECURITY RULES

Firestore rules must enforce:

Admin can access only their business.

Attendance device can access only its assigned business/device permissions.

Employee records cannot be accessed across businesses.

Salary information must have stricter permissions than general attendance.

Audit logs should be append-only where possible.

Do not use:

allow read, write: if true;

Do not put Firebase Admin credentials inside Flutter.

---

# 54. FIREBASE STORAGE SECURITY

Structure:

businesses/{businessId}/employees/{employeeId}/profile.jpg

businesses/{businessId}/announcements/{announcementId}/voice.m4a

Storage rules must verify:

authenticated user
business membership
correct resource ownership

Temporary announcement files should have retention/deletion logic.

---

# 55. FIREBASE CLOUD FUNCTIONS

Use Cloud Functions only where they genuinely help.

Possible functions:

* attendance validation
* salary aggregation
* notification dispatch
* cleanup expired audio
* audit processing
* scheduled absence processing
* report generation

Do not move every operation into Cloud Functions unnecessarily.

---

# 56. ABSENT GENERATION

At the end of an attendance window, the system can determine employees who were expected but did not check in.

Example:

Shift:
10:00–10:30

At 10:31:

Employees without attendance:

Ravi
Amit

Status:

ABSENT

However, if approved leave exists:

Status:

LEAVE

If holiday:

HOLIDAY

If weekly off:

WEEK_OFF

---

# 57. AUTO CHECKOUT

Optional setting:

Enable auto checkout

Example:

Employee forgot checkout.

System can automatically close attendance at:

11:00 PM

Mark:

AUTO_CHECKOUT

Admin can see that it was not a physical checkout.

---

# 58. WORKING HOURS

Calculate:

checkOut - checkIn

Example:

10:07 AM → 7:15 PM

Total:

9h 08m

Deduct configurable break time if applicable.

Support:

fixed break
multiple breaks
unpaid break
paid break

---

# 59. OVERTIME

Admin can configure:

Normal working duration:
8 hours

Overtime after:
8 hours

Overtime rate:
₹100/hour

System calculates overtime.

Admin must be able to override calculations.

---

# 60. INDIAN BUSINESS UX

The UI must be designed specifically for India.

Use:

* ₹
* DD/MM/YYYY
* 12-hour time display by default
* Indian phone number formatting
* Indian number formatting
* Hindi + English readiness
* Simple English labels
* Large touch targets
* Clear icons
* Minimal technical language

Examples:

"Attendance"

"Salary"

"Staff"

"Shift"

"Leave"

"Announcement"

Avoid overly complicated enterprise terminology.

---

# 61. UI DESIGN

Overall style:

Modern Indian SaaS + simple business application.

Avoid:

* excessive gradients
* glassmorphism everywhere
* tiny text
* complicated dashboards
* excessive animations
* unnecessary charts

Use:

* clean cards
* rounded corners
* strong typography
* high contrast
* clear status chips
* simple navigation
* responsive layouts

---

# 62. COLOR SYSTEM

Primary:

Deep Navy / Indigo

Secondary:

Saffron / Warm Orange

Success:

Green

Warning:

Amber

Danger:

Red

Background:

Very light neutral

Do not make the entire app orange.

Use Indian visual identity subtly.

Suggested semantic colors:

Primary → #243B6B
Accent → #F59E0B
Success → #16A34A
Danger → #DC2626
Warning → #D97706

However, define colors through Flutter ThemeData rather than hardcoding colors throughout the UI.

---

# 63. ADMIN NAVIGATION

Mobile:

Bottom navigation:

Home
Attendance
Staff
Salary
More

More:

Shifts
Leave
Announcements
Reports
Devices
Settings

---

# 64. ATTENDANCE SCREEN

Top:

Today — 11 September

Summary cards:

Present
Late
Absent
Leave

Calendar/list below.

Tap employee:

Detailed attendance.

---

# 65. EMPLOYEE ADD FLOW

Step 1:

Basic information

Step 2:

Salary information

Step 3:

Shift assignment

Step 4:

Face enrollment

Step 5:

Confirmation

Do not create a huge single form.

---

# 66. SHIFT CREATION FLOW

Fields:

Shift name

Start time

Check-in start

Check-in end

Grace period

Checkout start

Checkout end

Auto checkout

Late policy

Overtime policy

Cross-midnight toggle

Weekly off

Active

---

# 67. BUSINESS SETTINGS

Settings:

Business name
Logo
Address
Timezone
Currency
Attendance rules
Late rules
Checkout rules
Salary calculation
Leave rules
Holiday rules
Device management
Notification settings
Privacy settings

---

# 68. NOTIFICATION/VOICE SETTINGS

Admin can configure:

Attendance confirmation voice:

ON/OFF

Example:

"{name}, your attendance has been marked."

Checkout confirmation:

"{name}, your checkout has been recorded."

Unknown face voice:

ON/OFF

Announcement volume:

configurable

---

# 69. ATTENDANCE CONFIRMATION

When attendance is successfully marked:

Visual:

✓ Attendance Marked

Ravi Kumar

10:08 AM

Morning Shift

Voice:

"Ravi Kumar, your attendance has been marked."

After 2–4 seconds return to camera.

Avoid repeating voice continuously if the same employee remains in front of camera.

Use a cooldown.

---

# 70. RECOGNITION COOLDOWN

Example:

Ravi recognized at:

10:05:10

For the next 30–60 seconds:

Do not repeatedly process Ravi as a new attendance event.

This prevents duplicate detection and annoying repeated announcements.

---

# 71. UNKNOWN PERSON HANDLING

If face confidence is below threshold:

Do not store unnecessary biometric information.

Do not create attendance.

Show:

"Face not recognized."

Optionally:

"Please contact your manager."

---

# 72. ADMIN ATTENDANCE CORRECTION

Admin can modify:

check-in
check-out
status
shift

Every change creates audit log.

Example:

Original:
10:42

Changed:
10:15

Reason:
"Employee arrived but face scanner failed."

---

# 73. REPORT DASHBOARD

Charts:

Attendance trend
Late trend
Absence trend
Working hours
Overtime

Keep charts simple.

Do not overload the dashboard.

---

# 74. BUSINESS SCALE

Design for:

10 employees
50 employees
100 employees
500 employees
1000+ employees

Do not download all attendance records to the device.

Use:

pagination
aggregation
date-based queries
indexes

---

# 75. FIRESTORE INDEXING

Create required composite indexes for queries such as:

businessId + date
businessId + employeeId + date
businessId + shiftId + date
businessId + status + date
businessId + createdAt

Check actual Firestore query requirements during implementation.

---

# 76. OFFLINE CONFLICT RESOLUTION

If two devices create an event:

Use deterministic event IDs / transaction logic.

Rules:

One employee + one shift + one check-in event.

Do not create duplicates due to synchronization.

Server should be authoritative when online.

---

# 77. DATA RETENTION

Admin settings should eventually allow:

Attendance retention:
12 months
24 months
Custom

Voice announcements:
7 days
30 days
Custom

Profile images:
until employee deleted

Biometric representations:
until employee deletion/deactivation according to configured policy and applicable requirements.

---

# 78. BACKUP

Important business records should not depend only on the device.

Cloud Firestore is the primary source of truth.

Local database is the offline operational cache.

Never treat the local JSON file as the primary database.

JSON can be used for:

* export
* debugging
* emergency backup

---

# 79. APP STATES

Every screen must properly handle:

Loading
Success
Empty
Error
Offline
Permission denied
Unauthorized
Session expired

Do not leave blank screens.

---

# 80. CAMERA PERMISSIONS

Handle:

Camera permission granted
Camera denied
Camera permanently denied
Camera unavailable
Another app using camera

Provide clear instructions.

---

# 81. AUDIO PERMISSIONS

Admin voice recording requires microphone permission.

Handle:

Permission denied
Recording failure
Storage failure
Upload failure

---

# 82. NETWORK STATUS

Show network state internally.

Do not make the UI annoying.

Small indicator:

Online

or

Offline — attendance will sync automatically.

---

# 83. ARCHITECTURE

Use clean architecture.

Recommended:

lib/

core/
constants/
theme/
routing/
errors/
utils/
permissions/
network/

features/

```
auth/

onboarding/

dashboard/

employees/

face_recognition/

attendance/

shifts/

salary/

leave/

announcements/

devices/

reports/

settings/

audit/
```

data/

```
local/
remote/
models/
repositories/
```

services/

```
firebase/
camera/
face/
tts/
audio/
sync/
```

Use repository pattern.

UI must NOT directly access Firestore.

---

# 84. STATE MANAGEMENT

Use one consistent Flutter state management architecture.

Prefer:

Riverpod

or another scalable solution.

Do not mix multiple state-management systems without a clear reason.

---

# 85. LOCAL DATABASE

Use:

Drift/SQLite

or

Isar

or another robust Flutter-supported local database.

Tables/collections:

employees_local
face_embeddings_local
shifts_local
attendance_events_local
sync_queue
device_config
announcements_local
settings_local

---

# 86. SYNC ENGINE

Create:

SyncManager

Responsibilities:

* detect connectivity
* queue events
* retry failed events
* exponential backoff
* upload batches
* mark synced
* download changed employee data
* download shift changes
* process announcements
* resolve conflicts

Retry states:

PENDING
SYNCING
SYNCED
FAILED

Store:

retryCount
lastError
nextRetryAt

---

# 87. SECURITY

Never:

* hardcode Firebase secrets that should be server-side
* expose service-account JSON
* trust client-only role claims
* allow unrestricted Firestore access
* store admin password locally in plain text
* upload continuous camera footage
* expose biometric records publicly

Use:

Firebase Auth
Firestore Rules
Storage Rules
App Check where appropriate
Secure local storage for tokens/configuration

---

# 88. TESTING

Create unit tests for:

Attendance window
Late calculation
Checkout window
Shift matching
Overnight shifts
Duplicate attendance
Absent generation
Salary calculation
Overtime
Leave
Holiday
Weekly off
Offline queue
Sync retry
Conflict resolution

---

# 89. IMPORTANT ATTENDANCE TEST CASES

Test:

1. Employee enters during correct window.
2. Employee enters before window.
3. Employee enters after window.
4. Employee enters during wrong shift.
5. Employee enters twice.
6. Employee checks out twice.
7. Employee forgets checkout.
8. Internet disconnected.
9. Internet reconnects.
10. Device restarts while offline.
11. Employee is deactivated.
12. Shift changes.
13. Overnight shift.
14. Two employees appear together.
15. Unknown person.
16. Low-quality face.
17. Duplicate face enrollment.
18. Device clock changed.
19. Firebase unavailable.
20. Multiple attendance devices.

---

# 90. ADMIN TEST CASES

Test:

* login
* logout
* password reset
* employee creation
* employee edit
* employee deactivate
* shift creation
* shift assignment
* attendance correction
* salary calculation
* leave approval
* announcement
* voice recording
* device pairing
* report export

---

# 91. PERFORMANCE REQUIREMENTS

Attendance device must feel real-time.

Target:

Face recognition → result within approximately 1–2 seconds on supported hardware.

Do not process every frame unnecessarily.

UI must remain responsive.

Avoid blocking the main Flutter isolate.

Move heavy processing to isolates/native implementation where appropriate.

---

# 92. DATABASE PRINCIPLES

Firestore is NOT a SQL database.

Do not design relational joins.

Denormalize carefully.

Store IDs rather than huge nested objects.

For frequently displayed information, controlled denormalization is acceptable.

Example attendance can store:

employeeId
employeeNameSnapshot
shiftId
shiftNameSnapshot

This helps historical records remain readable even if employee/shift names change later.

---

# 93. HISTORICAL DATA

If employee name changes:

Old attendance should still display the historical name.

If shift name changes:

Old attendance should retain the original shift name snapshot.

---

# 94. EMPLOYEE STATUS

Employee:

ACTIVE
INACTIVE

Only ACTIVE employees can be recognized for attendance.

---

# 95. DEVICE PAIRING SECURITY

Use one-time pairing token.

Example:

Admin:

Settings → Devices → Add Device

Generate:

8-character pairing code

Attendance device:

Enter code

Backend verifies.

Token expires quickly.

After pairing:

Device receives secure configuration.

Do not permanently use the pairing code as an authentication password.

---

# 96. ADMIN SESSION

Admin authentication:

Firebase Auth.

Use secure session persistence.

Support:

Logout
Password reset
Session expiration
Account disabled

---

# 97. ONBOARDING

First launch:

1. Create/Login Admin
2. Create Business
3. Configure business
4. Create first shift
5. Add employees
6. Enroll faces
7. Pair attendance device
8. Test attendance
9. Finish setup

Provide a setup checklist.

---

# 98. FIRST ATTENDANCE TEST

After pairing device:

Admin can run:

"Test Attendance"

Employee stands in front of camera.

System performs recognition.

But test should NOT create real attendance.

Display:

Recognition successful.

---

# 99. BUSINESS TYPES

During onboarding optionally ask:

Retail Shop
Restaurant
Office
Warehouse
Factory
Clinic
Salon
Hotel
Other

Use this only for UX defaults.

Do not hardcode different core attendance systems for each business type.

---

# 100. DEFAULT CONFIGURATION

Example default:

Business opens:
10:00 AM

Attendance:
10:00–10:30

Grace:
10 minutes

Checkout:
7:00–8:00 PM

Auto checkout:
OFF

Late attendance:
ON

But admin can change everything.

---

# 101. LANGUAGE

Initial:

English

Architecture must support:

Hindi
English
Hinglish

Later.

All visible strings must come from localization resources.

Never hardcode UI text throughout widgets.

---

# 102. ACCESSIBILITY

Support:

Large text
Readable contrast
Large buttons
Clear icons
Screen-reader labels where applicable

Attendance kiosk should use large text because employees may stand several feet away.

---

# 103. DARK MODE

Admin app:

Light mode default.

Dark mode optional.

Attendance kiosk:

Prefer high-visibility dedicated kiosk theme.

---

# 104. APP LOCK / KIOSK MODE

Attendance device should ideally stay on attendance screen.

Prevent accidental navigation.

Provide:

Admin unlock gesture/button.

Require PIN/admin authorization to exit kiosk mode.

Do not allow employees to access settings.

---

# 105. CAMERA ALWAYS AVAILABLE

Important:

"Camera always open" means the attendance app remains in camera/kiosk mode while the app is active.

Do NOT implement covert/background camera recording.

Respect Android/iOS platform privacy and camera restrictions.

Do not record or upload continuous video.

Only process the camera stream required for attendance recognition.

---

# 106. ADMIN DASHBOARD EXAMPLE

HOME

Good Morning, Admin

ABC Store

TODAY

35 Staff
29 Present
2 Late
3 Absent
1 Leave

Quick Actions

* Employee
  Attendance
  Salary
  Announcement

Today's Activity

10:04
Ravi — Checked In

10:06
Amit — Checked In

10:15
Suresh — Late

---

# 107. EMPLOYEE DETAIL EXAMPLE

RAVI KUMAR

Employee ID:
EMP001

Shift:
Morning

Salary:
₹18,000/month

TODAY

Check-in:
10:07 AM

Check-out:
7:14 PM

Working:
9h 07m

MONTH

Present: 24
Absent: 1
Late: 3
Leave: 2
Overtime: 5h 20m

---

# 108. PRODUCT DIFFERENTIATION

The application should not feel like a generic attendance app.

Its USP should be:

"One small device at the entrance + one admin phone = complete staff management."

Features:

Face Attendance
Offline Attendance
Shift Control
Salary
Leave
Announcements
Voice Communication
Attendance Analytics
Device Management

This combination should be the product identity.

---

# 109. FUTURE FEATURES — DESIGN FOR EXTENSIBILITY

Architecture should allow future modules:

* Employee advances
* Loan tracking
* Incentives
* Commission
* Sales targets
* Performance
* Expense management
* Stock-related staff actions
* Task assignment
* Staff documents
* ID cards
* QR fallback attendance
* PIN fallback
* Geofencing for mobile attendance
* Multi-branch management
* Franchise management
* WhatsApp integrations
* Payroll export
* GST/business integrations
* Employee self-service app

Do NOT implement all future features now.

Only keep architecture extensible.

---

# 110. FALLBACK ATTENDANCE

Face recognition may fail.

Admin should be able to configure fallback:

QR
Employee ID
PIN
Manual Admin Entry

However, fallback must still obey shift and attendance windows.

---

# 111. FACE RECOGNITION FALLBACK

If employee face recognition confidence is borderline:

Do NOT automatically mark.

Show:

"Please look directly at the camera."

Retry.

After several failed attempts:

"Please use alternate attendance method."

---

# 112. ADMIN ANALYTICS

Business dashboard can eventually show:

Attendance percentage
Average lateness
Average working hours
Overtime
Absenteeism
Shift utilization

Keep analytics actionable.

Example:

"4 employees have not checked out."

"3 employees were late today."

---

# 113. ERROR HANDLING

Never show raw Firebase exceptions.

Instead:

Firebase unavailable →
"Cloud service temporarily unavailable. Your attendance is safely stored on this device."

Permission issue →
"Camera permission is required for attendance."

Sync issue →
"4 attendance records are waiting to sync."

---

# 114. DEVELOPMENT RULES FOR ANTIGRAVITY

You are building a production application.

Before coding:

1. Analyze the complete architecture.
2. Create implementation plan.
3. Create folder structure.
4. Define models.
5. Define repositories.
6. Define local database.
7. Define Firebase schema.
8. Define security rules.
9. Define navigation.
10. Define theme.
11. Define offline synchronization.
12. Then implement feature by feature.

Do NOT create a giant single-file Flutter application.

Do NOT put all logic inside widgets.

Do NOT use fake repositories once real Firebase implementation starts.

---

# 115. IMPLEMENTATION ORDER

PHASE 1

Project foundation

* Flutter
* routing
* theme
* localization
* state management
* error handling

PHASE 2

Firebase

* Auth
* Firestore
* Storage
* security rules

PHASE 3

Business/admin authentication

PHASE 4

Employee management

PHASE 5

Shift engine

PHASE 6

Camera + face enrollment

PHASE 7

Attendance engine

PHASE 8

Offline database

PHASE 9

Sync engine

PHASE 10

Attendance calendar

PHASE 11

Salary

PHASE 12

Leave + holiday

PHASE 13

Announcements

PHASE 14

TTS + voice recording

PHASE 15

Device pairing

PHASE 16

Reports

PHASE 17

Audit/security hardening

PHASE 18

Testing/performance optimization

---

# 116. DEFINITION OF DONE

The application is NOT considered complete when the UI works.

It is complete only when:

* Firebase works
* Authentication works
* Security rules work
* Employee management works
* Face enrollment works
* Face recognition works
* Shift validation works
* Attendance windows work
* Checkout windows work
* Overnight shifts work
* Offline attendance works
* Sync works
* Duplicate protection works
* Calendar works
* Salary works
* Leave works
* Announcements work
* Voice works
* Device pairing works
* Audit logs work
* Error handling works
* App survives restart
* App works without internet
* App synchronizes after internet returns
* Tests pass
* Production build succeeds

---

# 117. CRITICAL DEVELOPMENT RULE

Never destroy working functionality while implementing another feature.

Before modifying existing code:

* inspect it
* understand dependencies
* preserve public interfaces where possible
* run tests
* implement change
* run tests again

If a refactor is required, document why.

---

# 118. NO FAKE FUNCTIONALITY

Do not implement fake:

* face recognition
* Firebase synchronization
* salary calculation
* offline synchronization
* device pairing
* announcements

Temporary mock data may be used during UI development, but production paths must use the real implementations.

Mark all temporary mocks clearly.

---

# 119. SECURITY-FIRST REQUIREMENT

Before production release, review:

* Firestore rules
* Storage rules
* Auth
* device authorization
* biometric data handling
* local storage
* admin authorization
* tenant isolation
* audit logs
* API keys/configuration
* debug logging
* release build configuration

Do not release with development Firebase rules.

---

# 120. FINAL PRODUCT EXPERIENCE

ADMIN:

Open app.

Dashboard immediately shows:

"Today"

Present
Absent
Late
Leave
Not Checked Out

Admin can add employee in under a few minutes.

Admin assigns shift.

Admin enrolls face.

Attendance device automatically receives employee information.

EMPLOYEE:

Walks in.

Looks at camera.

System recognizes employee.

Validates shift.

Validates attendance window.

Marks attendance.

Voice:

"{name}, your attendance has been marked."

Admin immediately sees the attendance.

If internet is unavailable:

Attendance still works.

When internet returns:

Records automatically synchronize.

At month end:

Admin opens Salary.

System calculates attendance-based information.

Admin reviews salary.

Admin records payment.

This should feel like a complete workforce operating system rather than a simple attendance application.
"""

---

# 121. ANTIGRAVITY EXECUTION INSTRUCTION

Start by creating a technical implementation plan based on this specification.

Do NOT immediately generate all features in one pass.

First:

1. Inspect the project.
2. Determine whether this is a new project or existing project.
3. Preserve existing functionality if an existing project exists.
4. Create architecture.
5. Create Firebase configuration strategy.
6. Create data models.
7. Create local database schema.
8. Create repository interfaces.
9. Create sync architecture.
10. Create authentication.
11. Implement feature modules incrementally.

After every major phase:

* run flutter analyze
* run tests
* run build
* fix errors
* verify no regression

When implementing Firebase:

* create production-quality Firestore rules
* create Storage rules
* document indexes
* never use unrestricted read/write rules

When implementing face recognition:

* choose a Flutter/mobile-compatible on-device approach
* do not upload continuous camera frames
* do not depend on internet for recognition
* implement confidence threshold
* implement duplicate protection
* implement liveness/anti-spoofing where supported
* keep biometric data handling minimal and secure

When implementing offline support:

* local database is operational cache
* Firestore is cloud source of truth
* sync queue must survive application restart
* sync must be idempotent
* failed uploads must retry
* no attendance event should disappear

When implementing UI:

* follow the Indian business-oriented design system above
* keep screens simple
* make important actions obvious
* use ₹ and Indian date/time conventions
* support future Hindi localization
* make kiosk UI large and readable

Never sacrifice correctness for visual polish.

First build the foundation correctly, then build the features.
"""

---

# 122. IMPORTANT PRODUCT DECISION

Do not make Firebase responsible for real-time face recognition.

Recommended architecture:

```
             ┌──────────────────────┐
             │     ADMIN PHONE      │
             │                      │
             │ Employees            │
             │ Shifts               │
             │ Attendance           │
             │ Salary               │
             │ Leave                │
             │ Announcements        │
             └──────────┬───────────┘
                        │
                     Firebase
                        │
             ┌──────────▼───────────┐
             │      CLOUD           │
             │                      │
             │ Auth                 │
             │ Firestore            │
             │ Storage              │
             │ FCM                  │
             └──────────┬───────────┘
                        │
                Internet / Sync
                        │
             ┌──────────▼───────────┐
             │  ATTENDANCE DEVICE  │
             │                      │
             │ Camera               │
             │ Face Detection       │
             │ Face Recognition     │
             │ Shift Validation     │
             │ Attendance Engine    │
             │ Local Database       │
             │ Sync Queue           │
             │ TTS / Voice          │
             └──────────────────────┘
```

The attendance device must remain useful even when the cloud is temporarily unavailable.
"""

---

# 123. FINAL QUALITY STANDARD

The final application should feel like a polished commercial Indian SaaS product.

It must be:

Fast
Reliable
Offline-first
Secure
Simple
Scalable
Mobile-first
Indian-market-friendly

The core promise:

"Staff aaye, camera dekhe, attendance ho jaye — aur admin apne phone se poora staff, shift, attendance aur salary manage kare."

Build the system around this principle.
