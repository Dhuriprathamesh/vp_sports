import 'package:flutter/material.dart';
import '../../../data/mock_data.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case "Live":
        return Colors.red;
      case "Finished":
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = MockData.matches;

    return Scaffold(
      appBar: AppBar(title: const Text("📅 Match Schedule")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.sports,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              title: Text(
                "${match['sport']} - ${match['teams']}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${match['date']} at ${match['time']} \nVenue: ${match['venue']}",
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    match['status'],
                    style: TextStyle(
                      color: _getStatusColor(match['status']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (match['score'].toString().isNotEmpty)
                    Text(
                      match['score'],
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
