import 'package:flutter/material.dart';
import 'dart:convert'; // Ensures 'json' is defined
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../../../core/app_theme.dart';
import 'admin_update_score_screen.dart'; // Import the new screen

class LiveCricketScoreScreen extends StatefulWidget {
  final int matchId;
  final String sportName;
  final String teamAName;
  final String teamBName;
  final bool isForBoys;
  final Function(bool) onGenderToggle;
  final bool isAdmin;

  const LiveCricketScoreScreen({
    super.key,
    required this.matchId,
    required this.sportName,
    required this.teamAName,
    required this.teamBName,
    required this.isForBoys,
    required this.onGenderToggle,
    required this.isAdmin,
  });

  @override
  State<LiveCricketScoreScreen> createState() => _LiveCricketScoreScreenState();
}

class _LiveCricketScoreScreenState extends State<LiveCricketScoreScreen> {
  Map<String, dynamic>? _liveScoreData;
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _pollingTimer;
  bool _isDetailsExpanded = false;

  // --- MOCK Scorecard Data ---
  // Team A Batting Data
  final List<Map<String, String>> _teamABatting = [
    {'name': 'S. Khan', 'dismissal': 'c Player B b Bowler X', 'runs': '48', 'balls': '32'},
    {'name': 'A. Afridi', 'dismissal': 'not out', 'runs': '23', 'balls': '15'},
    {'name': 'Batter 3', 'dismissal': 'b Bowler Y', 'runs': '15', 'balls': '10'},
    {'name': 'Batter 4', 'dismissal': 'lbw b Bowler Z', 'runs': '5', 'balls': '8'},
    {'name': 'Batter 5', 'dismissal': 'run out (Player C)', 'runs': '30', 'balls': '25'},
  ];
  final String _teamAExtras = '10 (B 2, LB 4, Wd 3, Nb 1)';
  final List<String> _teamAFOW = [
    '25/1 (Batter 3, 4.2 ov)',
    '50/2 (Batter 4, 8.1 ov)',
    '100/3 (S. Khan, 15.3 ov)',
    '140/4 (Batter 5, 18.5 ov)',
  ];
   // Team B Bowling Data (Bowling against Team A)
   final List<Map<String, String>> _teamBBowling = [
    {'name': 'K. Maharaj', 'overs': '3.2', 'runs': '32', 'wickets': '1'},
    {'name': 'S. Muthusamy', 'overs': '3.0', 'runs': '28', 'wickets': '0'},
    {'name': 'Bowler X', 'overs': '4.0', 'runs': '40', 'wickets': '1'},
    {'name': 'Bowler Y', 'overs': '4.0', 'runs': '35', 'wickets': '1'},
    {'name': 'Bowler Z', 'overs': '4.0', 'runs': '37', 'wickets': '1'},
   ];

   // Team B Batting Data
   final List<Map<String, String>> _teamBBatting = [
    {'name': 'Player A', 'dismissal': 'c S. Khan b Afridi', 'runs': '20', 'balls': '15'},
    {'name': 'Player B', 'dismissal': 'not out', 'runs': '55', 'balls': '40'},
    {'name': 'Player C', 'dismissal': 'b Bowler 1', 'runs': '10', 'balls': '12'},
     {'name': 'Player D', 'dismissal': 'not out', 'runs': '5', 'balls': '8'},
   ];
   final String _teamBExtras = '8 (LB 2, Wd 6)';
   final List<String> _teamBFOW = [
    '30/1 (Player A, 5.1 ov)',
    '80/2 (Player C, 12.4 ov)',
   ];
   // Team A Bowling Data (Bowling against Team B)
   final List<Map<String, String>> _teamABowling = [
    {'name': 'A. Afridi', 'overs': '4.0', 'runs': '25', 'wickets': '1'},
    {'name': 'Bowler 1', 'overs': '4.0', 'runs': '30', 'wickets': '1'},
    {'name': 'Bowler 2', 'overs': '4.0', 'runs': '35', 'wickets': '0'},
    {'name': 'Bowler 3', 'overs': '4.0', 'runs': '28', 'wickets': '0'},
    {'name': 'S. Khan', 'overs': '4.0', 'runs': '20', 'wickets': '0'},
   ];
  // --- END MOCK ---


