import 'package:flutter/material.dart';
import '../../../core/app_theme.dart'; // Assuming your AppTheme is here

// Dummy player data structure for now
class Player {
  final int id;
  final String name;
  Player({required this.id, required this.name});
}

class AdminUpdateScoreScreen extends StatefulWidget {
  final int matchId;
  final String teamAName;
  final String teamBName;
  // In a real app, you'd fetch player lists based on matchId
  final List<Player> teamAPlayers;
  final List<Player> teamBPlayers;
  final bool isForBoys; // To maintain theme consistency

  const AdminUpdateScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    required this.teamAPlayers,
    required this.teamBPlayers,
    required this.isForBoys,
  });

  @override
  State<AdminUpdateScoreScreen> createState() => _AdminUpdateScoreScreenState();
}

// Enum to manage the current state of the scoring process
enum ScoringPhase {
  PreMatch, // Toss
  SelectPlayers, // Choose openers and bowler
  Innings1, // Ball-by-ball scoring for 1st innings
  InningsBreak, // Between innings
  Innings2, // Ball-by-ball scoring for 2nd innings
  MatchEnd, // Declare result
  Finished
}

class _AdminUpdateScoreScreenState extends State<AdminUpdateScoreScreen> {
  ScoringPhase _currentPhase = ScoringPhase.PreMatch;

  // --- State Variables (Examples - will need many more) ---
  String? _tossWinner;
  String? _tossDecision; // 'Bat' or 'Bowl'
  Player? _striker;
  Player? _nonStriker;
  Player? _currentBowler;
  int _currentScore = 0;
  int _currentWickets = 0;
  double _currentOvers = 0.0;
  // ... many more variables for runs, balls, extras, second innings, etc.

  // TODO: Add controllers, player selection logic, scoring logic, API calls

  @override
  Widget build(BuildContext context) {
     final gradientColors = widget.isForBoys
        ? AppTheme.boysGradientColors
        : AppTheme.girlsGradientColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Live Score'),
        backgroundColor: Theme.of(context).primaryColor,
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
        child: Column(
          children: [
            _buildScoreDisplay(), // Always show the current score
            Expanded(child: _buildScoringInterface()), // Main interaction area
            // Potentially add navigation/action buttons at the bottom
          ],
        ),
      ),
    );
  }

  // Widget to display the current match score summary
  Widget _buildScoreDisplay() {
    // TODO: Display live score, overs, wickets, target etc. based on state
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text('Score Display Area (Score: $_currentScore/$_currentWickets Overs: $_currentOvers)', style: const TextStyle(color: Colors.black87))),
    );
  }

  // Widget that changes based on the current scoring phase
  Widget _buildScoringInterface() {
    switch (_currentPhase) {
      case ScoringPhase.PreMatch:
        return _buildTossSection();
      case ScoringPhase.SelectPlayers:
        return _buildPlayerSelectionSection();
      case ScoringPhase.Innings1:
      case ScoringPhase.Innings2:
        return _buildBallByBallSection();
      case ScoringPhase.InningsBreak:
        return _buildInningsBreakSection();
      case ScoringPhase.MatchEnd:
        return _buildMatchResultSection();
      case ScoringPhase.Finished:
         return const Center(child: Text('Match Finished'));
      default:
        return const Center(child: Text('Loading...'));
    }
  }

  // --- Placeholder Widgets for each phase ---

  Widget _buildTossSection() {
    // TODO: Input for Toss Winner (Team A/B Dropdown/Buttons)
    // TODO: Input for Toss Decision (Bat/Bowl Radio Buttons)
    // TODO: Button to confirm Toss and move to SelectPlayers phase
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Toss Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Add Dropdowns/Buttons here
          ElevatedButton(
            onPressed: () {
              // TODO: Validate Toss input
              setState(() => _currentPhase = ScoringPhase.SelectPlayers);
            },
            child: const Text('Confirm Toss & Select Players'),
          )
        ],
      ),
    );
  }

  Widget _buildPlayerSelectionSection() {
     // TODO: Dropdowns/Lists to select Striker, Non-Striker, Opening Bowler
     // TODO: Button to confirm players and start Innings1 phase
    return Padding(
       padding: const EdgeInsets.all(16.0),
      child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Select Opening Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Add Dropdowns here
           ElevatedButton(
            onPressed: () {
               // TODO: Validate Player selection
              setState(() => _currentPhase = ScoringPhase.Innings1);
            },
            child: const Text('Start 1st Innings'),
          )
        ],
      ),
    );
  }

  Widget _buildBallByBallSection() {
    // TODO: Buttons for Runs (0, 1, 2, 3, 4, 6)
    // TODO: Buttons for Extras (Wd, Nb, Lb, B) + Run value if applicable
    // TODO: Button for Wicket -> Trigger wicket details popup (how out, who out, fielder?, new batter selection)
    // TODO: Display current striker, non-striker, bowler
    // TODO: Button to change bowler (end of over)
    // TODO: Button to change strike (end of over or odd runs)
    // TODO: Button to end innings
    return Padding(
       padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text( _currentPhase == ScoringPhase.Innings1 ? '1st Innings Scoring' : '2nd Innings Scoring',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Bowler: ${_currentBowler?.name ?? 'Select Bowler'}'),
          Text('Striker: ${_striker?.name ?? 'Select Striker'} | Non-Striker: ${_nonStriker?.name ?? 'Select Non-Striker'}'),
           const SizedBox(height: 20),
           const Text('Enter Ball Outcome:'),
          // Add Run Buttons, Extra Buttons, Wicket Button here
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              // TODO: Logic to end the current innings
              if (_currentPhase == ScoringPhase.Innings1) {
                 setState(() => _currentPhase = ScoringPhase.InningsBreak);
              } else {
                 setState(() => _currentPhase = ScoringPhase.MatchEnd);
              }
            },
            child: Text(_currentPhase == ScoringPhase.Innings1 ? 'End 1st Innings' : 'End 2nd Innings'),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsBreakSection() {
    // TODO: Display target score
    // TODO: Button to start 2nd Innings (moves to SelectPlayers or Innings2 phase)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Innings Break', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          // Display Target
          ElevatedButton(
            onPressed: () {
              // TODO: Reset relevant state for 2nd innings
               setState(() => _currentPhase = ScoringPhase.SelectPlayers); // Or directly to Innings2 if players are same/auto-selected
            },
            child: const Text('Start 2nd Innings'),
          ),
        ],
      ),
    );
  }

   Widget _buildMatchResultSection() {
    // TODO: Input/Selection for match result (Team A won, Team B won, Draw, No Result)
    // TODO: Input for margin (e.g., by 5 wickets, by 20 runs)
    // TODO: Button to finalize result and move to Finished phase
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const Text('Declare Match Result', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           // Add result input fields/dropdowns
           ElevatedButton(
            onPressed: () {
               // TODO: Save final result via API
              setState(() => _currentPhase = ScoringPhase.Finished);
            },
            child: const Text('Finalize Result & End Match'),
          ),
         ],
       ),
     );
   }
}
