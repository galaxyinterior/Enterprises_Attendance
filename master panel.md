# MASTER PANEL + SHOP REGISTRATION + ADMIN/KIOSK PROVISIONING SYSTEM

## 1. OBJECTIVE

Add a centralized MASTER PANEL to the existing Staff Management & Smart Attendance ecosystem.

There will be three logical access levels:

1. MASTER / SUPER ADMIN
2. SHOP ADMIN
3. KIOSK DEVICE

The MASTER PANEL belongs to the product owner/operator.

The SHOP ADMIN belongs to an individual business/shop.

The KIOSK account is used only by the dedicated attendance device.

The master panel must have complete control over shop onboarding, approval, activation, suspension, credentials, devices and operational status.

Do not redesign or break the existing employee, attendance, shift, salary, offline and announcement modules.

This specification extends the existing architecture.

---

# 2. HIGH-LEVEL ARCHITECTURE

```
                ┌─────────────────────────┐
                │       MASTER PANEL      │
                │                         │
                │ Product Owner / Admin   │
                │                         │
                │ Applications            │
                │ Shops                   │
                │ Admin Accounts          │
                │ Kiosk Accounts          │
                │ Devices                 │
                │ Pause / Resume          │
                │ Audit Logs              │
                │ System Settings         │
                └────────────┬────────────┘
                             │
                             │ Firebase / Backend
                             │
          ┌──────────────────┴──────────────────┐
          │                                     │
  ┌───────▼────────┐                    ┌───────▼────────┐
  │   ADMIN APP    │                    │  KIOSK DEVICE  │
  │                │                    │                │
  │ shopID@admin.in│                    │shopID@kiosk.in │
  │                │                    │                │
  │ Staff          │                    │ Camera         │
  │ Attendance     │                    │ Recognition    │
  │ Salary         │                    │ Check-in       │
  │ Shifts         │                    │ Checkout       │
  │ Leave          │                    │ Voice          │
  │ Reports        │                    │ Offline        │
  └────────────────┘                    └────────────────┘
```

MASTER PANEL IS ABOVE INDIVIDUAL SHOP ADMINISTRATORS.

---

# 3. THREE ACCESS LEVELS

## LEVEL 1 — MASTER

Product owner.

Example:

MASTER

Can:

* view all shops
* approve registrations
* reject registrations
* pause shops
* resume shops
* view shop status
* manage admin credentials
* manage kiosk credentials
* view kiosk status
* unlink devices
* view system health
* view audit logs
* manage global configuration
* view registration requests
* receive email notifications
* send system notices
* deactivate accounts

MASTER must NOT be a normal shop user.

---

# 4. LEVEL 2 — SHOP ADMIN

Credential format:

[shopID@admin.in](mailto:shopID@admin.in)

Example:

[ABC001@admin.in](mailto:ABC001@admin.in)

Shop admin can access only its own shop.

Admin can:

* manage employees
* enroll employee faces
* manage shifts
* view attendance
* manage salary
* manage leave
* manage announcements
* manage kiosk pairing
* view reports
* configure attendance rules

Admin must never access:

* other shops
* master panel
* other shop credentials
* global system settings
* master audit logs

---

# 5. LEVEL 3 — KIOSK

Credential format:

[shopID@kiosk.in](mailto:shopID@kiosk.in)

Example:

[ABC001@kiosk.in](mailto:ABC001@kiosk.in)

Kiosk account is restricted.

After successful login:

OPEN KIOSK MODE.

Kiosk can:

* access camera
* recognize employees
* mark attendance
* mark checkout
* receive announcements
* perform offline synchronization
* show device status

Kiosk cannot:

* manage employees
* access salary
* access attendance reports
* access admin settings
* view employee salary
* change shifts
* change business settings

---

# 6. LOGIN ROUTING

Use one login screen in the same Flutter application.

User enters:

Email/ID
Password

System authenticates through Firebase Authentication.

After authentication, determine account role.

If email ends with:

@admin.in

→ ADMIN APPLICATION EXPERIENCE

If email ends with:

@kiosk.in

→ KIOSK EXPERIENCE

MASTER account:

→ MASTER PANEL

Do NOT rely only on email suffix for authorization.

Email suffix is only for routing/UI.

Actual authorization must come from secure server-side role/business association.

---

# 7. MASTER PANEL TYPE

Master Panel should preferably be a separate protected web dashboard.

Recommended:

Flutter Web

or

another secure web admin interface.

It must not be exposed as an ordinary user feature.

Recommended URL structure:

master.yourdomain.com

Do not hardcode the real production domain until deployment.

---

# 8. SHOP REGISTRATION FLOW

A new shop owner opens:

Registration

Form fields:

Business Owner Name
Shop/Business Name
Shop Location
Address
City
State
PIN Code
Business Type
Email
Phone Number
Number of Employees
Expected Number of Kiosks
Preferred Plan if applicable
Additional Notes
Terms/Consent

