class StoreConfig {
  final String storeName;
  final String address;
  final String openTime;
  final String closeTime;
  final String punchInStart;
  final String punchInEnd;
  final String punchOutStart;
  final String punchOutEnd;
  final String ttsLanguage;

  StoreConfig({
    required this.storeName,
    required this.address,
    required this.openTime,
    required this.closeTime,
    required this.punchInStart,
    required this.punchInEnd,
    required this.punchOutStart,
    required this.punchOutEnd,
    required this.ttsLanguage,
  });

  Map<String, dynamic> toMap() {
    return {
      'store_name': storeName,
      'address': address,
      'open_time': openTime,
      'close_time': closeTime,
      'punch_in_start': punchInStart,
      'punch_in_end': punchInEnd,
      'punch_out_start': punchOutStart,
      'punch_out_end': punchOutEnd,
      'tts_language': ttsLanguage,
    };
  }

  factory StoreConfig.fromMap(Map<String, dynamic> map) {
    return StoreConfig(
      storeName: map['store_name'] ?? '',
      address: map['address'] ?? '',
      openTime: map['open_time'] ?? '09:00',
      closeTime: map['close_time'] ?? '18:00',
      punchInStart: map['punch_in_start'] ?? '08:00',
      punchInEnd: map['punch_in_end'] ?? '11:00',
      punchOutStart: map['punch_out_start'] ?? '17:00',
      punchOutEnd: map['punch_out_end'] ?? '20:00',
      ttsLanguage: map['tts_language'] ?? 'en-US',
    );
  }
}
