import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Core Imports
import '../../../core/api_constants.dart';

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
  bool _isSyncing = false;
  bool _isFetchingPlayers = false; 

  // --- Dynamic Player Lists Fetched from DB ---
  List<String> _teamAPlayersList = [];
  List<String> _teamBPlayersList = [];
  List<String> _teamCPlayersList = []; // For Athletics

  // --- Selected Departments (Team Names) ---
  String? _selectedDeptA;
  String? _selectedDeptB;
  String? _selectedDeptC;

  // Controllers (Used to store selected values for submission)
  late final TextEditingController _teamANameController;
  late final TextEditingController _teamBNameController;
  late final TextEditingController _teamCNameController;
  
  // List of controllers for the player slots
  late final List<TextEditingController> _teamAPlayerControllers;
  late final List<TextEditingController> _teamBPlayerControllers;
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
  String _category = 'singles'; 
  int _totalSets = 3;
  
  String? _selectedPlayerA;
  String? _selectedPlayerB;
  String? _selectedPlayerA2;
  String? _selectedPlayerB2;

  @override
  void initState() {
    super.initState();
    _teamANameController = TextEditingController();
    _teamBNameController = TextEditingController();
    _teamCNameController = TextEditingController();
    _venueController = TextEditingController();
    
    // Default start time: tomorrow
    _startTimeController = TextEditingController(
        text: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().add(const Duration(days: 1))));
    
    _oversController = TextEditingController();
    _umpiresController = TextEditingController();
    _matchDurationController = TextEditingController(text: widget.sportName == 'Kabaddi' ? "40" : "90");
    _refereesController = TextEditingController();

    // Determine how many player slots we need based on sport
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final totalPlayers = playerCounts['players']! + playerCounts['subs']!;
    
    _teamAPlayerControllers = List.generate(totalPlayers, (_) => TextEditingController());
    _teamBPlayerControllers = List.generate(totalPlayers, (_) => TextEditingController());
    _teamCPlayerControllers = List.generate(totalPlayers, (_) => TextEditingController());
  }

  // --- API: Fetch Players for a specific team/dept ---
  // This is called when the Team Name Dropdown changes
  Future<void> _fetchPlayersForTeam(String teamName, String targetList) async {
    setState(() => _isFetchingPlayers = true);
    
    // e.g. /api/get_players_by_team?team=CO&sport=Cricket
    final String apiUrl = '${ApiConstants.baseUrl}/api/get_players_by_team?team=$teamName&sport=${widget.sportName}';
    
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        // Expecting a simple list of strings: ["Player 1", "Player 2", ...]
        List<dynamic> data = json.decode(response.body);
        List<String> names = data.map((e) => e.toString()).toSet().toList(); // Remove duplicates
        names.sort(); // Sort alphabetically
        
        if (mounted) {
          setState(() {
            if (targetList == 'A') _teamAPlayersList = names;
            if (targetList == 'B') _teamBPlayersList = names;
            if (targetList == 'C') _teamCPlayersList = names;
          });
        }
      } else {
         debugPrint("Failed to fetch players: ${response.body}");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load players for $teamName'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Error fetching players: $e");
    } finally {
      if(mounted) setState(() => _isFetchingPlayers = false);
    }
  }

  // --- API: Sync DB from Google Sheets ---
  Future<void> _syncPlayersWithSheets() async {
    setState(() => _isSyncing = true);
    final String apiUrl = '${ApiConstants.baseUrl}/api/sync_players?sport=${widget.sportName}';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Players Synced Successfully!'), backgroundColor: Colors.green));
          
          // Refresh lists if teams are already selected
          if (_selectedDeptA != null) _fetchPlayersForTeam(_selectedDeptA!, 'A');
          if (_selectedDeptB != null) _fetchPlayersForTeam(_selectedDeptB!, 'B');
          if (_selectedDeptC != null) _fetchPlayersForTeam(_selectedDeptC!, 'C');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync Failed. Check backend console.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _teamANameController.dispose(); _teamBNameController.dispose(); _teamCNameController.dispose();
    _venueController.dispose(); _startTimeController.dispose(); _oversController.dispose();
    _umpiresController.dispose(); _matchDurationController.dispose(); _refereesController.dispose();
    _totalQuartersController.dispose();
    for (var c in _teamAPlayerControllers) c.dispose();
    for (var c in _teamBPlayerControllers) c.dispose();
    for (var c in _teamCPlayerControllers) c.dispose();
    super.dispose();
  }
  
  Future<void> _saveMatch() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final sportNameUrl = widget.sportName.toLowerCase().replaceAll(' ', '_'); 
    final String apiUrl = '${ApiConstants.baseUrl}/api/add_${sportNameUrl}_match';
    
    try {
      // Gather selected player names from controllers
      final List<String> teamAPlayers = _teamAPlayerControllers.map((c) => c.text).where((name) => name.isNotEmpty).toList();
      final List<String> teamBPlayers = _teamBPlayerControllers.map((c) => c.text).where((name) => name.isNotEmpty).toList();
      
      Map<String, dynamic> matchData = {
        'team_a_name': _teamANameController.text,
        'team_b_name': _teamBNameController.text,
        'team_a_players': teamAPlayers,
        'team_b_players': teamBPlayers,
        'start_time': _startTimeController.text,
        'venue': _venueController.text,
      };

      // --- Sport Specific Logic ---
      if (widget.sportName == 'Athletics') {
         final List<String> teamCPlayers = _teamCPlayerControllers.map((c) => c.text).where((name) => name.isNotEmpty).toList();
         matchData['team_c_name'] = _teamCNameController.text;
         matchData['team_c_players'] = teamCPlayers;
         matchData['officials'] = _refereesController.text.split(',');
         matchData['event_category'] = "Track Event"; 
      } else if (widget.sportName == 'Cricket') {
        matchData['overs'] = _oversController.text;
        matchData['umpires'] = _umpiresController.text.split(',');
      } else if (widget.sportName == 'Basketball') {
        matchData['umpires'] = _umpiresController.text.split(',');
        matchData['category'] = _basketballCategory;
        matchData['total_quarters'] = int.tryParse(_totalQuartersController.text) ?? 4;
      } else if (widget.sportName == 'Football') {
        matchData['match_duration'] = _matchDurationController.text;
        matchData['referees'] = _refereesController.text.split(',');
      } else if (widget.sportName == 'Kabaddi') {
        matchData['match_duration'] = _matchDurationController.text;
        matchData['officials'] = _refereesController.text.split(',');
      } else if (widget.sportName == 'Volleyball') {
        matchData['match_format'] = _volleyballFormat; 
        matchData['officials'] = _refereesController.text.split(',');
      } else if (widget.sportName == 'Chess' || widget.sportName == 'Carrom' || widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') {
         matchData['umpires'] = _umpiresController.text.split(',');
         if (widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') {
            matchData['total_sets'] = _totalSets;
            matchData['category'] = _category;
            
            if (_category == 'doubles') {
               // Combine names for doubles if 2 players are selected
               if (_teamAPlayerControllers.length >= 2 && _teamBPlayerControllers.length >= 2) {
                   matchData['player_a_selected'] = "${_teamAPlayerControllers[0].text} & ${_teamAPlayerControllers[1].text}";
                   matchData['player_b_selected'] = "${_teamBPlayerControllers[0].text} & ${_teamBPlayerControllers[1].text}";
               }
            } else {
               if (_teamAPlayerControllers.isNotEmpty) matchData['player_a_selected'] = _teamAPlayerControllers[0].text;
               if (_teamBPlayerControllers.isNotEmpty) matchData['player_b_selected'] = _teamBPlayerControllers[0].text;
            }
         } else if (widget.sportName == 'Chess') {
             if (_teamAPlayerControllers.isNotEmpty) matchData['player_a_selected'] = _teamAPlayerControllers[0].text;
             if (_teamBPlayerControllers.isNotEmpty) matchData['player_b_selected'] = _teamBPlayerControllers[0].text;
         }
      }

      final response = await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: json.encode(matchData));
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
        height: MediaQuery.of(context).size.height * 0.90,
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            
            // --- SYNC BUTTON ---
            if (_currentPage < (widget.sportName == 'Athletics' ? 3 : 2)) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncPlayersWithSheets,
                    icon: _isSyncing 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                      : const Icon(Icons.sync, size: 16),
                    label: Text(_isSyncing ? "Syncing..." : "Sync from Google Forms", style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade200,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                  ),
                ),
              ),

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
      case 0: return _buildTeamPage(isAthletics ? 'Event' : 'A', _teamANameController, _teamAPlayerControllers, _teamAPlayersList);
      case 1: return _buildTeamPage('B', _teamBNameController, _teamBPlayerControllers, _teamBPlayersList);
      case 2: return isAthletics ? _buildTeamPage('C', _teamCNameController, _teamCPlayerControllers, _teamCPlayersList) : _buildMatchInfoPage();
      case 3: return _buildMatchInfoPage();
      default: return Container(key: const ValueKey('empty'));
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
    final titles = isAthletics 
        ? ['Team A', 'Team B', 'Team C', 'Info'] 
        : ['Team A', 'Team B', 'Match Info'];
        
    int visualIndex = _currentPage;
    final int steps = titles.length;

    final double screenWidth = MediaQuery.of(context).size.width - 88; 
    final double progressWidth = (visualIndex / (steps - 1)) * screenWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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

  // --- UPDATED: Build Team Page with Filtered Dropdowns ---
  Widget _buildTeamPage(String teamLabel, TextEditingController teamNameController, List<TextEditingController> playerControllers, List<String> availablePlayers) {
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    final int playingCount = playerCounts['players']!;
    final isAthletics = widget.sportName == 'Athletics';
    
    final nameLabel = isAthletics && teamLabel == 'Event' ? "Enter Event Name" : 'Select Team $teamLabel Department';
    final headerLabel = isAthletics && teamLabel == 'Event' ? "Event Name" : 'Team $teamLabel Name';
    final listHeader = isAthletics ? "Participants" : 'Team $teamLabel Players (${playingCount} Playing + ${playerCounts['subs']} Subs)';

    return SingleChildScrollView(
      key: PageStorageKey('team_$teamLabel'),
      child: _AnimatedColumn(
        key: ValueKey('team_anim_$teamLabel'),
        children: [
          _buildSectionHeader(headerLabel),
          
          // --- TEAM NAME DROPDOWN ---
          DropdownButtonFormField<String>(
            value: (teamLabel == 'A' ? _selectedDeptA : (teamLabel == 'B' ? _selectedDeptB : _selectedDeptC)),
            decoration: const InputDecoration(
              labelText: "Department",
              prefixIcon: Icon(Icons.group),
              border: OutlineInputBorder(), 
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              filled: true, fillColor: Colors.white
            ),
            hint: const Text("Choose Department (CO, IF, EJ)"),
            items: ['CO', 'IF', 'EJ'].map((dept) => DropdownMenuItem(value: dept, child: Text(dept))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  teamNameController.text = val;
                  if (teamLabel == 'A') _selectedDeptA = val;
                  else if (teamLabel == 'B') _selectedDeptB = val;
                  else _selectedDeptC = val;
                  
                  // Fetch and Auto-Fill players
                  _fetchPlayersForTeam(val, teamLabel); 
                  
                  // Clear previous player selections to avoid mismatches
                  for(var c in playerControllers) c.clear();
                });
              }
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader(listHeader),
          
          // --- PLAYERS LIST with DUPLICATE FILTERING ---
          if (_isFetchingPlayers) 
             const Padding(
               padding: EdgeInsets.all(20.0),
               child: Center(child: CircularProgressIndicator()),
             )
          else
             ...List.generate(playerControllers.length, (index) {
                final bool isSub = index >= playingCount;
                final String label = isAthletics 
                    ? "Runner ${index + 1}"
                    : (isSub ? "Substitute ${index - playingCount + 1}" : "Player ${index + 1}");

                // 1. Identify values already selected in OTHER dropdowns for this team
                Set<String> selectedByOthers = {};
                for (int i = 0; i < playerControllers.length; i++) {
                  if (i != index && playerControllers[i].text.isNotEmpty) {
                    selectedByOthers.add(playerControllers[i].text);
                  }
                }

                // 2. Create a list excluding those already selected
                List<String> filteredPlayers = availablePlayers.where((p) {
                  // Include if not selected elsewhere, OR if it is the currently selected value for THIS dropdown
                  return !selectedByOthers.contains(p) || p == playerControllers[index].text;
                }).toList();

                // 3. Validate current value against new list
                String? currentValue = playerControllers[index].text;
                if (currentValue.isEmpty || !filteredPlayers.contains(currentValue)) {
                   currentValue = null;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: DropdownButtonFormField<String>(
                    value: currentValue,
                    decoration: InputDecoration(
                      labelText: label,
                      prefixIcon: Icon(isSub ? Icons.person_outline : Icons.person),
                      border: const OutlineInputBorder(), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      filled: true, fillColor: Colors.white
                    ),
                    hint: const Text("Select Player"),
                    // Use filtered list here
                    items: filteredPlayers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      setState(() {
                        // If this player was selected in another slot, clear that slot to prevent duplicates
                        for (int i = 0; i < playerControllers.length; i++) {
                           if (i != index && playerControllers[i].text == val) {
                              playerControllers[i].clear(); 
                           }
                        }
                        playerControllers[index].text = val ?? '';
                      });
                    },
                  ),
                );
             })
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }

  Widget _buildMatchInfoPage() {
      return SingleChildScrollView(
        key: const PageStorageKey('match_info'),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('Match Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._getSportSpecificMatchInfoFields(),
              const SizedBox(height: 10),
              _buildTextFormField(label: 'Venue', controller: _venueController, icon: Icons.location_on_outlined),
              _buildTextFormField(controller: _startTimeController, label: 'Start Time', icon: Icons.schedule_outlined),
            ],
          ),
        ),
      );
  }
  
  Widget _buildNavigationButtons() {
    final int maxPages = widget.sportName == 'Athletics' ? 3 : 2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentPage > 0)
          TextButton.icon(
            onPressed: () {
               setState(() {
                 _navigationDirection = -1.0;
                 _currentPage--;
               });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back")
          ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () {
            if (_currentPage < maxPages) {
               setState(() {
                 _navigationDirection = 1.0;
                 _currentPage++;
               });
            } else {
               _saveMatch();
            }
          },
          icon: Icon(_currentPage == maxPages ? Icons.save : Icons.arrow_forward),
          label: Text(_currentPage == maxPages ? "Save Match" : "Next"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
        )
      ],
    );
  }
  
  Map<String, int> _getSportPlayerCounts(String sportName) {
    switch (sportName) {
      case 'Basketball': return {'players': 5, 'subs': 3}; 
      case 'Cricket': return {'players': 11, 'subs': 2};
      case 'Football': return {'players': 11, 'subs': 3};
      case 'Kabaddi': return {'players': 7, 'subs': 3};
      case 'Volleyball': return {'players': 6, 'subs': 3};
      case 'Athletics': return {'players': 5, 'subs': 0}; 
      case 'Chess': return {'players': 1, 'subs': 0}; 
      case 'Carrom': return {'players': 2, 'subs': 0}; 
      case 'Table Tennis': return {'players': 2, 'subs': 0};
      case 'Badminton': return {'players': 2, 'subs': 0};
      default: return {'players': 1, 'subs': 0};
    }
  }

  List<Widget> _getSportSpecificMatchInfoFields() {
     List<Widget> fields = [];
     if(widget.sportName == 'Cricket') {
       fields.add(_buildTextFormField(controller: _oversController, label: 'Overs', icon: Icons.sports_cricket));
       fields.add(const SizedBox(height: 12));
       fields.add(_buildTextFormField(controller: _umpiresController, label: 'Umpires (comma separated)', icon: Icons.people));
     } else if(widget.sportName == 'Football' || widget.sportName == 'Kabaddi') {
       fields.add(_buildTextFormField(controller: _matchDurationController, label: 'Duration (mins)', icon: Icons.timer));
       fields.add(const SizedBox(height: 12));
       fields.add(_buildTextFormField(controller: _refereesController, label: 'Referees/Officials', icon: Icons.people));
     } else if (widget.sportName == 'Basketball') {
       fields.add(_buildTextFormField(controller: _totalQuartersController, label: 'Total Quarters', icon: Icons.timer));
       fields.add(const SizedBox(height: 12));
       fields.add(_buildTextFormField(controller: _umpiresController, label: 'Umpires', icon: Icons.people));
     } else if (widget.sportName == 'Volleyball') {
       fields.add(DropdownButtonFormField<String>(
          value: _volleyballFormat,
          decoration: const InputDecoration(labelText: "Match Format", border: OutlineInputBorder(), prefixIcon: Icon(Icons.sports_volleyball)),
          items: const [DropdownMenuItem(value: "Best of 3 Sets", child: Text("Best of 3 Sets")), DropdownMenuItem(value: "Best of 5 Sets", child: Text("Best of 5 Sets"))],
          onChanged: (v) => setState(() => _volleyballFormat = v!),
       ));
       fields.add(const SizedBox(height: 12));
       fields.add(_buildTextFormField(controller: _refereesController, label: 'Referees', icon: Icons.people));
     } else if (widget.sportName == 'Table Tennis' || widget.sportName == 'Badminton') {
        fields.add(DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
          items: const [DropdownMenuItem(value: "singles", child: Text("Singles")), DropdownMenuItem(value: "doubles", child: Text("Doubles"))],
          onChanged: (v) => setState(() => _category = v!),
       ));
       fields.add(const SizedBox(height: 12));
       fields.add(DropdownButtonFormField<int>(
          value: _totalSets,
          decoration: const InputDecoration(labelText: "Total Sets", border: OutlineInputBorder(), prefixIcon: Icon(Icons.format_list_numbered)),
          items: const [DropdownMenuItem(value: 3, child: Text("Best of 3")), DropdownMenuItem(value: 5, child: Text("Best of 5"))],
          onChanged: (v) => setState(() => _totalSets = v!),
       ));
       fields.add(const SizedBox(height: 12));
       fields.add(_buildTextFormField(controller: _umpiresController, label: 'Umpires', icon: Icons.people));
     } else {
       // Generic fields for others
       fields.add(_buildTextFormField(controller: _umpiresController, label: 'Officials/Umpires', icon: Icons.people));
     }
     return fields;
  }

  Widget _buildTextFormField({required String label, IconData? icon, TextEditingController? controller, TextInputType? keyboardType}) {
      return TextFormField(
        controller: controller, 
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, 
          prefixIcon: Icon(icon), 
          border: const OutlineInputBorder(),
          filled: true, fillColor: Colors.white
        ),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      );
  }
}

// Helper class for animation
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _controller.forward();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.children.length, (index) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut))),
          child: widget.children[index],
        );
      }),
    );
  }
}