Optional:

GSTIN
Business Registration Number
Website
Alternate Phone

Do not force unnecessary information.

---

# 9. REGISTRATION SUBMISSION

When user presses:

SUBMIT APPLICATION

The system should:

1. Validate form.
2. Sanitize input.
3. Validate email.
4. Validate phone.
5. Create registration request.
6. Store registration in Firestore.
7. Generate unique application ID.
8. Set status:
   PENDING
9. Send notification to MASTER.
10. Show confirmation to applicant.

Applicant should see:

"Application submitted successfully."

Application ID:

APP-XXXXXXXX

Do NOT create active admin/kiosk credentials yet.

---

# 10. REGISTRATION STATUS

Registration status values:

PENDING
UNDER_REVIEW
APPROVED
REJECTED
CANCELLED

Optional:

WAITING_FOR_INFORMATION

Master can change status.

Every status change must be audited.

---

# 11. REGISTRATION DATABASE

Suggested:

registrationRequests/{applicationId}

Fields:

applicationId
ownerName
shopName
businessType
email
phone
address
city
state
pincode
employeeCount
kioskCount
notes
status
submittedAt
reviewedAt
reviewedBy
rejectionReason
createdAt
updatedAt

Never store passwords in this document.

---

# 12. MASTER PANEL — REGISTRATION SCREEN

Master dashboard:

REGISTRATION REQUESTS

Cards/table:

Application ID
Shop Name
Owner
Phone
Email
Location
Submitted
Status

Filters:

Pending
Under Review
Approved
Rejected

Search:

Shop name
Owner
Email
Phone
Application ID

---

# 13. APPLICATION DETAIL

Master opens application.

Show:

Business information
Owner information
Contact details
Location
Employee count
Kiosk count
Submission date

Actions:

APPROVE

REJECT

REQUEST INFORMATION

Do not permanently delete applications by default.

---

# 14. APPROVAL FLOW

When MASTER presses:

APPROVE

Show confirmation dialog:

"Approve this business and create its access accounts?"

Then backend performs the provisioning process.

Generate:

businessId
shopId
admin account
kiosk account

Example:

SHOP ID:

ABC001

Admin:

[ABC001@admin.in](mailto:ABC001@admin.in)

Kiosk:

[ABC001@kiosk.in](mailto:ABC001@kiosk.in)

---

# 15. SHOP ID GENERATION

Shop ID must be:

* unique
* stable
* immutable
* easy to communicate
* safe to use in account identifiers

Recommended:

ABC001
SHOP001
DUM001

Do not generate shop ID purely from shop name.

Example:

"Akash General Store"

should NOT automatically become:

AKASHGENERALSTORE

because duplicate names are possible.

Use a unique generated ID.

---

# 16. ACCOUNT PROVISIONING

When application is approved:

Create Firebase Authentication account for:

[SHOP_ID@admin.in](mailto:SHOP_ID@admin.in)

Create Firebase Authentication account for:

[SHOP_ID@kiosk.in](mailto:SHOP_ID@kiosk.in)

Assign roles securely.

Example:

Admin custom claims:

role = SHOP_ADMIN
businessId = ABC001

Kiosk:

role = KIOSK
businessId = ABC001

Master:

role = MASTER

IMPORTANT:

Do not allow clients to assign themselves these roles.

Roles must be assigned only through trusted backend/admin operations.

---

# 17. PASSWORD GENERATION

Master should be able to:

A. Generate secure temporary passwords automatically.

or

B. Set initial passwords.

Recommended:

Generate secure temporary passwords.

Passwords must never be stored in plaintext in Firestore.

Firebase Authentication should store/manage password credentials.

Master panel should only display credentials during secure provisioning where absolutely necessary.

---

# 18. CREDENTIAL DELIVERY

After approval, the owner should receive:

Shop ID
Admin Login ID
Initial Password
Kiosk Login ID
Initial Password
Basic instructions

Do not send passwords through ordinary email unless there is a deliberate security design.

Prefer:

* secure credential setup link
* temporary password
* forced password change on first login

If email delivery is used, clearly label it as temporary credentials.

---

# 19. FIRST LOGIN

Admin first login:

[ABC001@admin.in](mailto:ABC001@admin.in)
Temporary password

System:

→ authentication successful
→ force password change
→ admin sets new password
→ continue to dashboard

Kiosk first login:

[ABC001@kiosk.in](mailto:ABC001@kiosk.in)
Temporary password

After successful setup:

→ enter kiosk mode
→ restrict navigation

---

# 20. KIOSK LOGOUT SECURITY

Kiosk should not have a normal easily accessible logout button.

The kiosk remains logged in.

To exit kiosk mode:

Admin/authorized operator must initiate:

EXIT KIOSK

Then require:

Kiosk ID
AND
Kiosk password

or a more secure admin authorization mechanism.

Important:

Do NOT rely on checking a password inside Flutter code.

Firebase Authentication must verify the credential.

After successful verification:

Allow logout / exit kiosk.

Otherwise:

remain in kiosk mode.

---

# 21. KIOSK LOCK SCREEN

When kiosk starts:

---

ABC GENERAL STORE

Attendance System

[ LIVE CAMERA ]

Please look at the camera

---

There should be no obvious navigation to admin features.

---

# 22. KIOSK PAUSE / RESUME

MASTER PANEL must contain:

SHOP STATUS

ACTIVE
PAUSED

When MASTER pauses a shop:

All associated access should respond appropriately.

At minimum:

* Admin cannot perform normal shop operations.
* Kiosk cannot mark new attendance.
* New synchronization should be restricted according to policy.
* Device should display:
  "This service has been temporarily paused."

Existing locally stored attendance must NOT be silently deleted.

Offline data should remain protected locally and synchronize according to the configured suspension policy when service resumes.

---

# 23. PAUSE FLOW

Master:

Shops
→ Select Shop
→ Pause

Show:

Pause Business

Reason:
[________________]

Confirm:

PAUSE SHOP

Reason must be stored in audit log.

---

# 24. RESUME FLOW

Master:

Paused Shop
→ Resume

Confirm:

"Resume ABC001?"

YES

Backend changes:

status = ACTIVE

Devices synchronize.

Kiosk returns to normal operation.

---

# 25. SHOP STATUS MODEL

Possible status:

PENDING
ACTIVE
PAUSED
SUSPENDED
DEACTIVATED

Do not confuse:

registration status

with

business operational status.

Registration:

PENDING
APPROVED
REJECTED

Business:

ACTIVE
PAUSED
SUSPENDED
DEACTIVATED

---

# 26. SHOP DATABASE

Suggested:

businesses/{businessId}

Fields:

businessId
shopId
shopName
ownerName
email
phone
address
city
state
pincode
businessType
status
createdAt
approvedAt
approvedBy
pausedAt
pausedBy
pauseReason
updatedAt

---

# 27. MASTER SHOP LIST

Master Panel:

ALL SHOPS

Columns:

Shop ID
Shop Name
Owner
Phone
City
Status
Employees
Kiosks
Created
Last Activity

Actions:

View
Pause
Resume
Manage
Devices
Audit

---

# 28. MASTER SHOP DETAIL

Display:

SHOP INFORMATION

Shop ID
Shop name
Owner
Email
Phone
Location
Created date
Approval date
Current status

USAGE:

Employees
Attendance records
Active kiosks
Last kiosk activity
Last synchronization

CONTROLS:

Pause
Resume
Manage Devices
View Admin
View Audit

Do not display admin passwords in normal shop detail.

---

# 29. MASTER DEVICE MANAGEMENT

Master must be able to view every kiosk.

Device fields:

deviceId
businessId
deviceName
deviceModel
platform
appVersion
lastSeen
lastSync
onlineStatus
cameraStatus
batteryStatus if available
createdAt
status

Statuses:

ONLINE
OFFLINE
DISABLED
UNPAIRED

---

# 30. MASTER KIOSK CONTROLS

Master can:

* view device
* disable device
* enable device
* revoke device
* force re-pair
* view last seen
* view sync status
* view app version
* view errors

Do not allow Master to remotely access the camera.

Master should NOT receive continuous camera footage.

---

# 31. MASTER ADMIN ACCOUNT MANAGEMENT

Master can view:

Admin account status

ACTIVE
DISABLED

Actions:

Disable Admin
Enable Admin
Force Password Reset
Revoke Sessions

Master should not normally see the current admin password.

---

# 32. ACCOUNT DEACTIVATION

If business is permanently deactivated:

Admin access:
DISABLED

Kiosk:
DISABLED

Historical data:
RETAINED according to retention policy

Do NOT delete historical attendance and salary data automatically.

---

# 33. MASTER DASHBOARD

Top metrics:

Total Shops
Active Shops
Paused Shops
Pending Applications
Active Kiosks
Offline Kiosks

Example:

SHOPS
126

ACTIVE
119

PAUSED
7

PENDING
14

KIOSKS
121

OFFLINE
4

---

# 34. MASTER DASHBOARD ALERTS

Show:

New registration received

Kiosk offline

Shop paused

Synchronization failure

Device error

App version outdated

Repeated authentication failures

---

# 35. EMAIL NOTIFICATION SYSTEM

When a new registration is submitted:

Send email to MASTER.

Example subject:

New Shop Registration — APP-ABC123

Email should contain:

Application ID
Owner
Shop
Phone
Email
Location
Employee count
Submission time

Do NOT include passwords.

