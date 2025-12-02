import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';
import '../../../core/app_theme.dart';

class AdminScheduleScreen extends StatefulWidget {
  final bool isForBoys;

  const AdminScheduleScreen({
    super.key,
    required this.isForBoys,
  });

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  String _selectedDay = 'Day 1';
  final List<String> _days = ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5'];
  
  List<Map<String, dynamic>> _scheduleEvents = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
    // Poll every 1 second for lively updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _fetchSchedule(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSchedule({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoading = true);
    try {
      final gender = widget.isForBoys ? 'Boys' : 'Girls';
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/get_schedule?gender=$gender'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _scheduleEvents = data.map((e) => e as Map<String, dynamic>).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!isBackground && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addEvent(String time, String event, String venue) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/add_schedule_event'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'day': _selectedDay,
          'time': time,
          'event': event,
          'venue': venue,
          'gender': widget.isForBoys ? 'Boys' : 'Girls',
        }),
      );
      if (response.statusCode == 201) {
        _fetchSchedule(); // Refresh immediately
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteEvent(int id) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/delete_schedule_event'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        _fetchSchedule();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showAddEventDialog() {
    TextEditingController timeCtrl = TextEditingController();
    TextEditingController eventCtrl = TextEditingController();
    TextEditingController venueCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Schedule Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time (e.g., 10:00 AM)')),
            TextField(controller: eventCtrl, decoration: const InputDecoration(labelText: 'Event Description')),
            TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Venue')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (timeCtrl.text.isNotEmpty && eventCtrl.text.isNotEmpty) {
                _addEvent(timeCtrl.text, eventCtrl.text, venueCtrl.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    final filteredEvents = _scheduleEvents.where((e) => e['day_label'] == _selectedDay).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Schedule'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // --- Day Selector ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Day:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  DropdownButton<String>(
                    value: _selectedDay,
                    dropdownColor: Theme.of(context).primaryColor,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    iconEnabledColor: Colors.white,
                    underline: Container(height: 2, color: Colors.white),
                    items: _days.map((String day) {
                      return DropdownMenuItem<String>(
                        value: day,
                        child: Text(day),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDay = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            
            // --- Schedule List ---
            Expanded(
              child: _isLoading && _scheduleEvents.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : filteredEvents.isEmpty
                      ? Center(child: Text("No events for $_selectedDay", style: const TextStyle(color: Colors.white70)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredEvents.length,
                          itemBuilder: (context, index) {
                            final event = filteredEvents[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    event['event_time'] ?? '',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  event['event_name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(event['venue'] ?? '', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteEvent(event['id']),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}