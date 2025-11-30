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
  // Athletics Specific: Team C Controller
  late final TextEditingController _teamCNameController; 
  
  late final List<TextEditingController> _teamAPlayerControllers;
  late final List<TextEditingController> _teamBPlayerControllers;
  // Athletics Specific: Team C Players
  late final List<TextEditingController> _teamCPlayerControllers;

  late final TextEditingController _venueController;
  late final TextEditingController _startTimeController;
  
  // Sport Specific Controllers
  late final TextEditingController _oversController;
  late final TextEditingController _umpiresController;
  late final TextEditingController _matchDurationController; 
  late final TextEditingController _refereesController; 
  
  final TextEditingController _totalQuartersController = TextEditingController(text: '4'); 
  
  String _volleyballFormat = 'Best of 3 Sets';
  String _basketballCategory = 'full_game';
  
  // Selection state for active players
  String? _selectedPlayerA;
  String? _selectedPlayerB;
  String? _selectedPlayerA2;
  String? _selectedPlayerB2;

  // Table Tennis & Badminton state
  String _category = 'singles'; 
  int _totalSets = 3;

  @override
  void initState() {
    super.initState();
    _teamANameController = TextEditingController();
    _teamBNameController = TextEditingController();
    _teamCNameController = TextEditingController(); // Init Team C Name
    _venueController = TextEditingController();
    _startTimeController = TextEditingController(
        text: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().add(const Duration(days: 1))));
    
    _oversController = TextEditingController();
    _umpiresController = TextEditingController();
    
    String defaultDuration = "90";
    if (widget.sportName == 'Kabaddi') defaultDuration = "40";
    _matchDurationController = TextEditingController(text: defaultDuration);
    
    _refereesController = TextEditingController();

    // Determine total controllers needed (Players + Subs)
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final totalPlayers = playerCounts['players']! + playerCounts['subs']!;
    
    _teamAPlayerControllers =
        List.generate(totalPlayers, (_) => TextEditingController());
    _teamBPlayerControllers =
        List.generate(totalPlayers, (_) => TextEditingController());
    // Init Team C Players (Only used for Athletics)
    _teamCPlayerControllers = 
        List.generate(totalPlayers, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _teamANameController.dispose();
    _teamBNameController.dispose();
    _teamCNameController.dispose();
    _venueController.dispose();
    _startTimeController.dispose();
    _oversController.dispose();
    _umpiresController.dispose();
    _matchDurationController.dispose();
    _refereesController.dispose();
    _totalQuartersController.dispose();
    for (var controller in _teamAPlayerControllers) controller.dispose();
    for (var controller in _teamBPlayerControllers) controller.dispose();
    for (var controller in _teamCPlayerControllers) controller.dispose();
    super.dispose();
  }
  
  Future<void> _saveMatch() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);

    const String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final sportNameUrl = widget.sportName.toLowerCase().replaceAll(' ', '_'); 
    final String apiUrl = 'http://$host:5000/api/add_${sportNameUrl}_match';
    
    try {
      final List<String> teamAPlayers = _teamAPlayerControllers
          .map((c) => c.text).where((name) => name.isNotEmpty).toList();

      final List<String> teamBPlayers = _teamBPlayerControllers
          .map((c) => c.text).where((name) => name.isNotEmpty).toList();
      
      Map<String, dynamic> matchData = {
        'team_a_name': _teamANameController.text,
        'team_b_name': _teamBNameController.text,
        'team_a_players': teamAPlayers,
        'team_b_players': teamBPlayers,
        'start_time': _startTimeController.text,
        'venue': _venueController.text,
      };

      if (widget.sportName == 'Athletics') {
         // --- Athletics Specific Data ---
         final List<String> teamCPlayers = _teamCPlayerControllers
            .map((c) => c.text).where((name) => name.isNotEmpty).toList();
         
         matchData['team_c_name'] = _teamCNameController.text;
         matchData['team_c_players'] = teamCPlayers;
         
         final List<String> officials = _refereesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
         matchData['officials'] = officials;
         // Use Team A Name field as "Event Category" for Athletics usually, 
         // but since we have 3 teams, we might map it differently or add a field.
         // Assuming backend expects 'event_category' separately or we reuse a field.
         // Let's assume user enters Event Name in Team A Name based on UI flow, 
         // BUT wait, we need actual Team Names. 
         // Let's add a specific field for 'Event Category' in _buildMatchInfoPage if needed,
         // or repurpose one. For now, let's keep it standard.
         matchData['event_category'] = "Track Event"; // Default or add field
      } 
      // ... [Other sports logic remains same] ...
      else if (widget.sportName == 'Cricket') {
        final List<String> umpires = _umpiresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['overs'] = _oversController.text;
        matchData['umpires'] = umpires;
      } else if (widget.sportName == 'Basketball') {
        final List<String> umpires = _umpiresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        matchData['umpires'] = umpires;
        matchData['category'] = _basketballCategory;
        matchData['total_quarters'] = int.tryParse(_totalQuartersController.text) ?? 4;
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
      } else if (widget.sportName == 'Chess') {
         final List<String> umpires = _umpiresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
         matchData['umpires'] = umpires;
         matchData['player_a_selected'] = _selectedPlayerA;
         matchData['player_b_selected'] = _selectedPlayerB;
      } else if (widget.sportName == 'Carrom') {
         final List<String> umpires = _umpiresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
         matchData['umpires'] = umpires;
      } else if (widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') {
         final List<String> umpires = _umpiresController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
         matchData['umpires'] = umpires;
         matchData['total_sets'] = _totalSets;
         matchData['category'] = _category;
         
         if (_category == 'doubles') {
            matchData['player_a_selected'] = "$_selectedPlayerA & $_selectedPlayerA2";
            matchData['player_b_selected'] = "$_selectedPlayerB & $_selectedPlayerB2";
         } else {
            matchData['player_a_selected'] = _selectedPlayerA;
            matchData['player_b_selected'] = _selectedPlayerB;
         }
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

  // --- UPDATED: Page Logic to handle 4 pages for Athletics ---
  Widget _getCurrentPage() {
    final isAthletics = widget.sportName == 'Athletics';
    
    if (isAthletics) {
       switch (_currentPage) {
         case 0: return _buildTeamPage('A', _teamANameController, _teamAPlayerControllers);
         case 1: return _buildTeamPage('B', _teamBNameController, _teamBPlayerControllers);
         case 2: return _buildTeamPage('C', _teamCNameController, _teamCPlayerControllers);
         case 3: return _buildMatchInfoPage();
         default: return Container(key: const ValueKey('empty'));
       }
    } else {
       // Standard 3 Pages for other sports
       switch (_currentPage) {
         case 0: return _buildTeamPage('A', _teamANameController, _teamAPlayerControllers);
         case 1: return _buildTeamPage('B', _teamBNameController, _teamBPlayerControllers);
         case 2: return _buildMatchInfoPage();
         default: return Container(key: const ValueKey('empty'));
       }
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

  // --- UPDATED: Progress Indicator for 4 Steps in Athletics ---
  Widget _buildProgressIndicator() {
    final isAthletics = widget.sportName == 'Athletics';
    final titles = isAthletics 
        ? ['Team A', 'Team B', 'Team C', 'Info'] 
        : ['Team A', 'Team B', 'Match Info'];
        
    int visualIndex = _currentPage;
    final int steps = titles.length;

    final double screenWidth = MediaQuery.of(context).size.width - 88; 
    final double progressWidth = (visualIndex / (steps - 1)) * screenWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Align(alignment: Alignment.centerLeft, child: AnimatedContainer(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, height: 4, width: progressWidth, margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(2)))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(steps, (index) {
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
            children: List.generate(steps, (index) {
              final bool isActive = index <= visualIndex;
              TextAlign align = index == 0 ? TextAlign.left : (index == steps - 1 ? TextAlign.right : TextAlign.center);
              return Expanded(child: Text(titles[index], textAlign: align, style: TextStyle(fontSize: 12, color: isActive ? Colors.black87 : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)));
            }),
          )
        ],
      ),
    );
  }

  Widget _buildTeamPage(String teamLabel, TextEditingController teamNameController, List<TextEditingController> playerControllers) {
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    
    final nameLabel = 'Enter Team $teamLabel Name';
    final headerLabel = 'Team $teamLabel Name';
    final listHeader = 'Team $teamLabel Players (${playerCounts['players']})';

    return SingleChildScrollView(
      key: PageStorageKey('team_$teamLabel'),
      child: _AnimatedColumn(
        key: ValueKey('team_anim_$teamLabel'),
        children: [
          _buildSectionHeader(headerLabel),
          _buildTextFormField(controller: teamNameController, label: nameLabel, icon: Icons.group_outlined),
          const SizedBox(height: 16),
          _buildSectionHeader(listHeader),
          ...List.generate(playerControllers.length, (index) {
              String pLabel;
              if (widget.sportName == 'Athletics') {
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
    List<String> getTeamPlayerNames(List<TextEditingController> controllers) {
        return controllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
    }
    
    List<DropdownMenuItem<String>> getPlayerDropdownItems(List<String> names) {
        if (names.isEmpty) {
            return [const DropdownMenuItem(value: null, child: Text("No players entered"))];
        }
        return names.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList();
    }

    switch (widget.sportName) {
      case 'Basketball':
        return [
           Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: DropdownButtonFormField<String>(
               value: _basketballCategory, 
               decoration: InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
               items: const [DropdownMenuItem(value: 'full_game', child: Text('Full Game')), DropdownMenuItem(value: 'half_game', child: Text('Half Game'))],
               onChanged: (val) => setState(() => _basketballCategory = val!),
             )),
           _buildTextFormField(controller: _totalQuartersController, label: 'Total Quarters', icon: Icons.timer, keyboardType: TextInputType.number),
           _buildTextFormField(controller: _umpiresController, label: 'Umpire(s) (comma-separated)', icon: Icons.sports),
        ];
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
        // For athletics, add specific event category field if desired, or repurpose existing fields.
        return [
           // Just the Official/Timekeeper field is usually enough for simple athletics
           _buildTextFormField(controller: _refereesController, label: 'Official / Timekeeper', icon: Icons.timer_outlined)
        ];
      case 'Chess':
      case 'Carrom':
      case 'Table Tennis': 
      case 'Badminton':
        List<String> teamANames = getTeamPlayerNames(_teamAPlayerControllers);
        List<String> teamBNames = getTeamPlayerNames(_teamBPlayerControllers);
        
        return [
           if (widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') ...[
             Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: DropdownButtonFormField<String>(
                 value: _category, decoration: InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                 items: const [DropdownMenuItem(value: 'singles', child: Text('Singles')), DropdownMenuItem(value: 'doubles', child: Text('Doubles'))],
                 onChanged: (val) => setState(() => _category = val!),
               )),
             Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: DropdownButtonFormField<int>(
                 value: _totalSets, decoration: InputDecoration(labelText: 'Total Sets', prefixIcon: Icon(Icons.format_list_numbered, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                 items: const [DropdownMenuItem(value: 3, child: Text('Best of 3')), DropdownMenuItem(value: 5, child: Text('Best of 5'))],
                 onChanged: (val) => setState(() => _totalSets = val!),
               )),
           ],

           if(widget.sportName != 'Carrom') ...[
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 8.0),
               child: DropdownButtonFormField<String>(
                 value: _selectedPlayerA,
                 decoration: InputDecoration(labelText: 'Select Player 1 (Team A)', prefixIcon: Icon(Icons.person_pin, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                 items: getPlayerDropdownItems(teamANames),
                 onChanged: (val) => setState(() => _selectedPlayerA = val),
                 validator: (val) => val == null ? 'Please select Player 1 for Team A' : null,
               ),
             ),
             
             if ((widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') && _category == 'doubles')
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 child: DropdownButtonFormField<String>(
                   value: _selectedPlayerA2,
                   decoration: InputDecoration(labelText: 'Select Player 2 (Team A)', prefixIcon: Icon(Icons.person_add_alt_1, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                   items: getPlayerDropdownItems(teamANames),
                   onChanged: (val) => setState(() => _selectedPlayerA2 = val),
                   validator: (val) => val == null ? 'Please select Player 2 for Team A' : null,
                 ),
               ),

             Padding(
               padding: const EdgeInsets.symmetric(vertical: 8.0),
               child: DropdownButtonFormField<String>(
                 value: _selectedPlayerB,
                 decoration: InputDecoration(labelText: 'Select Player 1 (Team B)', prefixIcon: Icon(Icons.person_pin, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                 items: getPlayerDropdownItems(teamBNames),
                 onChanged: (val) => setState(() => _selectedPlayerB = val),
                 validator: (val) => val == null ? 'Please select Player 1 for Team B' : null,
               ),
             ),

             if ((widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') && _category == 'doubles')
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 child: DropdownButtonFormField<String>(
                   value: _selectedPlayerB2,
                   decoration: InputDecoration(labelText: 'Select Player 2 (Team B)', prefixIcon: Icon(Icons.person_add_alt_1, color: Colors.grey[600], size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                   items: getPlayerDropdownItems(teamBNames),
                   onChanged: (val) => setState(() => _selectedPlayerB2 = val),
                   validator: (val) => val == null ? 'Please select Player 2 for Team B' : null,
                 ),
               ),
           ],

           _buildTextFormField(controller: _umpiresController, label: 'Umpire(s)', icon: Icons.person),
        ];
      default:
        return [];
    }
  }

  // --- UPDATED: Navigation Buttons to handle 4 pages logic ---
  Widget _buildNavigationButtons() {
    final isAthletics = widget.sportName == 'Athletics';
    final int maxPages = isAthletics ? 3 : 2; // 0-based index (0,1,2,3 for athletics; 0,1,2 for others)

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
                _currentPage--;
              });
            },
          ),
        const Spacer(),
        ElevatedButton.icon(
          icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward),
          label: Text(_currentPage == maxPages ? 'Save Match' : 'Next'),
          onPressed: _isLoading ? null : () {
            if (_currentPage < maxPages) {
              setState(() {
                _navigationDirection = 1.0;
                _currentPage++;
              });
            } else {
              _saveMatch();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Map<String, int> _getSportPlayerCounts(String sportName) {
    switch (sportName) {
      case 'Basketball': return {'players': 10, 'subs': 5};
      case 'Cricket': return {'players': 11, 'subs': 4};
      case 'Football': return {'players': 11, 'subs': 5};
      case 'Kabaddi': return {'players': 7, 'subs': 5};
      case 'Volleyball': return {'players': 6, 'subs': 6};
      case 'Athletics': return {'players': 5, 'subs': 0}; 
      case 'Chess': return {'players': 5, 'subs': 0};
      case 'Carrom': return {'players': 5, 'subs': 0}; 
      case 'Table Tennis': return {'players': 5, 'subs': 0};
      case 'Badminton': return {'players': 5, 'subs': 0};
      default: return {'players': 1, 'subs': 0};
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(top: 20.0, bottom: 8.0), child: Text(title, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16)));
  }

  Widget _buildTextFormField({required String label, IconData? icon, TextEditingController? controller, TextInputType? keyboardType, bool isRequired = true, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller, keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, helperText: helperText, 
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), 
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2)),
          filled: true, fillColor: Colors.white
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

class _AnimatedColumnState extends State<_AnimatedColumn> with SingleTickerProviderStateMixin {
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