  int _selectedTeamIndex = 0; // 0 for Team A, 1 for Team B

  final List<String> _recentBalls = [
      // Example Data: Represents overs 17, 18, 19, 20 (OLDEST first for chronological display)
      '6', '0', '1', '1', '4', '0', // 17th
      'W', '0', '4', '2', '1', 'LB1', // 18th
      '0', '1', '6', '0', '0', '1', // 19th
      '1', '0', '2', '0', '4', 'W', // 20th
    ];

  // Dummy Player Lists (Replace with actual data fetch later)
   final List<Player> _dummyTeamAPlayers = List.generate(15, (i) => Player(id: 100+i, name: 'Team A Player ${i+1}'));
   final List<Player> _dummyTeamBPlayers = List.generate(15, (i) => Player(id: 200+i, name: 'Team B Player ${i+1}'));


  @override
  void initState() {
    super.initState();
    _fetchLiveScore();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchLiveScore(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveScore({bool isRefresh = false}) async {
     if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      const String host = kIsWeb ? 'localhost' : '10.0.2.2';
      final response = await http.get(
          Uri.parse('http://$host:5000/api/get_live_score/${widget.matchId}'));

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _liveScoreData = json.decode(response.body);
            _isLoading = false;
          });
        } else {
          final error = json.decode(response.body)['message'];
          setState(() {
            _errorMessage = 'Failed to load live score: $error';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not connect to the server.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sportName} - Live'),
        elevation: 0,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBody() {
     if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage,
            style: TextStyle(color: Colors.red.shade800, fontSize: 16)),
      );
    }
    if (_liveScoreData == null) {
      return const Center(
          child: Text('No live score data available for this match.',
              style: TextStyle(color: Colors.black54, fontSize: 16)));
    }

    final scoreData = _liveScoreData!;