---

# 36. EMAIL AFTER APPROVAL

Optional:

Send applicant:

"Your business registration has been approved."

Include:

Application ID
Shop ID
Next steps

Credentials should preferably be delivered using a secure setup flow.

---

# 37. EMAIL TECHNOLOGY

The user specifically wants Gmail + App Password.

Implement email sending on the SERVER/BACKEND only.

Recommended configuration:

SMTP_HOST
SMTP_PORT
SMTP_USER
SMTP_APP_PASSWORD
MASTER_NOTIFICATION_EMAIL

Example environment variables:

SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=[your-business-email@gmail.com](mailto:your-business-email@gmail.com)
SMTP_APP_PASSWORD=your-generated-app-password
MASTER_NOTIFICATION_EMAIL=[your-master-email@gmail.com](mailto:your-master-email@gmail.com)

IMPORTANT:

These environment variables must NEVER be bundled into the Flutter APK.

Never place:

SMTP_APP_PASSWORD

inside:

lib/
assets/
.env shipped with Flutter
Firebase client configuration
public web assets

---

# 38. EMAIL ENVIRONMENT CONFIGURATION

For development:

.env.local

For production:

secure server environment / deployment secret manager.

The Flutter client must never receive the Gmail App Password.

Only backend/server-side email service can access it.

---

# 39. EMAIL SERVICE ARCHITECTURE

Registration:

Flutter
↓
Backend API / trusted backend function
↓
Create registration record
↓
Email service
↓
Gmail SMTP
↓
Master email

Do NOT allow Flutter to directly connect to Gmail SMTP with the master password.

---

# 40. EMAIL FAILURE

If email fails:

Registration must NOT disappear.

Firestore registration remains:

PENDING

Email status:

FAILED

Backend can retry.

Fields:

emailNotificationStatus
emailRetryCount
lastEmailError
lastEmailAttemptAt

Admin/master should see:

"Registration saved, email notification pending."

---

# 41. MASTER EMAIL CONFIGURATION

Master panel system settings may contain:

Notification email

SMTP sender email

But the SMTP App Password should only exist in secure backend environment configuration.

The UI can show:

Email Service:
Configured ✓

but never show the actual App Password.

---

# 42. EMAIL TEMPLATES

Create reusable templates:

New Registration
Registration Approved
Registration Rejected
Shop Paused
Shop Resumed
Kiosk Offline
Security Alert

Templates should be server-side.

---

# 43. REGISTRATION EMAIL

Subject:

New Shop Registration Received

Body:

A new business has submitted an application.

Application:
APP-XXXX

Business:
ABC General Store

Owner:
XXXX

Phone:
XXXX

Email:
XXXX

Location:
XXXX

Please review the application from Master Panel.

---

# 44. AUDIT LOG

Master operations must be audited.

Examples:

REGISTRATION_CREATED
REGISTRATION_APPROVED
REGISTRATION_REJECTED
SHOP_PAUSED
SHOP_RESUMED
ADMIN_DISABLED
ADMIN_ENABLED
KIOSK_DISABLED
KIOSK_ENABLED
KIOSK_REVOKED
PASSWORD_RESET_REQUESTED
DEVICE_PAIRED
DEVICE_UNPAIRED

Fields:

auditId
actorUid
actorRole
businessId
targetId
action
reason
timestamp
metadata

---

# 45. MASTER SECURITY

Master panel is the highest privilege area.

Implement:

* strong authentication
* MFA where possible
* secure session
* role verification
* audit logs
* rate limiting
* suspicious login detection
* session revocation
* protected routes

Never trust:

role supplied by Flutter client.

---

# 46. MASTER FIRESTORE ACCESS

Do not give MASTER broad client-side unrestricted Firestore access if it can be avoided.

Prefer privileged backend operations for sensitive actions such as:

* creating Firebase Auth users
* assigning custom claims
* pausing businesses
* provisioning accounts
* disabling accounts

Use Firebase Admin SDK in trusted backend environment.

---

# 47. IMPORTANT FIREBASE ADMIN SDK RULE

Firebase Admin SDK/service-account credentials must NEVER be included in:

Flutter
Android APK
iOS app
public JavaScript
Git repository

Store them only in secure server-side environment.

---

# 48. MULTI-TENANT SECURITY

Every shop is a separate tenant.

Example:

Business A:

ABC001

Business B:

XYZ002

ABC001 admin must never read:

XYZ002 employees
XYZ002 salary
XYZ002 attendance
XYZ002 devices

Firestore security rules must enforce this.

---

# 49. KIOSK AUTHORIZATION

Kiosk must have:

role = KIOSK

businessId = ABC001

deviceId = DEVICE123

The backend must validate:

authenticated user
+
role
+
business
+
device registration
+
device active status

Do not rely solely on:

email.endsWith("@kiosk.in")

