import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/api_constants.dart'; // Import ApiConstants
import 'admin_update_score_screen.dart';

// --- ADD THESE IMPORTS FOR PDF ---
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
// --- ADD CONDITIONAL WEB IMPORT ---
import 'package:universal_html/html.dart' as html;

// ==========================================
// 1. DATA MODELS
// ==========================================

class PlayerScore {
  final int id;
  final String name;
  final int runs;
  final int ballsFaced;
  final String status; // "Not Out", "Out", "Yet to bat", or dismissal info
  final int ballsBowled;
  final int runsConceded;
  final int wicketsTaken;

  PlayerScore({
    required this.id,
    required this.name,
    this.runs = 0,
    this.ballsFaced = 0,
    this.status = "Yet to bat",
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.wicketsTaken = 0,
  });

  factory PlayerScore.fromJson(Map<String, dynamic> json) {
    return PlayerScore(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      runs: json['runs'] ?? 0,
      ballsFaced: json['ballsFaced'] ?? 0,
      status: json['status'] ?? 'Yet to bat',
      ballsBowled: json['ballsBowled'] ?? 0,
      runsConceded: json['runsConceded'] ?? 0,
      wicketsTaken: json['wicketsTaken'] ?? 0,
    );
  }

  String get batsmanDisplayScore => "$runs ($ballsFaced)";
  String get bowlerDisplayFigures {
     int overs = ballsBowled ~/ 6;
     int ballsPart = ballsBowled % 6;
     return "$wicketsTaken/$runsConceded ($overs.$ballsPart)";
  }
  bool get hasBatted => status != "Yet to bat";
  bool get isOut => status != "Yet to bat" && status != "Not Out";
  bool get hasBowled => ballsBowled > 0;
}

