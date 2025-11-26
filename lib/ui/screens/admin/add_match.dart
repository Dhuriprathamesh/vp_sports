import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddMatchScreen extends StatefulWidget {
  final String sportName;

  const AddMatchScreen({super.key, required this.sportName});

  @override
  State<AddMatchScreen> createState() => _AddMatchScreenState();
}

class _AddMatchScreenState extends State<AddMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentPage = 0;
  double _navigationDirection = 1.0;
  bool _isLoading = false;

  // Controllers
  late final TextEditingController _teamANameController;
  late final TextEditingController _teamBNameController;
  late final List<TextEditingController> _teamAPlayerControllers;
  late final List<TextEditingController> _teamBPlayerControllers;
  late final TextEditingController _venueController;
  late final TextEditingController _startTimeController;
  
  // Sport Specific Controllers
  late final TextEditingController _oversController;
  late final TextEditingController _umpiresController;
  late final TextEditingController _matchDurationController; 
  late final TextEditingController _refereesController; 
  
  String _volleyballFormat = 'Best of 3 Sets';

  @override
  void initState() {
    super.initState();
    _teamANameController = TextEditingController();
    _teamBNameController = TextEditingController();
    _venueController = TextEditingController();
    // Default time: Tomorrow
    _startTimeController = TextEditingController(
        text: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().add(const Duration(days: 1))));
    
    _oversController = TextEditingController();
    _umpiresController = TextEditingController();
    
    String defaultDuration = "90";
    if (widget.sportName == 'Kabaddi') defaultDuration = "40";
    _matchDurationController = TextEditingController(text: defaultDuration);
    
    _refereesController = TextEditingController();

    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final totalPlayers = playerCounts['players']! + playerCounts['subs']!;
    _teamAPlayerControllers =
        List.generate(totalPlayers, (_) => TextEditingController());
    _teamBPlayerControllers =
        List.generate(totalPlayers, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _teamANameController.dispose();
    _teamBNameController.dispose();
    _venueController.dispose();
    _startTimeController.dispose();
    _oversController.dispose();
    _umpiresController.dispose();
    _matchDurationController.dispose();
    _refereesController.dispose();
    for (var controller in _teamAPlayerControllers) {
      controller.dispose();
    }
    for (var controller in _teamBPlayerControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _saveMatch() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);

    const String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final sportNameUrl = widget.sportName.toLowerCase();
    final String apiUrl = 'http://$host:5000/api/add_${sportNameUrl}_match';
    
    try {
      final List<String> teamAPlayers = _teamAPlayerControllers
          .map((c) => c.text)
          .where((name) => name.isNotEmpty)
          .toList();

      final List<String> teamBPlayers = _teamBPlayerControllers
          .map((c) => c.text)
          .where((name) => name.isNotEmpty)
          .toList();
      
      Map<String, dynamic> matchData = {
        'team_a_name': _teamANameController.text,
        'team_b_name': _teamBNameController.text,
        'team_a_players': teamAPlayers,
        'team_b_players': teamBPlayers,
        'start_time': _startTimeController.text,
        'venue': _venueController.text,
      };

      if (widget.sportName == 'Cricket') {
        final List<String> umpires = _umpiresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['overs'] = _oversController.text;
        matchData['umpires'] = umpires;
      } else if (widget.sportName == 'Football') {
        final List<String> referees = _refereesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['match_duration'] = _matchDurationController.text;
        matchData['referees'] = referees;
      } else if (widget.sportName == 'Kabaddi') {
        final List<String> officials = _refereesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['match_duration'] = _matchDurationController.text;
        matchData['officials'] = officials;
      } else if (widget.sportName == 'Volleyball') {
        final List<String> officials = _refereesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['match_format'] = _volleyballFormat; 
        matchData['officials'] = officials;
      } else if (widget.sportName == 'Athletics') {
        final List<String> officials = _refereesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['officials'] = officials;
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(matchData),
      );

      if (mounted) {
          if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match added successfully!'), backgroundColor: Colors.green));
            Navigator.of(context).pop(true); 
          } else {
            final responseBody = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${responseBody['message']}'), backgroundColor: Colors.red));
          }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
       insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            const Divider(height: 24),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  final slideIn = Tween<Offset>(
                    begin: Offset(_navigationDirection, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return ScaleTransition(
                    scale: Tween<double>(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: SlideTransition(
                      position: slideIn,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                child: _getCurrentPage(),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _getCurrentPage() {
    final isAthletics = widget.sportName == 'Athletics';
    
    switch (_currentPage) {
      case 0:
        // Page 1: "Event Name" + "Participants"
        return _buildTeamPage(isAthletics ? 'Event' : 'A', _teamANameController, _teamAPlayerControllers);
      case 1:
        // Page 2: Team B (Skipped for Athletics)
        return _buildTeamPage('B', _teamBNameController, _teamBPlayerControllers);
      case 2:
        // Page 3 (Athletics Page 2): Match Info
        return _buildMatchInfoPage();
      default:
        return Container(key: const ValueKey('empty'));
    }
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Add ${widget.sportName} Match',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final isAthletics = widget.sportName == 'Athletics';
    // Shows 2 steps for Athletics, 3 for others
    final titles = isAthletics ? ['Event', 'Info'] : ['Team A', 'Team B', 'Match Info'];
    
    // Map actual page index to visual step index
    int visualIndex = _currentPage;
    if (isAthletics && _currentPage == 2) visualIndex = 1; // Match Info is visually step 2

    final double screenWidth = MediaQuery.of(context).size.width - 88; 
    final double progressWidth = (visualIndex / (titles.length - 1)) * screenWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Background Line
              Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              // Active Progress Line
              Align(alignment: Alignment.centerLeft, child: AnimatedContainer(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, height: 4, width: progressWidth, margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(2)))), // Green Color
              // Step Circles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(titles.length, (index) {
                  final bool isCompleted = index < visualIndex;
                  final bool isActive = index == visualIndex;
                  return Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: isCompleted ? const Color(0xFF1B5E20) : (isActive ? const Color(0xFF1B5E20) : Colors.grey.shade300), 
                      border: Border.all(color: Colors.white, width: 2), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                    ),
                    child: Center(child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 20) : Text('${index + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(titles.length, (index) {
              final bool isActive = index <= visualIndex;
              TextAlign align = index == 0 ? TextAlign.left : (index == titles.length - 1 ? TextAlign.right : TextAlign.center);
              return Expanded(child: Text(titles[index], textAlign: align, style: TextStyle(fontSize: 12, color: isActive ? Colors.black87 : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)));
            }),
          )
        ],
      ),
    );
  }

  Widget _buildTeamPage(String teamLabel, TextEditingController teamNameController, List<TextEditingController> playerControllers) {
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final isAthletics = widget.sportName == 'Athletics';
    
    final nameLabel = isAthletics ? "Enter Event Name" : 'Enter Team $teamLabel Name';
    final headerLabel = isAthletics ? "Event Name" : 'Team $teamLabel Name';
    final listHeader = isAthletics ? "Participants (${playerCounts['players']})" : 'Team $teamLabel Players (${playerCounts['players']})';

    return SingleChildScrollView(
      key: PageStorageKey('team_$teamLabel'),
      child: _AnimatedColumn(
        key: ValueKey('team_anim_$teamLabel'),
        children: [
          _buildSectionHeader(headerLabel),
          _buildTextFormField(controller: teamNameController, label: nameLabel, icon: isAthletics ? Icons.event_note : Icons.group_outlined),
          const SizedBox(height: 16),
          _buildSectionHeader(listHeader),
          ...List.generate(playerControllers.length, (index) {
              String pLabel;
              if (isAthletics) {
                 pLabel = 'Runner ${index + 1}';
              } else {
                 pLabel = index < playerCounts['players']! ? 'Player ${index + 1}' : 'Substitute ${index - playerCounts['players']! + 1}';
              }
              return _buildTextFormField(controller: playerControllers[index], label: pLabel, icon: Icons.person_outline, isRequired: false);
          }),
        ],
      ),
    );
  }

  Widget _buildMatchInfoPage() {
    return SingleChildScrollView(
      key: const PageStorageKey('match_info'),
      child: Form(
        key: _formKey,
        child: _AnimatedColumn(
          key: const ValueKey('match_info_anim'),
          children: [
            _buildSectionHeader('Match Information'),
            ..._getSportSpecificMatchInfoFields(),
            const SizedBox(height: 8),
            _buildTextFormField(label: 'Venue', controller: _venueController, icon: Icons.location_on_outlined),
             _buildTextFormField(controller: _startTimeController, label: 'Start Time (YYYY-MM-DD HH:MM:SS)', icon: Icons.schedule_outlined, keyboardType: TextInputType.datetime),
          ],
        ),
      ),
    );
  }

  List<Widget> _getSportSpecificMatchInfoFields() {
    switch (widget.sportName) {
      case 'Cricket':
        return [_buildTextFormField(controller: _oversController, label: 'Overs per Innings', icon: Icons.sports_cricket_outlined, keyboardType: TextInputType.number),
          _buildTextFormField(controller: _umpiresController, label: 'Umpire(s) (comma-separated)', icon: Icons.sports)];
      case 'Football':
        return [_buildTextFormField(controller: _matchDurationController, label: 'Match Duration (mins)', icon: Icons.timer, keyboardType: TextInputType.number),
          _buildTextFormField(controller: _refereesController, label: 'Referee(s)', icon: Icons.sports_soccer_outlined)];
      case 'Kabaddi':
        return [_buildTextFormField(controller: _matchDurationController, label: 'Match Duration (mins)', icon: Icons.timer, keyboardType: TextInputType.number),
          _buildTextFormField(controller: _refereesController, label: 'Referee / Officials', icon: Icons.sports_kabaddi_outlined)];
      case 'Volleyball':
        return [
           Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: DropdownButtonFormField<String>(
               value: _volleyballFormat, decoration: InputDecoration(labelText: 'Match Format', prefixIcon: Icon(Icons.sports_volleyball, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
               items: const [DropdownMenuItem(value: 'Best of 3 Sets', child: Text('Best of 3 Sets')), DropdownMenuItem(value: 'Best of 5 Sets', child: Text('Best of 5 Sets'))],
               onChanged: (val) => setState(() => _volleyballFormat = val!),
             )),
           _buildTextFormField(controller: _refereesController, label: 'Referee / Line Judges', icon: Icons.sports),
        ];
      case 'Athletics':
        return [
          _buildTextFormField(controller: _refereesController, label: 'Official / Timekeeper', icon: Icons.timer_outlined),
        ];
      default:
        return [];
    }
  }

  Widget _buildNavigationButtons() {
    final isAthletics = widget.sportName == 'Athletics';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentPage > 0)
          TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            onPressed: _isLoading ? null : () {
              setState(() {
                _navigationDirection = -1.0;
                // Logic: If Athletics, skip page 1 (Team B) when going back
                if (isAthletics && _currentPage == 2) {
                   _currentPage = 0;
                } else {
                   _currentPage--;
                }
              });
            },
          ),
        const Spacer(),
        ElevatedButton.icon(
          icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_forward), // Changed Icon to just arrow
          label: Text(_currentPage == 2 ? 'Save Match' : 'Next'),
          onPressed: _isLoading ? null : () {
            if (_currentPage < 2) {
              setState(() {
                _navigationDirection = 1.0;
                // Logic: If Athletics, skip page 1 (Team B) when going forward
                if (isAthletics && _currentPage == 0) {
                   _currentPage = 2;
                } else {
                   _currentPage++;
                }
              });
            } else {
              _saveMatch();
            }
          },
          // Updated Button Style to match the image (Green, Rounded)
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20), // Dark Green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), // Wider button
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Less rounded corners
          ),
        ),
      ],
    );
  }

  Map<String, int> _getSportPlayerCounts(String sportName) {
    switch (sportName) {
      case 'Cricket': return {'players': 11, 'subs': 4};
      case 'Football': return {'players': 11, 'subs': 5};
      case 'Kabaddi': return {'players': 7, 'subs': 5};
      case 'Volleyball': return {'players': 6, 'subs': 6};
      case 'Athletics': return {'players': 8, 'subs': 0}; // 8 lanes usually
      default: return {'players': 1, 'subs': 0};
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(top: 20.0, bottom: 8.0), child: Text(title, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16)));
  }

  // Updated Input Field Style to match Image (White Box, Grey Border)
  Widget _buildTextFormField({required String label, IconData? icon, TextEditingController? controller, TextInputType? keyboardType, bool isRequired = true, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller, keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, 
          helperText: helperText, 
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), 
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2)),
          filled: true, 
          fillColor: Colors.white // White Background
        ),
        validator: (value) => isRequired && (value?.isEmpty ?? true) ? 'Required' : null,
      ),
    );
  }
}

class _AnimatedColumn extends StatefulWidget {
  final List<Widget> children;
  const _AnimatedColumn({super.key, required this.children});

  @override
  State<_AnimatedColumn> createState() => _AnimatedColumnState();
}

class _AnimatedColumnState extends State<_AnimatedColumn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 400 + (widget.children.length * 80)));
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.children.length, (index) {
        final intervalStart = (80 * index) / _controller.duration!.inMilliseconds;
        final intervalEnd = (intervalStart + 0.6).clamp(0.0, 1.0);
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut))),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut))),
            child: widget.children[index],
          ),
        );
      }),
    );
  }
}