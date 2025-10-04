import 'package:flutter/material.dart';
import '../../../data/mock_data.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final leaderboard = MockData.leaderboard;

    // sort by points (highest first)
    leaderboard.sort((a, b) => b['points'].compareTo(a['points']));

    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Leaderboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: DataTable(
          border: TableBorder.all(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          columns: const [
            DataColumn(label: Text("Class")),
            DataColumn(label: Text("Played")),
            DataColumn(label: Text("Won")),
            DataColumn(label: Text("Lost")),
            DataColumn(label: Text("Points")),
          ],
          rows: leaderboard.map((team) {
            return DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                (states) {
                  if (leaderboard.indexOf(team) == 0) {
                    return Colors.yellow.withOpacity(0.3); // 🥇 highlight top
                  }
                  return null;
                },
              ),
              cells: [
                DataCell(Text(team['class'])),
                DataCell(Text(team['played'].toString())),
                DataCell(Text(team['won'].toString())),
                DataCell(Text(team['lost'].toString())),
                DataCell(Text(team['points'].toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