// ==========================================
// 2. LIVE CRICKET SCORE VIEWER
// ==========================================

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
  // --- State Variables ---
  Map<String, dynamic>? _liveScoreData;
  List<PlayerScore> _teamABatting = [];
  List<PlayerScore> _teamBBowling = [];
  List<PlayerScore> _teamBBatting = [];
  List<PlayerScore> _teamABowling = [];
  int _teamAExtras = 0;
  int _teamBExtras = 0;
  bool _isFirstInnings = true;

  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _pollingTimer;
  bool _isDetailsExpanded = false;
  int _selectedTeamIndex = 0; // 0 for Team A, 1 for Team B
  
  List<String> _team1TimelineData = []; 
  List<String> _team2TimelineData = []; 

  bool _isDownloadingPdf = false;
  bool _isMatchFinished = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveScore(); // Initial fetch
    
    // Poll more frequently, but we will cancel this if match is finished
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
     if (!isRefresh && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      // --- UPDATED: Use ApiConstants.baseUrl ---
      final response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/api/get_live_score/${widget.matchId}'));

      if (mounted) {
        if (response.statusCode == 200) {
          final fetchedData = json.decode(response.body);

          // --- Parse Detailed Data ---
          List<PlayerScore> parsePlayerList(List<dynamic>? data) {
            if (data == null) return [];
            return data
                .whereType<Map<String, dynamic>>()
                .map((item) => PlayerScore.fromJson(item))
                .toList();
          }
          
          bool parsedIsFirstInnings = true;
          if (fetchedData['is_first_innings'] != null) {
            if (fetchedData['is_first_innings'] is bool) {
               parsedIsFirstInnings = fetchedData['is_first_innings'];
            } else if (fetchedData['is_first_innings'] is int) {
               parsedIsFirstInnings = fetchedData['is_first_innings'] == 1;
            }
          }

          // Check if match is finished to stop polling
          bool isFinished = fetchedData['current_status']?.toLowerCase() == 'finished';
          if (isFinished) {
             _pollingTimer?.cancel();
             // Auto-expand details for finished matches so user sees scorecard immediately
             if (!_isDetailsExpanded && !isRefresh) { 
                _isDetailsExpanded = true; 
             }
          }

          setState(() {
            _liveScoreData = fetchedData;
            _teamABatting = parsePlayerList(fetchedData['team1_batting']);
            _teamBBowling = parsePlayerList(fetchedData['team2_bowling']);
            _teamBBatting = parsePlayerList(fetchedData['team2_batting']);
            _teamABowling = parsePlayerList(fetchedData['team1_bowling']);
            _teamAExtras = fetchedData['team1_extras'] ?? 0;
            _teamBExtras = fetchedData['team2_extras'] ?? 0;
            _isFirstInnings = parsedIsFirstInnings; 
            _team1TimelineData = List<String>.from(fetchedData['team1_timeline'] ?? []);
            _team2TimelineData = List<String>.from(fetchedData['team2_timeline'] ?? []);
            _isLoading = false;
            _errorMessage = ''; 
            _isMatchFinished = isFinished;
          });

        } else {
          final error = json.decode(response.body)['message'] ?? 'Unknown error';
          if (_isLoading || _errorMessage != 'Failed to load live score: $error') {
             setState(() {
               _errorMessage = 'Failed to load live score: $error';
               _isLoading = false; 
             });
          }
        }
      }
    } catch (e) {
      if (mounted) {
         const errorMsg = 'Could not connect to the server.';
         if (_isLoading || _errorMessage != errorMsg) {
            setState(() {
              _errorMessage = errorMsg;
              _isLoading = false; 
            });
         }
      }
    }
  }

  // --- PDF DOWNLOAD LOGIC ---
  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting download...'), backgroundColor: Colors.blue),
    );

    // --- UPDATED: Use ApiConstants.baseUrl ---
    final String apiUrl = '${ApiConstants.baseUrl}/api/download_scorecard_pdf/${widget.matchId}';
    final String downloadFileName = 'scorecard_match_${widget.matchId}.pdf';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (mounted) {
        if (response.statusCode == 200) {
          final pdfBytes = response.bodyBytes;

          if (kIsWeb) {
            // --- WEB DOWNLOAD LOGIC ---
            final blob = html.Blob([pdfBytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute("download", downloadFileName)
              ..click();
            html.Url.revokeObjectUrl(url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download started in browser.'), backgroundColor: Colors.green),
            );
          } else {
            // --- MOBILE DOWNLOAD LOGIC ---
            var status = await Permission.storage.request();
            if (!status.isGranted) {
               if (await Permission.storage.isPermanentlyDenied) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Permission denied. Please enable storage permission in app settings.'), backgroundColor: Colors.red),
                 );
                 await openAppSettings();
               } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Storage permission is required to download files.'), backgroundColor: Colors.red),
                 );
               }
               setState(() => _isDownloadingPdf = false);
               return;
            }

            Directory? dir = await getDownloadsDirectory();
            if (dir == null) {
              throw Exception('Could not find downloads directory.');
            }
            final String savePath = "${dir.path}/$downloadFileName";

            File file = File(savePath);
            await file.writeAsBytes(pdfBytes);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved to ${dir.path.split('/').last}'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    OpenFilex.open(savePath);
                  },
                ),
              ),
            );
            await OpenFilex.open(savePath);
          }
        } else {
          final error = json.decode(response.body)['message'] ?? 'Unknown error';
          throw Exception('Failed to download PDF: $error');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    // --- UPDATED TITLE LOGIC ---
    // If match is finished, show "Sport Recent". Otherwise "Sport Live".
    String appBarTitle;
    if (_isMatchFinished) {
      appBarTitle = "${widget.sportName} Recent";
    } else {
      appBarTitle = "${widget.sportName} Live";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
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
       // Keep bottom nav bar conditional on isAdmin
       bottomNavigationBar: !widget.isAdmin ? _buildBottomNavigationBar(context) : null,
    );
  }

  Widget _buildBody() {
     if (_isLoading && _liveScoreData == null) {
      return Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor));
    }
    // Show error prominently if loading failed and no data exists
    if (_errorMessage.isNotEmpty && _liveScoreData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column( 
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Text(
                 _errorMessage,
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.red.shade800, fontSize: 16),
               ),
               const SizedBox(height: 20),
               ElevatedButton.icon(
                 onPressed: () => _fetchLiveScore(isRefresh: true),
                 icon: const Icon(Icons.refresh),
                 label: const Text('Retry'),
               )
            ],
          ),
        ),
      );
    }
    
    if (_liveScoreData == null) {
      return const Center(
          child: Text('Waiting for live score data...',
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
                   if (_errorMessage.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(top: 10.0),
                       child: Text(
                         'Update failed: $_errorMessage',
                         style: TextStyle(color: Colors.orange[800], fontSize: 12),
                         textAlign: TextAlign.center,
                       ),
                     ),
                ],
              ),
            ),
          ),
          if (widget.isAdmin && !_isMatchFinished) _buildAdminScoreButton(),
        ],
      ),
    );
  }


  Widget _buildCombinedScorecard(Map<String, dynamic> scoreData) {
     // Use current_status (which is what backend sends) instead of match_status_text
     final bool isFinished = scoreData['current_status']?.toLowerCase() == 'finished';

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
          
          if (isFinished)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: ElevatedButton.icon(
                icon: _isDownloadingPdf
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                label: const Text('Download Scorecard (PDF)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: Colors.blueGrey, // A different color
                ),
                onPressed: _isDownloadingPdf ? null : _downloadPdf,
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          _buildPlayerDetailsContent(scoreData), 
          _buildExpandToggle(),

          AnimatedCrossFade(
             firstChild: const SizedBox(height: 16.0),
             secondChild: Padding( // Expanded View: Details + Timelines
                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     const Center(child: Text('Scorecard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                     const SizedBox(height: 8),
                     _buildTeamToggle(), 
                     const SizedBox(height: 12),
                     _buildDetailedScorecard(), 
                    
                    const SizedBox(height: 24),
                    _buildTimelineSection(
                      '${_liveScoreData?['team1_name'] ?? widget.teamAName} Innings',
                      _team1TimelineData,
                    ),
                    const SizedBox(height: 16),
                    _buildTimelineSection(
                      '${_liveScoreData?['team2_name'] ?? widget.teamBName} Innings',
                      _team2TimelineData,
                    ),
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
         if (mounted) {
            setState(() {
             _selectedTeamIndex = index;
           });
         }
       },
       borderRadius: BorderRadius.circular(8.0),
       selectedBorderColor: selectedColor,
       selectedColor: Colors.white,
       fillColor: selectedColor,
       color: unselectedColor,
       constraints: BoxConstraints(minHeight: 36.0, minWidth: (MediaQuery.of(context).size.width - 92) / 2),
       children: <Widget>[
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 8.0),
           child: Flexible(child: Text(_liveScoreData?['team1_name'] ?? widget.teamAName, overflow: TextOverflow.ellipsis, maxLines: 1)),
         ),
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 8.0),
           child: Flexible(child: Text(_liveScoreData?['team2_name'] ?? widget.teamBName, overflow: TextOverflow.ellipsis, maxLines: 1)),
         ),
       ],
     );
  }

   Widget _buildDetailedScorecard() {
        final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800);
        const cellStyle = TextStyle(fontSize: 12, color: Colors.black87);
        final placeholderStyle = TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic);

        // Determine which lists to use based on selected tab
        final bool isTeamASelected = _selectedTeamIndex == 0;
        final List<PlayerScore> battingList = isTeamASelected ? _teamABatting : _teamBBatting;
        final List<PlayerScore> bowlingList = isTeamASelected ? _teamBBowling : _teamABowling; // Switched for bowling
        final int extras = isTeamASelected ? _teamAExtras : _teamBExtras;

        // Filter lists for display
        final List<PlayerScore> battersToShow = battingList.where((p) => p.hasBatted).toList();
        final List<PlayerScore> bowlersToShow = bowlingList.where((p) => p.hasBowled).toList();
        final List<PlayerScore> fallenWickets = battingList.where((p) => p.isOut).toList();
         // Sort batters and bowlers alphabetically for consistent order
         battersToShow.sort((a,b) => a.name.compareTo(b.name));
         bowlersToShow.sort((a,b) => a.name.compareTo(b.name));

         // Check if match started
         bool tossDone = _liveScoreData?['toss_winner'] != null;
         bool statsExist = _teamABatting.any((p) => p.hasBatted) || _teamBBatting.any((p)=> p.hasBatted);
         bool matchStarted = tossDone || statsExist ;


       return Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
               // Batting Table
               const Center(child: Text('Batting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                DataTable(
                   columnSpacing: 10,
                   horizontalMargin: 0,
                   headingRowHeight: 30,
                   dataRowMinHeight: 32,
                   dataRowMaxHeight: 36,
                   headingRowColor: WidgetStateProperty.resolveWith<Color?>((_) => Colors.grey.shade200),
                   columns: [
                       DataColumn(label: Text('Batter', style: headerStyle, overflow: TextOverflow.ellipsis)),
                       DataColumn(label: Text('R', style: headerStyle), numeric: true),
                       DataColumn(label: Text('B', style: headerStyle), numeric: true),
                       DataColumn(label: Text('Status', style: headerStyle, overflow: TextOverflow.ellipsis)),
                   ],
                   rows: !matchStarted
                     ? [DataRow(cells: [DataCell(Text('Details after toss', style: placeholderStyle)), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-'))])]
                     : battersToShow.isEmpty
                         ? [DataRow(cells: [DataCell(Text('Yet to bat', style: placeholderStyle)), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-'))])]
                         : battersToShow.map((player) {
                               return DataRow(cells: [
                                 DataCell(Text(player.name, style: cellStyle, overflow: TextOverflow.ellipsis)),
                                 DataCell(Text(player.runs.toString(), style: cellStyle)),
                                 DataCell(Text(player.ballsFaced.toString(), style: cellStyle)),
                                 DataCell(Text(player.status == "Not Out" ? player.batsmanDisplayScore : player.status, style: cellStyle, overflow: TextOverflow.ellipsis)),
                               ]);
                             }).toList(),
               ),
               const Divider(height: 16, thickness: 1),

               // Extras
               Text( !matchStarted ? 'Extras: -' : 'Extras: $extras',
                   style: !matchStarted ? placeholderStyle : cellStyle),
               const Divider(height: 16, thickness: 1),

                // Fall of Wickets
                const Center(child: Text('Fall of Wickets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                 const SizedBox(height: 4),
                 !matchStarted
                    ? Center(child: Text('Match hasn\'t started yet', style: placeholderStyle))
                    : fallenWickets.isEmpty
                       ? Center(child: Text('No wickets fallen yet', style: placeholderStyle))
                       : Wrap(
                           spacing: 12.0,
                           runSpacing: 4.0,
                           alignment: WrapAlignment.center, // Center align the FoW items
                           children: fallenWickets.map((player) {
                             int wicketNumber = fallenWickets.indexOf(player) + 1;
                             return Text(
                               '$wicketNumber. ${player.name} ${player.batsmanDisplayScore}',
                               style: cellStyle.copyWith(fontSize: 11),
                             );
                           }).toList(),
                         ),
                 const Divider(height: 16, thickness: 1),

                // Bowling Table
                 const Center(child: Text('Bowling', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                DataTable(
                    columnSpacing: 10,
                    horizontalMargin: 0,
                    headingRowHeight: 30,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 32,
                    headingRowColor: WidgetStateProperty.resolveWith<Color?>((_) => Colors.grey.shade200),
                    columns: [
                        DataColumn(label: Text('Bowler', style: headerStyle, overflow: TextOverflow.ellipsis)),
                        DataColumn(label: Text('O', style: headerStyle), numeric: true),
                        DataColumn(label: Text('R', style: headerStyle), numeric: true),
                        DataColumn(label: Text('W', style: headerStyle), numeric: true),
                    ],
                    rows: !matchStarted
                      ? [DataRow(cells: [DataCell(Text('Details after toss', style: placeholderStyle)), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-'))])]
                      : bowlersToShow.isEmpty
                         ? [DataRow(cells: [DataCell(Text('Yet to bowl', style: placeholderStyle)), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-'))])]
                         : bowlersToShow.map((player) {
                              return DataRow(cells: [
                                DataCell(Text(player.name, style: cellStyle, overflow: TextOverflow.ellipsis)),
                                DataCell(Text( "${player.ballsBowled ~/ 6}.${player.ballsBowled % 6}" , style: cellStyle)), // Display Overs.Balls
                                DataCell(Text(player.runsConceded.toString(), style: cellStyle)),
                                DataCell(Text(player.wicketsTaken.toString(), style: cellStyle)),
                              ]);
                            }).toList(),
                ),
           ],
       );
   }


  // Expand Toggle
  Widget _buildExpandToggle() {
     return InkWell(
      onTap: () {
        if (mounted) {
           setState(() {
             _isDetailsExpanded = !_isDetailsExpanded;
           });
        }
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


  // Updated _buildTimelineSection
  Widget _buildTimelineSection(String title, List<String> ballsForTimeline) {
    final Color titleColor = Colors.grey[700]!;

    if (ballsForTimeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            title,
             style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: titleColor),
          ),
        ),
          const SizedBox(height: 8),
          _buildTimeline(ballsForTimeline),
      ],
    );
  }

  // Updated _buildTimeline
  Widget _buildTimeline(List<String> balls) {
    List<Widget> timelineWidgets = [];
    int ballsPerOver = 6;
    int totalOversDisplayed = (balls.isEmpty ? 0 : (balls.length - 1) ~/ ballsPerOver + 1).clamp(0, 100);
    if (totalOversDisplayed == 0) return const SizedBox(height: 24); // Return empty box if no balls

    List<String> displayBalls = List.from(balls);
    int expectedBalls = totalOversDisplayed * ballsPerOver;
    if (displayBalls.length < expectedBalls) {
        displayBalls.addAll(List.generate(expectedBalls - displayBalls.length, (_) => ''));
    }


    for (int overIndex = 0; overIndex < totalOversDisplayed; overIndex++) {
        String overId = _getOverIdentifier(overIndex, totalOversDisplayed);
        timelineWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                  overId,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            )
        );

        int startIndex = overIndex * ballsPerOver;
        int endIndex = startIndex + ballsPerOver;
        for (int i = startIndex; i < endIndex; i++) {
           timelineWidgets.add(_buildBallWidget(displayBalls[i]));
        }

        if (overIndex < totalOversDisplayed - 1) {
             timelineWidgets.add(
                Container(
                    height: 20,
                    width: 1.5,
                    color: Colors.grey.shade400,
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
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

  String _getOverIdentifier(int overIndex, int totalOversDisplayed) {
      int overNumber = overIndex + 1;
      if (overNumber <= 0) return "";
      if (overNumber % 10 == 1 && overNumber % 100 != 11) return "${overNumber}st";
      if (overNumber % 10 == 2 && overNumber % 100 != 12) return "${overNumber}nd";
      if (overNumber % 10 == 3 && overNumber % 100 != 13) return "${overNumber}rd";
      return "${overNumber}th";
  }

  Widget _buildBallWidget(String ballOutcome) {
     Color bgColor;
    Color textColor = Colors.white;
    bool isEmpty = ballOutcome.isEmpty;

    if (isEmpty) {
        bgColor = Colors.grey.shade300;
        ballOutcome = '';
    } else {
        String lowerOutcome = ballOutcome.toLowerCase();
        bool isWicket = lowerOutcome == 'w';
        bool isBoundary = lowerOutcome.startsWith('4') || lowerOutcome.startsWith('6');
        bool isExtraIndicator = lowerOutcome.endsWith('wd') || lowerOutcome.endsWith('nb') || lowerOutcome.endsWith('lb') || lowerOutcome.endsWith('b');


        if (isWicket) {
          bgColor = Colors.red.shade700;
        } else if (isBoundary && !isExtraIndicator) {
          bgColor = Colors.green.shade700;
        } else if (isExtraIndicator) {
           bgColor = Colors.blueGrey.shade400;
        }
         else {
           bgColor = (lowerOutcome == '0') ? Colors.grey.shade500 : Colors.grey.shade700;
        }
    }


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: isEmpty ? Border.all(color: Colors.grey.shade500, width: 0.5) : null,
      ),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      alignment: Alignment.center,
      child: Text(
        ballOutcome,
        style: TextStyle(
          color: isEmpty ? Colors.transparent : textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }


  // Scoreboard Content
  Widget _buildScoreboardContent(Map<String, dynamic> scoreData) {
      // Use correct keys from Backend (team1_name vs team_a_name)
      String teamA = scoreData['team1_name'] ?? widget.teamAName;
      String teamB = scoreData['team2_name'] ?? widget.teamBName;
      
      // Manually construct score string since backend doesn't send formatted string
      int t1Runs = scoreData['team1_runs'] ?? 0;
      int t1Wickets = scoreData['team1_wickets'] ?? 0;
      int t1Balls = scoreData['team1_balls'] ?? 0;
      
      int t2Runs = scoreData['team2_runs'] ?? 0;
      int t2Wickets = scoreData['team2_wickets'] ?? 0;
      int t2Balls = scoreData['team2_balls'] ?? 0;

      String teamAScore = "$t1Runs/$t1Wickets";
      String teamAOvers = "(${t1Balls ~/ 6}.${t1Balls % 6})";
      
      String teamBScore = "$t2Runs/$t2Wickets";
      String teamBOvers = "(${t2Balls ~/ 6}.${t2Balls % 6})";
      
      // Use current_status instead of match_status_text
      String matchStatus = scoreData['current_status'] ?? 'Live';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(teamA,
                       textAlign: TextAlign.center, // Center team names
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
                   color: matchStatus.toLowerCase() == 'finished' ? Colors.blueGrey : Colors.red.shade700,
                   fontWeight: FontWeight.bold,
                 ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(teamB,
                       textAlign: TextAlign.center, // Center team names
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

  // Player Details (Top Summary)
  Widget _buildPlayerDetailsContent(Map<String, dynamic> scoreData) {
      const Color textColor = Colors.black87;
      final Color titleColor = Colors.grey[700]!;
      
      // Calculate Batting/Bowling Team Name
      // We rely on toss logic if first innings, or swap if second
      String team1 = scoreData['team1_name'] ?? widget.teamAName;
      String team2 = scoreData['team2_name'] ?? widget.teamBName;
      String tossWinner = scoreData['toss_winner'] ?? "";
      String tossDecision = scoreData['toss_decision'] ?? "";
      bool isFirstInnings = _isFirstInnings;
      
      String battingTeam = "";
      String bowlingTeam = "";
      
      if (tossWinner.isNotEmpty) {
          bool team1BattingFirst = (tossWinner == team1 && tossDecision == "Bat") || (tossWinner == team2 && tossDecision == "Bowl");
          if (isFirstInnings) {
              battingTeam = team1BattingFirst ? team1 : team2;
              bowlingTeam = team1BattingFirst ? team2 : team1;
          } else {
              battingTeam = team1BattingFirst ? team2 : team1;
              bowlingTeam = team1BattingFirst ? team1 : team2;
          }
      }
      
      String bowlingTitle = bowlingTeam.isNotEmpty ? '$bowlingTeam Bowling' : 'Bowling';
      String battingTitle = battingTeam.isNotEmpty ? '$battingTeam Batting' : 'Batting';

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
                  Text( bowlingTitle, style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
                  const SizedBox(height: 12),
                  _buildPlayerStat( context: context, name: _findPlayerName(scoreData['bowler_id'], _teamABowling + _teamBBowling), stat: "", isBatting: false, textColor: textColor,),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text( battingTitle, style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
                  const SizedBox(height: 12),
                  _buildPlayerStat( context: context, name: _findPlayerName(scoreData['striker_id'], _teamABatting + _teamBBatting), stat: "*", isBatting: true, textColor: textColor,),
                  const SizedBox(height: 8),
                  _buildPlayerStat( context: context, name: _findPlayerName(scoreData['non_striker_id'], _teamABatting + _teamBBatting), stat: "", isBatting: true, textColor: textColor,),
                ],
              ),
            ),
          ],
        ),
    );
  }
  
  String _findPlayerName(dynamic id, List<PlayerScore> players) {
      if (id == null) return "N/A";
      int pid = (id is int) ? id : int.tryParse(id.toString()) ?? -1;
      try {
          return players.firstWhere((p) => p.id == pid).name;
      } catch (e) {
          return "N/A";
      }
  }

  // Admin Score Button
  Widget _buildAdminScoreButton() {
    return Container(
     padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
     width: double.infinity,
     child: ElevatedButton.icon(
       onPressed: () {
         // Navigate to Admin screen
          Navigator.of(context).push(MaterialPageRoute(
           builder: (_) => AdminUpdateScoreScreen( // Use correct class name
             matchId: widget.matchId,
             teamAName: _liveScoreData?['team1_name'] ?? widget.teamAName, 
             teamBName: _liveScoreData?['team2_name'] ?? widget.teamBName, 
             isForBoys: widget.isForBoys,
           ),
         )).then((value) {
            // Refresh data when returning from admin screen
            if(value == true) { // Changed condition slightly
               _fetchLiveScore(isRefresh: true);
            }
         });
       },
       icon: const Icon(Icons.edit),
       label: const Text('Update Score'),
       style: ElevatedButton.styleFrom(
         minimumSize: const Size(double.infinity, 44),
       ),
     ),
   );
  }


  // Player Stat Row
  Widget _buildPlayerStat(
      {required BuildContext context,
      required String name,
      required String stat,
      required bool isBatting,
      required Color textColor}) {
       String combinedText = "$name $stat";
    if (name == 'N/A' || name.isEmpty) combinedText = "-";

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

 // Bottom Navigation Bar for Users (Conditional)
 Widget _buildBottomNavigationBar(BuildContext context) {

    // Otherwise, build the user navigation bar
    return BottomNavigationBar(
      currentIndex: 0, // Assuming this screen relates to the 'Home' tab for users
      onTap: (index) {
        if (index == 0) {
          if (Navigator.canPop(context)) {
             Navigator.of(context).pop();
          } else {
             _fetchLiveScore(isRefresh: true); // Refresh if already home
          }
        } else if (index == 3) {
          widget.onGenderToggle(!widget.isForBoys);
        }
        // Handle other tab navigation if necessary
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
} // End of _LiveCricketScoreScreenState