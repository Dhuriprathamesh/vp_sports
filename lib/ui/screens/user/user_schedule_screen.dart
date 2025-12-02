import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';
import '../../../core/app_theme.dart';

class UserScheduleScreen extends StatefulWidget {
  final bool isForBoys;

  const UserScheduleScreen({
    super.key,
    required this.isForBoys,
  });

  @override
  State<UserScheduleScreen> createState() => _UserScheduleScreenState();
}

class _UserScheduleScreenState extends State<UserScheduleScreen> {
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

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    final filteredEvents = _scheduleEvents.where((e) => e['day_label'] == _selectedDay).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Schedule'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
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
            
            // --- Schedule List (Read Only) ---
            Expanded(
              child: _isLoading && _scheduleEvents.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : filteredEvents.isEmpty
                      ? Center(child: Text("No events scheduled for $_selectedDay", style: const TextStyle(color: Colors.white70)))
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