---

# 50. KIOSK DEVICE BINDING

A kiosk account should preferably be bound to a physical device.

After first login:

device generates secure installation/device identifier.

Backend associates:

kioskUid
businessId
deviceId

If credentials are copied to another device:

system should require device authorization/re-pairing.

---

# 51. DEVICE REPLACEMENT

If phone breaks:

Master/Admin:

Devices
→ Replace Device
→ Revoke old device
→ Generate pairing code
→ New phone login/pair
→ Sync employee recognition data
→ Resume kiosk

Old device must lose authorization.

---

# 52. SHOP PAUSED WHILE KIOSK IS OFFLINE

Important edge case.

If kiosk has no internet and shop is paused remotely:

The kiosk cannot know immediately.

Therefore:

* previously synced state may remain active temporarily
* once connectivity returns, kiosk retrieves authoritative status
* backend should reject new cloud attendance after pause
* local records should remain queued and protected
* define explicit policy for offline events generated during suspension

For commercial deployment, document this behavior clearly.

---

# 53. SHOP RESUME WHILE KIOSK IS OFFLINE

When kiosk reconnects:

1. Download current shop status.
2. Download updated configuration.
3. Synchronize pending data.
4. Refresh employee data.
5. Refresh shifts.
6. Process announcements.
7. Return to active kiosk state.

---

# 54. MASTER GLOBAL SEARCH

Master should be able to search:

Shop ID
Shop name
Owner
Phone
Email
Device ID
Application ID

---

# 55. MASTER FILTERS

Filter by:

Status
City
State
Business type
Registration date
Number of employees
Number of kiosks
Online/offline

---

# 56. MASTER NOTIFICATION CENTER

Master panel should show:

New registrations
Kiosk offline
System errors
Email failures
Security events

Unread count.

---

# 57. MASTER SYSTEM HEALTH

Dashboard:

Firebase:
CONNECTED

Email:
CONNECTED

Firestore:
HEALTHY

Storage:
HEALTHY

Kiosk devices:
121 active

Offline:
4

Email queue:
0 pending

---

# 58. SYSTEM CONFIGURATION

Master-level settings can eventually include:

Default attendance rules
Default retention
Maximum employee limit
Maximum kiosk limit
Maintenance mode
Supported app versions
Announcement defaults

Do NOT allow master global configuration to accidentally overwrite existing business-specific settings.

Use:

GLOBAL DEFAULT

and

BUSINESS OVERRIDE

architecture.

---

# 59. APP VERSION CONTROL

Master should eventually see:

Kiosk app version

Example:

v1.2.4

If old:

"Update Required"

Master can configure minimum supported version.

Example:

minimumKioskVersion = 1.2.0

If kiosk version < minimum:

restrict functionality according to policy.

---

# 60. MAINTENANCE MODE

Master can enable:

SYSTEM MAINTENANCE

Then apps show:

"Service temporarily under maintenance."

However, offline attendance behavior must be explicitly defined.

Do not blindly disable local attendance if the business requires offline operation.

---

# 61. MASTER PANEL NAVIGATION

Recommended:

Dashboard

Registrations

Shops

Devices

Accounts

Notifications

Audit Logs

System Health

Settings

---

# 62. SHOP ADMIN NAVIGATION

Separate from Master:

Dashboard

Attendance

Staff

Salary

Shifts

Leave

Announcements

Reports

Devices

Settings

---

# 63. KIOSK NAVIGATION

Kiosk should effectively have one main screen:

LIVE ATTENDANCE CAMERA

Optional hidden/admin-accessible:

Device Status
Sync Status
Exit Kiosk

---

# 64. ROLE ROUTING ARCHITECTURE

After login:

authenticate()

↓

fetch secure user profile/claims

↓

switch(role)

MASTER
→ MasterPanel

SHOP_ADMIN
→ AdminDashboard

KIOSK
→ KioskScreen

UNKNOWN
→ AccessDenied

Never:

if email.contains("@admin.in")
then grant admin permissions.

Email pattern only determines intended identity format.

---

# 65. PASSWORD RESET

Admin password reset:

Master can trigger reset.

Kiosk password reset:

Master can trigger reset.

Password reset should use secure Firebase mechanisms.

Never display existing password.

---

# 66. MASTER FORCE LOGOUT

Master can revoke a user's sessions.

Useful if:

* device stolen
* password compromised
* employee/admin leaves
* kiosk credentials copied

Backend should invalidate/revoke access where supported.

---

# 67. SHOP ADMIN CANNOT CONTROL SHOP STATUS

Shop Admin should NOT have:

Pause Shop
Resume Shop
Delete Business
Change business ownership
Change master settings

Only MASTER can perform these operations.

---

# 68. OWNERSHIP TRANSFER

Future-ready architecture:

Master can change business owner/admin.

