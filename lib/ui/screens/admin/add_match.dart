import 'package:flutter/material.dart';

class AddMatchScreen extends StatefulWidget {
  final String sportName;

  const AddMatchScreen({super.key, required this.sportName});

  @override
  State<AddMatchScreen> createState() => _AddMatchScreenState();
}

class _AddMatchScreenState extends State<AddMatchScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        width: MediaQuery.of(context).size.width * 0.95,
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
        child: Column(
          children: [
            // --- Custom Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Add ${widget.sportName} Match',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            // --- Form Section ---
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSportSpecificForm(),
                    ],
                  ),
                ),
              ),
            ),
            // --- Save Button ---
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Match details saved!')),
                    );
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Match Details'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper to build the correct form based on sport ---
  Widget _buildSportSpecificForm() {
    switch (widget.sportName) {
      case 'Cricket':
        return _buildCricketForm();
      case 'Football':
        return _buildFootballForm();
      case 'Kabaddi':
        return _buildKabaddiForm();
      case 'Volleyball':
        return _buildVolleyballForm();
      case 'Athletics':
        return _buildAthleticsForm();
      case 'Table Tennis':
      case 'Badminton':
      case 'Carrom':
        return _buildRacquetSportsForm();
      case 'Chess':
        return _buildChessForm();
      default:
        return _buildTextFormField(label: 'Match Details');
    }
  }

  // --- SPORT-SPECIFIC FORM WIDGETS ---

  Widget _buildCricketForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Teams & Players'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Team A Name', icon: Icons.group_outlined),
          _buildTextFormField(label: 'Team B Name', icon: Icons.group_outlined),
        ),
        _buildTextFormField(label: 'Players (e.g., 11 + 1)', icon: Icons.people_outline),
        _buildSectionHeader('Match Info'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Overs', icon: Icons.sports_cricket_outlined),
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined),
        ),
        _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined),
        _buildTextFormField(label: 'Umpire(s)', icon: Icons.sports),
      ],
    );
  }

  Widget _buildFootballForm() {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Teams & Players'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Team A Name', icon: Icons.group_outlined),
          _buildTextFormField(label: 'Team B Name', icon: Icons.group_outlined),
        ),
        _buildTextFormField(label: 'Players (e.g., 11 + 5)', icon: Icons.people_outline),
        _buildSectionHeader('Match Info'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Duration', icon: Icons.timer_outlined),
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined),
        ),
        _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined),
        _buildTextFormField(label: 'Referee(s)', icon: Icons.sports),
      ],
    );
  }
  
  Widget _buildKabaddiForm() {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Teams & Players'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Team A Name', icon: Icons.group_outlined),
          _buildTextFormField(label: 'Team B Name', icon: Icons.group_outlined),
        ),
        _buildTextFormField(label: 'Players (e.g., 7 + 3)', icon: Icons.people_outline),
         _buildSectionHeader('Match Info'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Duration', icon: Icons.timer_outlined),
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined),
        ),
        _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined),
        _buildTextFormField(label: 'Referee / Officials', icon: Icons.sports),
      ],
    );
  }
  
  Widget _buildVolleyballForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Teams & Players'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Team A Name', icon: Icons.group_outlined),
          _buildTextFormField(label: 'Team B Name', icon: Icons.group_outlined),
        ),
        _buildTextFormField(label: 'Players (e.g., 6 + 2)', icon: Icons.people_outline),
        _buildSectionHeader('Match Info'),
        _buildResponsiveFormFieldRow(
          _buildDropdownFormField(label: 'Format', items: ['Best of 3', 'Best of 5'], icon: Icons.format_list_numbered),
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined),
        ),
        _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined),
        _buildTextFormField(label: 'Referee / Line Judges', icon: Icons.sports),
      ],
    );
  }
  
   Widget _buildAthleticsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Event Details'),
        _buildTextFormField(label: 'Event Name', icon: Icons.emoji_events_outlined),
        _buildTextFormField(label: 'Participants (comma-separated)', icon: Icons.people_outline, maxLines: 3),
        _buildSectionHeader('Event Info'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined),
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined),
        ),
        _buildTextFormField(label: 'Official / Timekeeper', icon: Icons.sports),
      ],
    );
  }
  
  Widget _buildRacquetSportsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Teams & Players'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Team A Name', icon: Icons.group_outlined),
          _buildTextFormField(label: 'Team B Name', icon: Icons.group_outlined),
        ),
        _buildTextFormField(label: 'Players (per team)', icon: Icons.people_outline),
        _buildSectionHeader('Match Info'),
         _buildResponsiveFormFieldRow(
          _buildDropdownFormField(label: 'Match Type', items: ['Singles', 'Doubles'], icon: Icons.person_outline),
          _buildDropdownFormField(label: 'Format', items: ['Best of 3', 'Best of 5', 'Best of 7'], icon: Icons.format_list_numbered)
        ),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined), 
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined)
        ),
        _buildTextFormField(label: 'Umpire / Official', icon: Icons.sports),
      ],
    );
  }
  
  Widget _buildChessForm() {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Teams & Players'),
        _buildResponsiveFormFieldRow(
          _buildTextFormField(label: 'Team A Name', icon: Icons.group_outlined),
          _buildTextFormField(label: 'Team B Name', icon: Icons.group_outlined),
        ),
        _buildTextFormField(label: 'Players (per team)', icon: Icons.people_outline),
        _buildSectionHeader('Match Info'),
        _buildResponsiveFormFieldRow(
          _buildDropdownFormField(label: 'Time Control', items: ['Blitz', 'Rapid', 'Classical'], icon: Icons.timer_outlined),
          _buildTextFormField(label: 'Venue', icon: Icons.location_on_outlined),
        ),
        _buildTextFormField(label: 'Start Time', icon: Icons.schedule_outlined),
        _buildTextFormField(label: 'Arbiter / Match Official', icon: Icons.sports),
      ],
    );
  }

  // --- GENERIC FORM FIELD WIDGETS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[800],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildResponsiveFormFieldRow(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a breakpoint to decide whether to use a row or a column
        if (constraints.maxWidth > 400) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        } else {
          return Column(
            children: [left, right],
          );
        }
      },
    );
  }

  Widget _buildTextFormField({required String label, IconData? icon, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdownFormField({required String label, required List<String> items, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (value) {},
        validator: (value) => value == null ? 'Required' : null,
      ),
    );
  }
}

