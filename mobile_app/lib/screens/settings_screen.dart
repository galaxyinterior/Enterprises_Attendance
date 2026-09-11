import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_config.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  final String storeId;
  const SettingsScreen({super.key, required this.storeId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _announcementController = TextEditingController();
  
  TimeOfDay _inStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _inEnd = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _outStart = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _outEnd = const TimeOfDay(hour: 20, minute: 0);
  
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordedFilePath;
  
  String _selectedLanguage = 'en-IN'; // English (India) default

  final List<Map<String, String>> _languages = [
    {'code': 'en-IN', 'name': 'English'},
    {'code': 'hi-IN', 'name': 'Hindi (हिंदी)'},
    {'code': 'gu-IN', 'name': 'Gujarati (ગુજરાતી)'},
    {'code': 'ur-IN', 'name': 'Urdu (اردو)'},
    {'code': 'bn-IN', 'name': 'Bengali (বাংলা)'}, 
    {'code': 'bh-IN', 'name': 'Bhojpuri (भोजपुरी)'},
    {'code': 'mr-IN', 'name': 'Marathi (मराठी)'},
    {'code': 'ta-IN', 'name': 'Tamil (தமிழ்)'},
    {'code': 'te-IN', 'name': 'Telugu (తెలుగు)'},
  ];

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _loadConfig();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await DatabaseHelper.instance.getStoreConfig();
    if (config != null) {
      setState(() {
        _inStart = _parseTime(config.punchInStart) ?? _inStart;
        _inEnd = _parseTime(config.punchInEnd) ?? _inEnd;
        _outStart = _parseTime(config.punchOutStart) ?? _outStart;
        _outEnd = _parseTime(config.punchOutEnd) ?? _outEnd;
        _selectedLanguage = config.ttsLanguage;
      });
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _pickTime(BuildContext context, bool isStart, bool isIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isIn ? (isStart ? _inStart : _inEnd) : (isStart ? _outStart : _outEnd),
    );
    if (picked != null) {
      setState(() {
        if (isIn) {
          if (isStart) _inStart = picked;
          else _inEnd = picked;
        } else {
          if (isStart) _outStart = picked;
          else _outEnd = picked;
        }
      });
      _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    final config = StoreConfig(
      storeName: widget.storeId,
      address: '',
      openTime: '',
      closeTime: '',
      punchInStart: _formatTime(_inStart),
      punchInEnd: _formatTime(_inEnd),
      punchOutStart: _formatTime(_outStart),
      punchOutEnd: _formatTime(_outEnd),
      ttsLanguage: _selectedLanguage,
    );
    await DatabaseHelper.instance.saveStoreConfig(config);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Saved!")));
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/announcement.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 16000),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordedFilePath = null;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }
  }

  Future<void> _sendAnnouncement() async {
    final msg = _announcementController.text.trim();
    if (msg.isEmpty && _recordedFilePath == null) return;
    
    String? audioBase64;
    if (_recordedFilePath != null) {
      try {
        final bytes = await File(_recordedFilePath!).readAsBytes();
        audioBase64 = base64Encode(bytes);
      } catch (e) {
        debugPrint("Error encoding audio: $e");
      }
    }

    try {
      final payload = <String, dynamic>{
        'store_id': widget.storeId,
        'message': msg.isNotEmpty ? msg : "Voice Announcement",
      };
      
      if (audioBase64 != null) {
        payload['audio_path'] = audioBase64;
      }

      await Supabase.instance.client
          .from('notifications')
          .insert(payload);
      
      _announcementController.clear();
      setState(() {
        _recordedFilePath = null;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Announcement sent to Kiosk!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Settings", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voice Settings
            const Text("Voice & Language", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: "Kiosk Voice Language",
                  prefixIcon: const Icon(Icons.record_voice_over, color: Color(0xFF00BFFF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _languages.map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang['code']!,
                    child: Text(lang['name']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLanguage = val);
                    _saveConfig();
                  }
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Notification Broadcast
            const Text("Broadcast Announcement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  TextField(
                    controller: _announcementController,
                    decoration: InputDecoration(
                      labelText: "Message to announce on Kiosk (Optional)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.campaign),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isRecording ? _stopRecording : _startRecording,
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.red : null),
                          label: Text(_isRecording ? "Stop Recording" : "Record Voice Message"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.red.shade100 : Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_recordedFilePath != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text("Recorded", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _recordedFilePath = null),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sendAnnouncement,
                      icon: const Icon(Icons.send),
                      label: const Text("Send Announcement"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Timings
            const Text("Punch Timings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text("Punch IN Allowed Window", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(child: _buildTimeButton("Start: ${_inStart.format(context)}", () => _pickTime(context, true, true))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTimeButton("End: ${_inEnd.format(context)}", () => _pickTime(context, false, true))),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text("Punch OUT Allowed Window", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(child: _buildTimeButton("Start: ${_outStart.format(context)}", () => _pickTime(context, true, false))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTimeButton("End: ${_outEnd.format(context)}", () => _pickTime(context, false, false))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(text),
    );
  }
}