Old admin:

disabled

New admin:

created

Historical data remains linked to business.

---

# 69. REGISTRATION DUPLICATE DETECTION

Before accepting:

Check possible duplicate:

same email
same phone
same shop name + location

Do not automatically reject solely based on shop name.

Flag:

"Possible duplicate application."

Master decides.

---

# 70. REGISTRATION RATE LIMIT

Protect registration endpoint against spam.

Implement:

* rate limiting
* CAPTCHA/abuse protection where appropriate
* email verification if required
* phone validation
* duplicate request detection

---

# 71. FORM VALIDATION

Required:

Owner name
Shop name
Phone
Email
Location
City
State

Validate:

Indian phone number format

Email syntax

PIN code

Do not trust client-side validation alone.

Validate again on backend.

---

# 72. REGISTRATION DATA PRIVACY

Registration contains personal/business information.

Therefore:

* secure Firestore rules
* restricted master access
* audit access
* minimal data collection
* retention policy
* deletion policy

Do not expose registration data publicly.

---

# 73. MASTER PANEL UI

Design:

Professional SaaS control center.

Use:

Sidebar navigation
Top search
Notification icon
Profile menu
Status badges
Data tables
Confirmation dialogs
Charts only where useful

Colors:

Primary:
Deep Navy / Indigo

Accent:
Saffron / Orange

Success:
Green

Warning:
Amber

Danger:
Red

Keep the Master Panel visually distinct from the shop admin panel while retaining the same design system.

---

# 74. MASTER DASHBOARD SAMPLE

MASTER CONTROL CENTER

Good Afternoon

System Overview

126
TOTAL SHOPS

119
ACTIVE

7
PAUSED

14
PENDING APPLICATIONS

121
KIOSKS

4
OFFLINE

---

Recent Applications

ABC General Store
PENDING

XYZ Fashion
PENDING

RK Restaurant
UNDER REVIEW

---

System Health

Firebase       ✓ Healthy
Email          ✓ Connected
Storage        ✓ Healthy

---

# 75. SHOP DETAIL SAMPLE

ABC001

ABC General Store

ACTIVE

Owner:
Rahul Kumar

Location:
Deoghar, Jharkhand

Employees:
34

Kiosks:
1

Last Kiosk Seen:
2 minutes ago

Actions:

[PAUSE SHOP]

[MANAGE DEVICES]

[VIEW AUDIT]

---

# 76. APPROVAL CONFIRMATION

When approving:

"Approve ABC General Store?"

This will create:

Shop ID:
ABC001

Admin Account:
[ABC001@admin.in](mailto:ABC001@admin.in)

Kiosk Account:
[ABC001@kiosk.in](mailto:ABC001@kiosk.in)

Continue?

[Cancel] [Approve & Provision]

---

# 77. PROVISIONING TRANSACTION

Account creation must be designed to handle partial failures.

Possible:

Business created ✓
Admin created ✓
Kiosk creation failed ✗

System must NOT report:

"Provisioning complete."

Instead:

Provisioning status:

PARTIAL_FAILURE

Allow retry.

Do not create duplicate accounts on retry.

---

# 78. PROVISIONING STATUS

Possible:

NOT_STARTED
IN_PROGRESS
COMPLETED
PARTIAL_FAILURE
FAILED

Store:

provisioningStatus
provisioningAttempt
lastProvisioningError
lastProvisioningAt

---

# 79. EMAIL QUEUE

Do not make user wait indefinitely for SMTP.

Use:

registration created
→ email job queued
→ backend sends email
→ status updated

This provides reliability.

---

# 80. MASTER AUDIT REQUIREMENT

Every master action must record:

WHO

WHAT

WHEN

WHICH BUSINESS

WHY

Example:

MASTER:
masterUid123

ACTION:
PAUSE_SHOP

BUSINESS:
ABC001

REASON:
Subscription expired

TIME:
2026-09-11 14:10 IST

---

# 81. SUBSCRIPTION-READY ARCHITECTURE

Even if subscription/payment is NOT implemented now, design business status so future plans can be added.

Possible:

planId
subscriptionStatus
subscriptionStart
subscriptionEnd
trialStart
trialEnd

Future:

FREE
TRIAL
BASIC
PRO
ENTERPRISE

Do NOT implement payment gateway unless specifically requested.

---

# 82. IMPORTANT ACCOUNT FORMAT RULE

The requested formats are:

[SHOPID@admin.in](mailto:SHOPID@admin.in)

[SHOPID@kiosk.in](mailto:SHOPID@kiosk.in)

These should be treated as application login identifiers.

However, if the product later needs actual email delivery to the shop owner's real email, keep:

ownerEmail

separate from:

adminLoginId

Do not assume:

[SHOPID@admin.in](mailto:SHOPID@admin.in)

is a real mailbox.

---

