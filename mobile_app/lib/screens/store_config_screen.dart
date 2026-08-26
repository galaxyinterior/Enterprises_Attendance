import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/store_config.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class StoreConfigScreen extends StatefulWidget {
  final String storeId;
  const StoreConfigScreen({super.key, required this.storeId});

  @override
  State<StoreConfigScreen> createState() => _StoreConfigScreenState();
}

class _StoreConfigScreenState extends State<StoreConfigScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _punchInStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _punchInEnd = const TimeOfDay(hour: 11, minute: 0);
  TimeOfDay _punchOutStart = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _punchOutEnd = const TimeOfDay(hour: 20, minute: 0);
  String _ttsLanguage = 'en-IN';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await DatabaseHelper.instance.getStoreConfig();
    if (config != null) {
      _nameController.text = config.storeName;
      _addressController.text = config.address;
      _openTime = _parseTime(config.openTime);
      _closeTime = _parseTime(config.closeTime);
      _punchInStart = _parseTime(config.punchInStart);
      _punchInEnd = _parseTime(config.punchInEnd);
      _punchOutStart = _parseTime(config.punchOutStart);
      _punchOutEnd = _parseTime(config.punchOutEnd);
      _ttsLanguage = config.ttsLanguage;
    }
    setState(() {
      _isLoading = false;
    });
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay initialTime, Function(TimeOfDay) onSelected) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF121826),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        onSelected(picked);
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Store Name and Address are required.")),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    final config = StoreConfig(
      storeName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      openTime: _formatTime(_openTime),
      closeTime: _formatTime(_closeTime),
      punchInStart: _formatTime(_punchInStart),
      punchInEnd: _formatTime(_punchInEnd),
      punchOutStart: _formatTime(_punchOutStart),
      punchOutEnd: _formatTime(_punchOutEnd),
      ttsLanguage: _ttsLanguage,
    );

    await DatabaseHelper.instance.saveStoreConfig(config);
    await SyncService.pushStoreConfig(widget.storeId, config);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Store Configuration Saved & Synced!"), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildTimePickerRow(String title, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF0B0F19),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _selectTime(context, time, onChanged),
            child: Text(
              time.format(context),
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Configuration"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Store Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Store Name",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF121826),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Store Address",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF121826),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Operating Hours",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121826),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildTimePickerRow("Store Opening Time", _openTime, (t) => _openTime = t),
                  const Divider(color: Colors.white24),
                  _buildTimePickerRow("Store Closing Time", _closeTime, (t) => _closeTime = t),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Punch-In Window",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              "Employees can only punch IN during this time.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121826),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildTimePickerRow("Start Time", _punchInStart, (t) => _punchInStart = t),
                  const Divider(color: Colors.white24),
                  _buildTimePickerRow("End Time", _punchInEnd, (t) => _punchInEnd = t),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Punch-Out Window",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              "Employees can only punch OUT during this time.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121826),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildTimePickerRow("Start Time", _punchOutStart, (t) => _punchOutStart = t),
                  const Divider(color: Colors.white24),
                  _buildTimePickerRow("End Time", _punchOutEnd, (t) => _punchOutEnd = t),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Voice Assistant (TTS)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _ttsLanguage,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Announcement Language",
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.record_voice_over, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF121826),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'en-US', child: Text("English (Default)")),
                DropdownMenuItem(value: 'en-IN', child: Text("English (India)")),
                DropdownMenuItem(value: 'hi-IN', child: Text("Hindi (हिंदी)")),
                DropdownMenuItem(value: 'gu-IN', child: Text("Gujarati (ગુજરાતી)")),
                DropdownMenuItem(value: 'ur-IN', child: Text("Urdu (اردو)")),
                DropdownMenuItem(value: 'bh-IN', child: Text("Bhojpuri (भोजपुरी)")),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _ttsLanguage = val);
                }
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? "Saving..." : "Save Configuration",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
