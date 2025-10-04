import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final Function(bool) onThemeToggle;
  final bool isDarkMode;

  const ProfileScreen({super.key, required this.onThemeToggle, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("👤 Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Info
            Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundImage: AssetImage("lib/assets/images/avatar.png"), // placeholder
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Prathamesh Dhuri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Class: CO3KA"),
                    Text("Roll No: 45"),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dark Mode Toggle
            SwitchListTile(
              value: isDarkMode,
              onChanged: onThemeToggle,
              title: const Text("🌙 Dark Mode"),
            ),
            const Divider(),

            // About Section
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("About App"),
              subtitle: Text("Sports Tracker v1.0\nVidyalankar Polytechnic"),
            ),

            const Spacer(),
            const Center(
              child: Text(
                "Made with ❤️ in Flutter",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
