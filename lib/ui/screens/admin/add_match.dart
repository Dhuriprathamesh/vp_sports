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

  late final TextEditingController _teamANameController;
  late final TextEditingController _teamBNameController;
  late final List<TextEditingController> _teamAPlayerControllers;
  late final List<TextEditingController> _teamBPlayerControllers;
  late final TextEditingController _oversController;
  late final TextEditingController _venueController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _umpiresController;

  @override
  void initState() {
    super.initState();
    _teamANameController = TextEditingController();
    _teamBNameController = TextEditingController();
    _oversController = TextEditingController();
    _venueController = TextEditingController();
    // Set a default time for user convenience
    _startTimeController = TextEditingController(
        text: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().add(const Duration(days: 1))));
    _umpiresController = TextEditingController();

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
    _oversController.dispose();
    _venueController.dispose();
    _startTimeController.dispose();
    _umpiresController.dispose();
    for (var controller in _teamAPlayerControllers) {
      controller.dispose();
    }
    for (var controller in _teamBPlayerControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _saveMatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);

    final String host = kIsWeb ? 'localhost' : '10.0.2.2';
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
      
      final List<String> umpires = _umpiresController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final Map<String, dynamic> matchData = {
        'team_a_name': _teamANameController.text,
        'team_b_name': _teamBNameController.text,
        'team_a_players': teamAPlayers,
        'team_b_players': teamBPlayers,
        'overs': _oversController.text,
        'start_time': _startTimeController.text,
        'venue': _venueController.text,
        'umpires': umpires,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(matchData),
      );

      if (mounted) {
          if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Match added successfully!'), backgroundColor: Colors.green),
            );
            // MODIFIED: Pop with a 'true' result to signal success
            Navigator.of(context).pop(true);
          } else {
            final responseBody = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${responseBody['message']}'), backgroundColor: Colors.red),
            );
          }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to server: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
       insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ));
                  
                  final scaleIn = Tween<double>(begin: 0.98, end: 1.0).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic));

                  return ScaleTransition(
                    scale: scaleIn,
                    child: SlideTransition(
                      position: slideIn,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
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
    switch (_currentPage) {
      case 0:
        return _buildTeamPage(
            'A', _teamANameController, _teamAPlayerControllers);
      case 1:
        return _buildTeamPage(
            'B', _teamBNameController, _teamBPlayerControllers);
      case 2:
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
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final titles = ['Team A', 'Team B', 'Match Info'];
    final double screenWidth =
        MediaQuery.of(context).size.width - 88; // Dialog's horizontal padding
    final double progressWidth =
        (_currentPage / (titles.length - 1)) * screenWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 4,
                  width: progressWidth,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(titles.length, (index) {
                  final bool isCompleted = index < _currentPage;
                  final bool isActive = index == _currentPage;
                  final color = isCompleted
                      ? Colors.green
                      : (isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300);

                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(titles.length, (index) {
              final bool isActive = index <= _currentPage;
              TextAlign align;
              if (index == 0) {
                align = TextAlign.left;
              } else if (index == titles.length - 1) {
                align = TextAlign.right;
              } else {
                align = TextAlign.center;
              }
              return Expanded(
                child: Text(
                  titles[index],
                  textAlign: align,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.black87 : Colors.grey,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildTeamPage(
      String teamLabel,
      TextEditingController teamNameController,
      List<TextEditingController> playerControllers) {
    final playerCounts = _getSportPlayerCounts(widget.sportName);
    return SingleChildScrollView(
      key: PageStorageKey('team_$teamLabel'),
      child: _AnimatedColumn(
        key: ValueKey('team_anim_$teamLabel'),
        children: [
          _buildSectionHeader('Team $teamLabel Name'),
          _buildTextFormField(
            controller: teamNameController,
            label: 'Enter Team $teamLabel Name',
            icon: Icons.group_outlined,
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Team $teamLabel Players'),
          ..._buildPlayerInputFields(
            playerControllers,
            playerCounts['players']!,
            playerCounts['subs']!,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlayerInputFields(
      List<TextEditingController> controllers, int playerCount, int subCount) {
    return List.generate(controllers.length, (index) {
      final String label = index < playerCount
          ? 'Player ${index + 1}'
          : 'Substitute ${index - playerCount + 1}';
      return _buildTextFormField(
        controller: controllers[index],
        label: label,
        icon: Icons.person_outline,
        isRequired: false,
      );
    });
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
          ],
        ),
      ),
    );
  }

  List<Widget> _getSportSpecificMatchInfoFields() {
    switch (widget.sportName) {
      case 'Cricket':
        return [
          _buildResponsiveFormFieldRow(
            _buildTextFormField(
                controller: _oversController,
                label: 'Overs', icon: Icons.sports_cricket_outlined, keyboardType: TextInputType.number),
            _buildTextFormField(
                controller: _venueController,
                label: 'Venue', icon: Icons.location_on_outlined),
          ),
          _buildTextFormField(
              controller: _startTimeController,
              label: 'Start Time (YYYY-MM-DD HH:MM:SS)', icon: Icons.schedule_outlined),
          _buildTextFormField(
              controller: _umpiresController,
              label: 'Umpire(s) (comma-separated)', icon: Icons.sports),
        ];
      default:
        return [
          _buildTextFormField(
            label: 'Venue',
            controller: _venueController,
            icon: Icons.location_on_outlined,
          ),
           _buildTextFormField(
              controller: _startTimeController,
              label: 'Start Time (YYYY-MM-DD HH:MM:SS)', icon: Icons.schedule_outlined),
        ];
    }
  }

  Widget _buildNavigationButtons() {
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
          icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_currentPage == 2
              ? Icons.save_alt_outlined
              : Icons.arrow_forward),
          label: Text(_currentPage == 2 ? 'Save Match' : 'Next'),
          onPressed: _isLoading ? null : () {
            if (_currentPage < 2) {
              setState(() {
                _navigationDirection = 1.0;
                _currentPage++;
              });
            } else {
              _saveMatch();
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, int> _getSportPlayerCounts(String sportName) {
    switch (sportName) {
      case 'Cricket':
        return {'players': 11, 'subs': 4};
      default:
        return {'players': 11, 'subs': 4};
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 16),
      ),
    );
  }

  Widget _buildResponsiveFormFieldRow(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
          return Column(children: [left, right]);
        }
      },
    );
  }

  Widget _buildTextFormField(
      {required String label,
      IconData? icon,
      TextEditingController? controller,
      TextInputType? keyboardType,
      bool isRequired = true,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            borderSide:
                BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: (value) {
          if (isRequired && (value?.isEmpty ?? true)) {
            return 'This field is required';
          }
          return null;
        }
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
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + (widget.children.length * 80)),
    );
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
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut),
            ),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut),
              ),
            ),
            child: widget.children[index],
          ),
        );
      }),
    );
  }
}

