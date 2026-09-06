import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailSender {
  static String generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<void> sendApprovalEmail({
    required String recipientEmail,
    required String ownerName,
    required String storeName,
    required String storeCode,
    required String adminPassword,
    required String kioskPassword,
  }) async {
    final smtpEmail = dotenv.env['SMTP_EMAIL'];
    final smtpPassword = dotenv.env['SMTP_PASSWORD'];

    if (smtpEmail == null || smtpPassword == null || smtpEmail.isEmpty || smtpPassword.isEmpty) {
      throw Exception('SMTP credentials not configured in .env file.');
    }

    final smtpServer = gmail(smtpEmail, smtpPassword);

    final message = Message()
      ..from = Address(smtpEmail, 'SmartAttend Master Admin')
      ..recipients.add(recipientEmail)
      ..subject = 'Your Store Application for $storeName has been Approved!'
      ..html = """
        <h3>Hello $ownerName,</h3>
        <p>Congratulations! Your store application for <strong>$storeName</strong> has been approved.</p>
        <p>Your unique Store ID is: <strong>$storeCode</strong></p>
        <br/>
        <h4>Admin Panel Credentials:</h4>
        <p>Email: admin@$storeCode.in</p>
        <p>Password: $adminPassword</p>
        <br/>
        <h4>Kiosk Screen Credentials:</h4>
        <p>Email: kiosk@$storeCode.in</p>
        <p>Password: $kioskPassword</p>
        <br/>
        <p>Please log in and change your password immediately.</p>
        <p>Welcome to SmartAttend!</p>
      """;

    try {
      await send(message, smtpServer);
    } on MailerException catch (e) {
      throw Exception('Failed to send email: ${e.message}');
    }
  }
}
