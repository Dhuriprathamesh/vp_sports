// A centralized file for mock data models and retrieval logic.

// --- DATA MODELS ---

abstract class MatchResult {}

// MODIFIED: Added an 'id' field to store the unique identifier from the database.
class UpcomingMatch extends MatchResult {
  final int id;
  final String title;
  final String? teamA;
  final String? teamB;
  final String venue;
  final String date;
  final String time;

  UpcomingMatch({
    required this.id,
    required this.title,
    this.teamA,
    this.teamB,
    required this.venue,
    required this.date,
    required this.time,
  });
}

class LiveMatch extends MatchResult {
  final String teamA;
  final String teamB;
  final String score;
  final String status;

  LiveMatch(
      {required this.teamA,
      this.teamB = "",
      required this.score,
      required this.status});
}

class TeamMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final String result;
  final List<String> highlights;

  TeamMatchResult(
      {required this.teamA,
      required this.teamB,
      required this.scoreA,
      required this.scoreB,
      required this.result,
      this.highlights = const []});
}

class PlayerMatchResult extends MatchResult {
  final String playerA;
  final String playerB;
  final String result;
  final List<String> gameScores;

  PlayerMatchResult(
      {required this.playerA,
      required this.playerB,
      required this.result,
      required this.gameScores});
}

class VolleyballMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String result;
  final String bestPlayer;
  final List<String> setScores;

  VolleyballMatchResult(
      {required this.teamA,
      required this.teamB,
      required this.result,
      required this.bestPlayer,
      required this.setScores});
}

class AthleticsResult extends MatchResult {
  final String event;
  final String winner;
  final List<Map<String, String>> podium;

  AthleticsResult(
      {required this.event, required this.winner, required this.podium});
}

class CarromMatchResult extends MatchResult {
  final String playerA;
  final String playerB;
  final String result;
  final List<String> roundScores;
    
  CarromMatchResult({required this.playerA, required this.playerB, required this.result, required this.roundScores});
}

class ChessMatchResult extends MatchResult {
    final String teamA;
    final String teamB;
    final String result;
    final List<Map<String, String>> boardResults;

    ChessMatchResult({required this.teamA, required this.teamB, required this.result, required this.boardResults});
}


// --- MOCK DATA RETRIEVAL ---

class SportsData {
  static List<MatchResult> getRecentMatches(String sportName) {
    // This can be expanded to return different data based on the sport
    return _recentCricketMatches;
  }

  static List<MatchResult> getLiveMatches(String sportName) {
     if (sportName == 'Cricket') {
      return [_liveCricketMatch];
    }
    return [];
  }
  
  static List<MatchResult> getUpcomingMatches(String sportName) {
     if (sportName == 'Kabaddi') {
      return [_upcomingKabaddiMatch];
    }
     if (sportName == 'Athletics') {
      return [_upcomingAthleticsEvent];
    }
    return [];
  }

  // --- Sample Data ---

  static final LiveMatch _liveCricketMatch = LiveMatch(
    teamA: 'Vidyalankar Warriors',
    teamB: 'Polytechnic Titans',
    score: '125/4 (15.2)',
    status: 'Vidyalankar needs 35 runs in 28 balls.',
  );
  
  static final UpcomingMatch _upcomingKabaddiMatch = UpcomingMatch(
    id: 99, // Dummy ID
    title: 'Inter-Department Kabaddi Final',
    teamA: 'Computer Commandos',
    teamB: 'IT Ninjas',
    venue: 'Main Ground',
    date: 'Oct 28',
    time: '04:00 PM',
  );

   static final UpcomingMatch _upcomingAthleticsEvent = UpcomingMatch(
    id: 98, // Dummy ID
    title: '100m Sprint Final (Boys)',
    venue: 'Athletics Track',
    date: 'Oct 29',
    time: '10:00 AM',
  );

  static final List<MatchResult> _recentCricketMatches = [
    TeamMatchResult(
        teamA: 'Computer Strikers',
        teamB: 'IT Gladiators',
        scoreA: '154/7',
        scoreB: '148/9',
        result: 'Computer Strikers won by 6 runs.',
        highlights: [
          'Player of the Match: R. Sharma (58 runs)',
          'Best Bowler: J. Bumrah (3/22)'
        ]),
    TeamMatchResult(
        teamA: 'Mechanical Mavericks',
        teamB: 'Electronics Dynamos',
        scoreA: '189/5',
        scoreB: '190/4',
        result: 'Electronics Dynamos won by 6 wickets.',
        highlights: ['Player of the Match: S. Iyer (72*)']),
  ];
}
