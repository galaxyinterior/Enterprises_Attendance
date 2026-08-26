import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> init(String languageCode) async {
    if (!_initialized) {
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _initialized = true;
    }
    await _tts.setLanguage(languageCode);
  }

  static Future<void> speakAttendance(String name, String punchType, String languageCode) async {
    await init(languageCode);
    String message = "Attendance marked for $name. Punch $punchType.";

    if (languageCode == 'hi-IN') {
      message = "$name की उपस्थिति दर्ज हो गई, पंच $punchType";
    } else if (languageCode == 'gu-IN') {
      message = "$name ની હાજરી નોંધાઈ ગઈ છે, પંચ $punchType";
    } else if (languageCode == 'ur-IN') {
      message = "$name کی حاضری لگ گئی، پنچ $punchType";
    } else if (languageCode == 'bh-IN') {
      // Use Hindi voice but Bhojpuri dialect
      await _tts.setLanguage('hi-IN');
      message = "$name के हाजिरी लग गईल बा, पंच $punchType";
    }

    await _tts.speak(message);
  }

  static Future<void> speakMessage(String message, String languageCode) async {
    await init(languageCode);
    String translatedMessage = message;

    if (message.contains("not allowed")) {
      if (languageCode == 'hi-IN' || languageCode == 'bh-IN') {
        translatedMessage = "इस समय पंच की अनुमति नहीं है";
      } else if (languageCode == 'gu-IN') {
        translatedMessage = "આ સમયે પંચની મંજૂરી નથી";
      } else if (languageCode == 'ur-IN') {
        translatedMessage = "اس وقت پنچ کی اجازت نہیں ہے";
      }
    } else if (message == "straight_face") {
      translatedMessage = "Please keep a straight face first.";
      if (languageCode == 'hi-IN' || languageCode == 'bh-IN') {
        translatedMessage = "कृपया पहले सीधा चेहरा रखें।";
      } else if (languageCode == 'gu-IN') {
        translatedMessage = "કૃપા કરીને પહેલા સીધો ચહેરો રાખો.";
      } else if (languageCode == 'ur-IN') {
        translatedMessage = "براہ کرم پہلے سیدھا چہرہ رکھیں۔";
      }
    } else if (message == "smile_now") {
      translatedMessage = "Good! Now SMILE to verify.";
      if (languageCode == 'hi-IN' || languageCode == 'bh-IN') {
        translatedMessage = "अच्छा! अब सत्यापित करने के लिए मुस्कुराएं।";
      } else if (languageCode == 'gu-IN') {
        translatedMessage = "સરસ! હવે ચકાસવા માટે સ્મિત કરો.";
      } else if (languageCode == 'ur-IN') {
        translatedMessage = "اچھا! اب تصدیق کرنے کے لیے مسکرائیں۔";
      }
    }

    if (languageCode == 'bh-IN') {
      await _tts.setLanguage('hi-IN');
    }

    await _tts.speak(translatedMessage);
  }
}