# 83. DOMAIN CONFIGURATION

Make these configurable:

ADMIN_LOGIN_DOMAIN=admin.in

KIOSK_LOGIN_DOMAIN=kiosk.in

Then account generator:

shopId + "@" + ADMIN_LOGIN_DOMAIN

shopId + "@" + KIOSK_LOGIN_DOMAIN

Do not hardcode these values throughout the application.

---

# 84. MASTER ACCOUNT

Master account should use a separately configured identity.

Do NOT create:

[MASTER@admin.in](mailto:MASTER@admin.in)

as a normal shop admin.

Master role should be explicitly assigned.

---

# 85. FIRESTORE COLLECTION SUMMARY

Suggested:

registrationRequests/
{applicationId}

businesses/
{businessId}
employees/
shifts/
attendance/
salaryRecords/
leaveRequests/
announcements/
devices/
holidays/
auditLogs/
settings/

users/
{uid}

masterAuditLogs/
{auditId}

systemSettings/
global

emailJobs/
{jobId}

---

# 86. SECURITY RULE CONCEPT

Conceptually:

MASTER
→ system-wide access

SHOP_ADMIN
→ own business only

KIOSK
→ own business + only kiosk-approved resources

Unknown/disabled
→ no access

Rules must verify actual authorization.

Do not implement:

allow read, write: if true;

---

# 87. IMPORTANT BACKEND OPERATIONS

Create trusted backend functions/services for:

createShop()
approveRegistration()
rejectRegistration()
createAdminAccount()
createKioskAccount()
setBusinessStatus()
disableAccount()
enableAccount()
revokeDevice()
sendRegistrationEmail()
sendApprovalEmail()
createAuditLog()

Do not allow arbitrary clients to call privileged operations.

---

# 88. MASTER PANEL TESTING

Test:

1. New registration.
2. Registration validation.
3. Duplicate registration.
4. Master receives notification.
5. Master approves.
6. Business created.
7. Admin account created.
8. Kiosk account created.
9. Partial provisioning failure.
10. Retry provisioning.
11. Admin login.
12. Kiosk login.
13. Wrong role.
14. Admin tries another business.
15. Kiosk tries admin route.
16. Master pauses shop.
17. Kiosk receives pause.
18. Admin receives pause.
19. Master resumes.
20. Device reconnects.
21. Password reset.
22. Device revoke.
23. Email failure.
24. Email retry.
25. Master audit logging.

---

# 89. SECURITY TESTING

Test:

* forged role
* modified businessId
* copied kiosk credentials
* disabled account
* paused business
* expired session
* unauthorized Firestore read
* unauthorized Storage read
* master route access from admin
* admin route access from kiosk
* password brute force
* registration spam

---

# 90. NO SECRET IN FLUTTER

ABSOLUTE RULE:

Never put these inside Flutter application:

SMTP_APP_PASSWORD
Firebase Admin SDK private key
service account JSON
master backend secret
JWT signing secret
private API secret

Flutter may contain Firebase client configuration, but trusted backend credentials must remain server-side.

---

# 91. ENVIRONMENT VARIABLES

Backend environment should support:

FIREBASE_PROJECT_ID
FIREBASE_CLIENT_EMAIL
FIREBASE_PRIVATE_KEY

SMTP_HOST
SMTP_PORT
SMTP_USER
SMTP_APP_PASSWORD
MASTER_NOTIFICATION_EMAIL

LOGIN_ADMIN_DOMAIN
LOGIN_KIOSK_DOMAIN

APP_BASE_URL

All secrets must be excluded from Git.

Add:

.env
.env.*
to appropriate gitignore rules where necessary.

Provide:

.env.example

with placeholder values only.

---

# 92. GMAIL APP PASSWORD

Use a Gmail account with:

2-Step Verification enabled.

Generate an App Password from the Google account security settings.

Use that App Password only in the backend environment.

Do not use the normal Gmail account password.

Do not commit the App Password to Git.

Do not print the App Password in logs.

Do not return it through an API response.

---

# 93. EMAIL SECURITY

Email credentials should never appear in:

* Firestore
* Flutter source
* browser local storage
* frontend environment
* error logs
* analytics
* crash reports

---

# 94. LOGGING

Never log:

password
app password
Firebase private key
access token
refresh token
biometric representation

Logs should contain safe identifiers only.

---

# 95. MASTER PANEL RESPONSIVE DESIGN

Master panel is primarily desktop/tablet.

Must still be usable on mobile.

Desktop:

Sidebar + data table.

Mobile:

Cards + filters + bottom/compact navigation.

---

# 96. PRODUCT OWNER WORKFLOW

The final workflow should be:

NEW BUSINESS

↓

Registration Form

↓

Firestore Registration Request

↓

Email to MASTER

↓

MASTER reviews

↓

APPROVE

