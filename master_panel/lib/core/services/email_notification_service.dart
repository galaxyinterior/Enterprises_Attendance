import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../models/registration_request_model.dart';

class EmailNotificationService {
  static final EmailNotificationService _instance = EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  // Gmail SMTP credentials
  static const String _smtpUser = 'akmtechofficial@gmail.com';
  static const String _smtpPassword = 'zynz isfx bmhd smvw';
  static const String _masterEmail = 'akmtechofficial@gmail.com';

  Future<bool> sendNewRegistrationAlert(RegistrationRequestModel request) async {
    final smtpServer = gmail(_smtpUser, _smtpPassword);

    final message = Message()
      ..from = Address(_smtpUser, 'Smart Attendance Ecosystem')
      ..recipients.add(_masterEmail)
      ..subject = '🚨 New Shop Registration — ${request.applicationId}'
      ..html = '''
        <div style="font-family: Arial, sans-serif; padding: 20px; background-color: #0f172a; color: #ffffff; border-radius: 10px;">
          <h2 style="color: #6366f1;">New Business Registration Received</h2>
          <p style="color: #cbd5e1;">A new business has submitted an application for the Smart Attendance Ecosystem.</p>
          <hr style="border-color: #334155;" />
          <table style="width: 100%; color: #ffffff; border-spacing: 0 8px;">
            <tr><td><strong>Application ID:</strong></td><td style="color: #818cf8;"><strong>${request.applicationId}</strong></td></tr>
            <tr><td><strong>Shop Name:</strong></td><td>${request.shopName}</td></tr>
            <tr><td><strong>Owner Name:</strong></td><td>${request.ownerName}</td></tr>
            <tr><td><strong>Phone Number:</strong></td><td>${request.phone}</td></tr>
            <tr><td><strong>Email Address:</strong></td><td>${request.email}</td></tr>
            <tr><td><strong>Business Type:</strong></td><td>${request.businessType}</td></tr>
            <tr><td><strong>Location:</strong></td><td>${request.city}, ${request.state}</td></tr>
            <tr><td><strong>Submission Time:</strong></td><td>${request.submittedAt}</td></tr>
          </table>
          <hr style="border-color: #334155;" />
          <p style="color: #94a3b8; font-size: 13px;">Please log in to the Master Control Panel to review and approve/provision this shop.</p>
        </div>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Email notification sent successfully: $sendReport');
      return true;
    } catch (e) {
      debugPrint('Error sending Gmail notification: $e');
      return false;
    }
  }

  Future<bool> sendApprovalCredentialsEmail({
    required String recipientEmail,
    required String shopName,
    required String ownerName,
    required String shopId,
    required String adminEmail,
    required String adminPassword,
    required String kioskEmail,
    required String kioskPassword,
  }) async {
    final smtpServer = gmail(_smtpUser, _smtpPassword);

    final message = Message()
      ..from = Address(_smtpUser, 'Smart Attendance Ecosystem')
      ..recipients.add(recipientEmail.trim())
      ..subject = '🎉 Shop Registration Approved! - Credentials for $shopName ($shopId)'
      ..html = '''
        <div style="font-family: Arial, sans-serif; padding: 24px; background-color: #0f172a; color: #ffffff; border-radius: 12px; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #6366f1; margin-top: 0;">Congratulations $ownerName! 🎉</h2>
          <p style="color: #cbd5e1; font-size: 15px;">Your application for <strong>$shopName</strong> has been reviewed and approved by the Super Admin.</p>
          
          <div style="background-color: #1e293b; padding: 16px; border-radius: 10px; border-left: 4px solid #10b981; margin: 20px 0;">
            <p style="margin: 0; color: #94a3b8; font-size: 12px; font-weight: bold; text-transform: uppercase;">YOUR ASSIGNED SHOP ID</p>
            <p style="margin: 4px 0 0 0; color: #10b981; font-size: 24px; font-weight: bold; letter-spacing: 1px;">$shopId</p>
          </div>

          <hr style="border-color: #334155; margin: 24px 0;" />

          <h3 style="color: #818cf8; margin-bottom: 12px;">🔑 Your Access Credentials</h3>
          
          <!-- Admin Panel Credentials -->
          <div style="background-color: #1e293b; padding: 16px; border-radius: 10px; margin-bottom: 16px;">
            <h4 style="color: #6366f1; margin: 0 0 10px 0;">📱 1. SHOP ADMIN PANEL LOGIN</h4>
            <table style="width: 100%; color: #ffffff; border-spacing: 0 4px;">
              <tr>
                <td style="color: #94a3b8; width: 120px;">Login ID:</td>
                <td><strong style="color: #ffffff;">$adminEmail</strong></td>
              </tr>
              <tr>
                <td style="color: #94a3b8;">Password:</td>
                <td><strong style="color: #f59e0b;">$adminPassword</strong></td>
              </tr>
            </table>
          </div>

          <!-- Kiosk Credentials -->
          <div style="background-color: #1e293b; padding: 16px; border-radius: 10px; margin-bottom: 16px;">
            <h4 style="color: #38bdf8; margin: 0 0 10px 0;">🖥️ 2. KIOSK ATTENDANCE APP LOGIN</h4>
            <table style="width: 100%; color: #ffffff; border-spacing: 0 4px;">
              <tr>
                <td style="color: #94a3b8; width: 120px;">Login ID:</td>
                <td><strong style="color: #ffffff;">$kioskEmail</strong></td>
              </tr>
              <tr>
                <td style="color: #94a3b8;">Password:</td>
                <td><strong style="color: #f59e0b;">$kioskPassword</strong></td>
              </tr>
            </table>
          </div>

          <hr style="border-color: #334155; margin: 24px 0;" />
          
          <h4 style="color: #cbd5e1; margin-bottom: 8px;">Next Steps:</h4>
          <ol style="color: #94a3b8; padding-left: 20px; font-size: 14px; line-height: 1.6;">
            <li>Open the <strong>Smart Attendance App</strong>.</li>
            <li>Select <strong>Shop Admin Login</strong> or <strong>Kiosk Mode</strong>.</li>
            <li>Log in using the respective Login ID and Password provided above.</li>
          </ol>

          <p style="color: #64748b; font-size: 12px; margin-top: 24px; text-align: center;">This is an automated system email. Please keep your credentials secure.</p>
        </div>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Credentials email sent successfully to $recipientEmail: $sendReport');
      return true;
    } catch (e) {
      debugPrint('Error sending credentials email: $e');
      return false;
    }
  }
}