    return RefreshIndicator(
      onRefresh: () => _fetchLiveScore(isRefresh: true),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCombinedScorecard(scoreData),
                ],
              ),
            ),
          ),
          if (widget.isAdmin) _buildAdminScoreButton(),
        ],
      ),
    );
  }

  Widget _buildCombinedScorecard(Map<String, dynamic> scoreData) {
     return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildScoreboardContent(scoreData),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: Text(
              scoreData['summary_text'] ?? 'Match is live.',
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          _buildPlayerDetailsContent(scoreData),
          _buildExpandToggle(),

          AnimatedCrossFade(
             firstChild: Padding(
               padding: const EdgeInsets.only(bottom: 16.0, top: 8.0, left: 16.0, right: 16.0),
               child: _buildTimelineSection(_recentBalls), // Timeline when collapsed
             ),
             secondChild: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
                 child: Column( // Detailed view + timeline when expanded
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     const Center(child: Text('Scorecard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                     const SizedBox(height: 8),
                     _buildTeamToggle(),
                     const SizedBox(height: 12),
                    _selectedTeamIndex == 0
                        ? _buildDetailedScorecard(
                            battingData: _teamABatting,
                            extras: _teamAExtras,
                            fowData: _teamAFOW,
                            bowlingData: _teamBBowling,
                          )
                        : _buildDetailedScorecard(
                            battingData: _teamBBatting,
                             extras: _teamBExtras,
                            fowData: _teamBFOW,
                            bowlingData: _teamABowling,
                          ),
                    const SizedBox(height: 16),
                    _buildTimelineSection(_recentBalls),
                    const SizedBox(height: 16),
                   ],
                 ),
             ),
             crossFadeState: _isDetailsExpanded
                 ? CrossFadeState.showSecond
                 : CrossFadeState.showFirst,
             duration: const Duration(milliseconds: 300),
           ),
        ],
      ),
    );
  }

   Widget _buildTeamToggle() {
      final Color selectedColor = Theme.of(context).primaryColor;
      final Color unselectedColor = Colors.grey.shade600;

     return ToggleButtons(
       isSelected: [_selectedTeamIndex == 0, _selectedTeamIndex == 1],
       onPressed: (int index) {
         setState(() {
           _selectedTeamIndex = index;
         });
       },
       borderRadius: BorderRadius.circular(8.0),
       selectedBorderColor: selectedColor,
       selectedColor: Colors.white,
       fillColor: selectedColor,
       color: unselectedColor,
       // Adjusted constraints slightly for better flexibility
       constraints: BoxConstraints(minHeight: 36.0, minWidth: (MediaQuery.of(context).size.width - 88) / 2),
       children: <Widget>[
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 8.0),
           child: Flexible(child: Text(widget.teamAName, overflow: TextOverflow.ellipsis, maxLines: 1)),
         ),
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 8.0),
           child: Flexible(child: Text(widget.teamBName, overflow: TextOverflow.ellipsis, maxLines: 1)),
         ),
       ],
     );
   }

   Widget _buildDetailedScorecard({
       required List<Map<String, String>> battingData,
       required String extras,
       required List<String> fowData,
       required List<Map<String, String>> bowlingData,
   }) {
        final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800);
        const cellStyle = TextStyle(fontSize: 12, color: Colors.black87);

       return Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
               // --- Batting Table ---
               const Center(child: Text('Batting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                DataTable(
                   columnSpacing: 10,
                   horizontalMargin: 0,
                   headingRowHeight: 30,
                   dataRowMinHeight: 32,
                   dataRowMaxHeight: 36,
                   headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                            return Colors.grey.shade200;
                        }),
                   columns: [
                       DataColumn(label: Text('Batter', style: headerStyle)),
                       DataColumn(label: Text('R', style: headerStyle), numeric: true),
                       DataColumn(label: Text('B', style: headerStyle), numeric: true),
                   ],
                   rows: battingData.map((batter) => DataRow(
                       cells: [
                           DataCell(
                               Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                       Text(batter['name']!, style: cellStyle, overflow: TextOverflow.ellipsis),
                                        Text( // Always show dismissal text
                                            batter['dismissal']!,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: batter['dismissal'] == 'not out' ? Colors.black87 : Colors.grey.shade600,
                                                fontWeight: batter['dismissal'] == 'not out' ? FontWeight.w500 : FontWeight.normal
                                            ),
                                            overflow: TextOverflow.ellipsis
                                        ),
                                   ],
                               )
                           ),
                           DataCell(Text(batter['runs']!, style: cellStyle)),
                           DataCell(Text(batter['balls']!, style: cellStyle)),
                       ],
                   )).toList(),
               ),
               const Divider(height: 16, thickness: 1), // Divider added

               // --- Extras ---
               Text('Extras: $extras', style: cellStyle),
               const Divider(height: 16, thickness: 1), // Divider added

                // --- Fall of Wickets ---
                const Center(child: Text('Fall of Wickets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                 const SizedBox(height: 4),
                 Wrap( // Use Wrap for horizontal layout
                    spacing: 8.0, // Space between items horizontally
                    runSpacing: 4.0, // Space between lines if it wraps
                    children: List<Widget>.generate(fowData.length, (index) {
                      return Row( // Keep score and details together
                         mainAxisSize: MainAxisSize.min, // Prevent Row from taking full width
                         children: [
                           Text(fowData[index], style: cellStyle),
                           // Add separator if not the last item
                           if (index < fowData.length - 1)
                              const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                         ],
                      );
                    }),
                  ),
                 const Divider(height: 16, thickness: 1), // Divider added

                // --- Bowling Table ---
                 const Center(child: Text('Bowling', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                DataTable(
                    columnSpacing: 10,
                    horizontalMargin: 0,
                    headingRowHeight: 30,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 28,
                    headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                            return Colors.grey.shade200;
                        }),
                    columns: [
                        DataColumn(label: Text('Bowler', style: headerStyle)),
                        DataColumn(label: Text('O', style: headerStyle), numeric: true),
                        DataColumn(label: Text('R', style: headerStyle), numeric: true),
                        DataColumn(label: Text('W', style: headerStyle), numeric: true),
                    ],
                    rows: bowlingData.map((bowler) => DataRow(
                        cells: [
                            DataCell(Text(bowler['name']!, style: cellStyle, overflow: TextOverflow.ellipsis)),
                            DataCell(Text(bowler['overs']!, style: cellStyle)),
                            DataCell(Text(bowler['runs']!, style: cellStyle)),
                            DataCell(Text(bowler['wickets']!, style: cellStyle)),
                        ],
                    )).toList(),
                ),
           ],
       );
   }

  Widget _buildExpandToggle() {
    // ... (remains the same)
     return InkWell(
      onTap: () {
        setState(() {
          _isDetailsExpanded = !_isDetailsExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isDetailsExpanded ? 'Show Less' : 'Show More',
              style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Icon(
              _isDetailsExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(List<String> allRecentBalls) {
    final Color titleColor = Colors.grey[700]!;
    // Take only the last 24 balls (4 overs) for the timeline
    final ballsToShow = allRecentBalls.length > 24
        ? allRecentBalls.sublist(allRecentBalls.length - 24)
        : allRecentBalls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // MODIFIED: Center align, bold, remove colon
        Center(
          child: Text(
            'Overs Timeline',
             style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: titleColor),
          ),
        ),
          const SizedBox(height: 8),
          _buildTimeline(ballsToShow),
      ],
    );
  }

  String _getOverIdentifier(int overIndex, int totalOversDisplayed) {
      int overNumber = overIndex + 1;
      if (overNumber <= 0) return "";
      if (overNumber % 10 == 1 && overNumber % 100 != 11) return "${overNumber}st";
      if (overNumber % 10 == 2 && overNumber % 100 != 12) return "${overNumber}nd";
      if (overNumber % 10 == 3 && overNumber % 100 != 13) return "${overNumber}rd";
      return "${overNumber}th";
  }

  // MODIFIED: Layout updated for identifier -> balls -> divider
  Widget _buildTimeline(List<String> balls) {
    List<Widget> timelineWidgets = [];
    int ballsPerOver = 6;
    int totalOversDisplayed = (balls.length / ballsPerOver).ceil();

    for (int overIndex = 0; overIndex < totalOversDisplayed; overIndex++) {
        // Add over identifier
        String overId = _getOverIdentifier(overIndex, totalOversDisplayed);
        timelineWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0), // Spacing before identifier
              child: Text(
                  overId,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            )
        );

        // Add ball widgets for the current over
        int startIndex = overIndex * ballsPerOver;
        int endIndex = (startIndex + ballsPerOver).clamp(0, balls.length);
        for (int i = startIndex; i < endIndex; i++) {
           timelineWidgets.add(_buildBallWidget(balls[i]));
        }

        // Add vertical divider (except after the last over)
        if (overIndex < totalOversDisplayed - 1) {
             timelineWidgets.add(
                Container(
                    height: 20,
                    width: 1.5,
                    color: Colors.grey.shade400,
                    margin: const EdgeInsets.symmetric(horizontal: 8.0), // Spacing around divider
                ),
             );
        }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: timelineWidgets,
      ),
    );
  }


  Widget _buildBallWidget(String ballOutcome) {
     Color bgColor;
    Color textColor = Colors.white;
    bool isWideOrNoBall = ballOutcome.toLowerCase() == 'wd' || ballOutcome.toLowerCase() == 'nb' || ballOutcome.toLowerCase().contains('lb');
    bool isWicket = ballOutcome.toLowerCase() == 'w';
    bool isBoundary = ballOutcome == '4' || ballOutcome == '6';

    if (isWicket) {
      bgColor = Colors.red.shade700;
    } else if (isBoundary) {
      bgColor = Colors.green.shade700;
    } else if (isWideOrNoBall) {
       bgColor = Colors.blueGrey.shade400;
    }
     else {
      bgColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 2.5), // Spacing between balls
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      constraints: const BoxConstraints(minWidth: 24), // Ensure minimum width for single digits
      alignment: Alignment.center, // Center the text
      child: Text(
        ballOutcome,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildScoreboardContent(Map<String, dynamic> scoreData) {
      String teamA = widget.teamAName;
    String teamB = widget.teamBName;
    String teamAScore = scoreData['team_a_score'] ?? '0/0';
    String teamAOvers = "(${scoreData['team_a_overs'] ?? '0.0'})";
    String teamBScore = scoreData['team_b_score'] ?? '0/0';
    String teamBOvers = "(${scoreData['team_b_overs'] ?? '0.0'})";
    String matchStatus = scoreData['match_status_text'] ?? 'Live';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(teamA,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(teamAScore,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Text(teamAOvers,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                matchStatus,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(teamB,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(teamBScore,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Text(teamBOvers,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildPlayerDetailsContent(Map<String, dynamic> scoreData) {
      const Color textColor = Colors.black87;
    final Color titleColor = Colors.grey[700]!;

    return Container(
      padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${scoreData['bowling_team_name'] ?? 'Team'} Bowling',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor),
                  ),
                  const SizedBox(height: 12),
                  _buildPlayerStat(
                    context: context,
                    name: scoreData['bowler_on_strike_name'] ?? 'N/A',
                    stat: scoreData['bowler_on_strike_figures'] ?? '-',
                    isBatting: false,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 8),
                  _buildPlayerStat(
                    context: context,
                    name: scoreData['bowler_off_strike_name'] ?? 'N/A',
                    stat: scoreData['bowler_off_strike_figures'] ?? '-',
                    isBatting: false,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${scoreData['batting_team_name'] ?? 'Team'} Batting',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor),
                  ),
                  const SizedBox(height: 12),
                  _buildPlayerStat(
                    context: context,
                    name: scoreData['batsman_on_strike_name'] ?? 'N/A',
                    stat: scoreData['batsman_on_strike_score'] ?? '-',
                    isBatting: true,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 8),
                  _buildPlayerStat(
                    context: context,
                    name: scoreData['batsman_off_strike_name'] ?? 'N/A',
                    stat: scoreData['batsman_off_strike_score'] ?? '-',
                    isBatting: true,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildAdminScoreButton() {
     // Navigate to AdminUpdateScoreScreen, passing dummy player data for now
    return Container(
     padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
     width: double.infinity,
     child: ElevatedButton.icon(
       onPressed: () {
         // TODO: Fetch real player lists before navigating
         Navigator.of(context).push(MaterialPageRoute(
           builder: (context) => AdminUpdateScoreScreen(
             matchId: widget.matchId,
             teamAName: widget.teamAName,
             teamBName: widget.teamBName,
             teamAPlayers: _dummyTeamAPlayers, // Pass dummy data for now
             teamBPlayers: _dummyTeamBPlayers, // Pass dummy data for now
             isForBoys: widget.isForBoys,
           ),
         ));
       },
       icon: const Icon(Icons.edit),
       label: const Text('Update Score'),
       style: ElevatedButton.styleFrom(
         minimumSize: const Size(double.infinity, 44),
       ),
     ),
   );
  }

  Widget _buildPlayerStat(
      {required BuildContext context,
      required String name,
      required String stat,
      required bool isBatting,
      required Color textColor}) {
       String combinedText = "$name: $stat";
    if (name == 'N/A') combinedText = "N/A";

    return Row(
      mainAxisAlignment: isBatting ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            combinedText,
            style: TextStyle(fontSize: 13, color: textColor),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
     return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pop();
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys);
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.schedule), label: 'Schedule'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
        BottomNavigationBarItem(
          icon: Icon(widget.isForBoys ? Icons.male : Icons.female),
          label: widget.isForBoys ? 'Boys' : 'Girls',
        ),
      ],
    );
  }
}