↓

Generate Shop ID

↓

Create Admin Account

↓

Create Kiosk Account

↓

Business becomes ACTIVE

↓

Owner receives onboarding instructions

↓

Admin logs in

↓

Adds employees

↓

Creates/enrolls shifts

↓

Enrolls faces

↓

Pairs kiosk

↓

Kiosk starts attendance

---

# 97. PAUSE WORKFLOW

MASTER

↓

Select Shop

↓

Pause

↓

Reason

↓

Confirm

↓

Business status = PAUSED

↓

Admin restricted

↓

Kiosk restricted

↓

Audit log created

↓

Optional email notification

---

# 98. RESUME WORKFLOW

MASTER

↓

Select paused shop

↓

Resume

↓

Business status = ACTIVE

↓

Devices synchronize

↓

Admin access restored

↓

Kiosk access restored

---

# 99. CRITICAL DESIGN PRINCIPLE

The Master Panel is the control plane.

The Shop Admin is the business management plane.

The Kiosk is the attendance execution plane.

Do not mix responsibilities.

MASTER:
Controls platform/business access.

ADMIN:
Controls staff/business operations.

KIOSK:
Executes attendance.

---

# 100. FINAL ANTIGRAVITY INSTRUCTION

Implement this specification as an extension of the existing Staff Management & Smart Attendance project.

DO NOT rewrite the existing application unnecessarily.

Before coding:

1. Inspect current architecture.
2. Identify existing Firebase configuration.
3. Identify current authentication implementation.
4. Identify existing business/shop model.
5. Identify employee model.
6. Identify device model.
7. Identify existing navigation.
8. Identify existing offline sync system.

Then design the Master Panel integration.

Do not duplicate existing models.

Do not create a second conflicting authentication architecture.

Reuse existing:

* Firebase project
* Firestore architecture
* repositories
* state management
* theme system
* offline engine
* device model

where appropriate.

---

# 101. IMPLEMENTATION PHASES

PHASE 1

Master authentication and authorization.

PHASE 2

Registration request system.

PHASE 3

Master registration dashboard.

PHASE 4

Shop provisioning.

PHASE 5

Admin/kiosk account creation.

PHASE 6

Role-based routing.

PHASE 7

Kiosk device binding.

PHASE 8

Pause/resume system.

PHASE 9

Master device management.

PHASE 10

Email notification service.

PHASE 11

Audit logging.

PHASE 12

Security hardening.

PHASE 13

Testing.

---

# 102. ACCEPTANCE CRITERIA

The feature is complete only when:

✓ Business can submit registration.

✓ Registration reaches Master Panel.

✓ Master receives email notification.

✓ Master can approve.

✓ Unique Shop ID is generated.

✓ Admin account is provisioned.

✓ Kiosk account is provisioned.

✓ Admin login opens Admin Panel.

✓ Kiosk login opens Kiosk Mode.

✓ Kiosk cannot access Admin Panel.

✓ Admin cannot access Master Panel.

✓ Master can see all businesses.

✓ Master can pause business.

✓ Master can resume business.

✓ Paused business cannot perform unauthorized new operations.

✓ Existing offline data is not silently deleted.

✓ Device status is visible.

✓ Device can be revoked.

✓ Password reset works.

✓ Email failures do not lose registration data.

✓ Email credentials remain server-side.

✓ Audit logs work.

✓ Multi-tenant isolation works.

✓ Security rules prevent cross-business access.

✓ No production secret is inside Flutter.

✓ No service-account credentials are inside the APK.

✓ Existing attendance/offline/salary functionality remains intact.

---

# 103. MOST IMPORTANT SECURITY RULE

The following must NEVER happen:

Flutter client says:

"I am MASTER."

Backend says:

"Okay."

Instead:

Firebase Authentication
+
secure role claims/profile
+
business association
+
backend authorization
+
Firestore/Storage security rules

must determine what the user is allowed to do.

Never trust the client.

---

# 104. FINAL PRODUCT ARCHITECTURE

```
                MASTER
                   │
                   ▼
          ┌────────────────┐
          │  MASTER PANEL  │
          └───────┬────────┘
                  │
   ┌──────────────┼───────────────┐
   │              │               │
   ▼              ▼               ▼
```

Registration       Shops          Devices
│              │               │
└──────────────┼───────────────┘
▼
BUSINESS
│
┌────────┴────────┐
▼                 ▼
ADMIN ACCOUNT      KIOSK ACCOUNT
│                 │
▼                 ▼
ADMIN APP          KIOSK APP
│                 │
Staff/Salary       Camera/Attendance
Shift/Leave        Offline Sync
Reports            Voice
Announcement       Checkout

Firebase + trusted backend services sit underneath this entire architecture.

The Master Panel must remain the authoritative control layer for business activation, suspension, account provisioning and device authorization.
