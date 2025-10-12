import 'package:flutter/material.dart';

// --- Base Data Model ---
abstract class MatchResult {}

// --- Models for Match Lists (Live, Recent, Upcoming) ---
class TeamMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final String result;
  final List<String> highlights;

  TeamMatchResult({
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.result,
    this.highlights = const [],
  });
}

class PlayerMatchResult extends MatchResult {
  final String playerA;
  final String playerB;
  final String result;
  final List<String> gameScores;

  PlayerMatchResult({
    required this.playerA,
    required this.playerB,
    required this.result,
    required this.gameScores,
  });
}

class AthleticsResult extends MatchResult {
  final String event;
  final List<Map<String, String>> podium;
  final String winner;

  AthleticsResult({
    required this.event,
    required this.podium,
    required this.winner,
  });
}

class VolleyballMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String result;
  final String bestPlayer;
  final List<String> setScores;

  VolleyballMatchResult({
    required this.teamA,
    required this.teamB,
    required this.result,
    required this.bestPlayer,
    required this.setScores,
  });
}

class ChessMatchResult extends MatchResult {
  final String teamA;
  final String teamB;
  final String result;
  final List<Map<String, String>> boardResults;

  ChessMatchResult({
    required this.teamA,
    required this.teamB,
    required this.result,
    required this.boardResults,
  });
}

class CarromMatchResult extends MatchResult {
  final String playerA;
  final String playerB;
  final String result;
  final List<String> roundScores;

  CarromMatchResult({
    required this.playerA,
    required this.playerB,
    required this.result,
    required this.roundScores,
  });
}

class LiveMatch extends MatchResult {
  final String teamA;
  final String teamB;
  final String score;
  final String status;

  LiveMatch({
    required this.teamA,
    required this.teamB,
    required this.score,
    required this.status,
  });
}

class UpcomingMatch extends MatchResult {
  final String title;
  final String? teamA;
  final String? teamB;
  final String date;
  final String time;
  final String venue;

  UpcomingMatch({
    required this.title,
    this.teamA,
    this.teamB,
    required this.date,
    required this.time,
    required this.venue,
  });
}

// --- Models for Detailed Scorecards ---

class BattingStats {
  final String name;
  final String dismissal;
  final String runs;
  final String balls;
  final String fours;
  final String sixes;
  final String sr;

  BattingStats({
    required this.name,
    required this.dismissal,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.sr,
  });
}

class BowlingStats {
  final String name;
  final String overs;
  final String maidens;
  final String runs;
  final String wickets;
  final String er;

  BowlingStats({
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.er,
  });
}

class CricketInnings {
  final String teamName;
  final String totalScore;
  final List<BattingStats> batting;
  final List<String> fow;
  final List<BowlingStats> bowling;

  CricketInnings({
    required this.teamName,
    required this.totalScore,
    required this.batting,
    required this.fow,
    required this.bowling,
  });
}

class CricketScorecard {
  final String result;
  final List<CricketInnings> innings;

  CricketScorecard({
    required this.result,
    required this.innings,
  });
}

class FootballScorecard {
  final String result;
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final List<Map<String, String>> goalScorers;

  FootballScorecard({
    required this.result,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.goalScorers,
  });
}

class KabaddiScorecard {
  final String result;
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;
  final String topRaider;
  final String topDefender;

  KabaddiScorecard({
    required this.result,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.topRaider,
    required this.topDefender,
  });
}


// --- Data Source Class ---
class SportsData {

  static Object? getDetailedScorecard(String sportName, MatchResult match) {
     if (sportName == 'Cricket' && match is TeamMatchResult) {
      return getCricketScorecard(match);
    }
    if (sportName == 'Football' && match is TeamMatchResult) {
      return getFootballScorecard(match);
    }
     if (sportName == 'Kabaddi' && match is TeamMatchResult) {
      return getKabaddiScorecard(match);
    }
    // Return the match itself if no detailed scorecard is available
    return match;
  }

   static KabaddiScorecard? getKabaddiScorecard(TeamMatchResult match) {
    if (match.teamA == 'Vidyalankar Raiders') {
      return KabaddiScorecard(
        result: 'Polytechnic Panthers won by 8 points',
        teamA: 'Vidyalankar Raiders',
        teamB: 'Polytechnic Panthers',
        scoreA: '39',
        scoreB: '47',
        topRaider: 'S. Jadhav (15 raid points)',
        topDefender: 'A. More (5 tackle points)',
      );
    }
    return null;
  }

  static FootballScorecard? getFootballScorecard(TeamMatchResult match) {
     if (match.teamA == 'Vidyalankar FC') {
      return FootballScorecard(
        result: 'Polytechnic United won 2-1',
        teamA: 'Vidyalankar FC',
        teamB: 'Polytechnic United',
        scoreA: '1',
        scoreB: '2',
        goalScorers: [
          {'player': 'R. Khan', 'time': '12\'', 'team': 'Vidyalankar FC'},
          {'player': 'S. Pawar', 'time': '48\'', 'team': 'Polytechnic United'},
          {'player': 'M. Ghosh', 'time': '71\'', 'team': 'Polytechnic United'},
        ]
      );
     }
     return null;
  }

  static CricketScorecard? getCricketScorecard(TeamMatchResult match) {
    if (match.teamA == 'Vidyalankar Warriors') {
      return CricketScorecard(
        result: 'Poly Strikers won by 4 wickets',
        innings: [
          CricketInnings(
            teamName: 'Vidyalankar Warriors',
            totalScore: '152/7 (20.0)',
            batting: [
              BattingStats(name: 'A. Sharma', dismissal: 'c Player b S. Afridi', runs: '5', balls: '6', fours: '1', sixes: '0', sr: '83.33'),
              BattingStats(name: 'S. Gill', dismissal: 'lbw b H. Rauf', runs: '12', balls: '10', fours: '1', sixes: '0', sr: '120.00'),
              BattingStats(name: 'T. Varma', dismissal: 'not out', runs: '69', balls: '53', fours: '3', sixes: '4', sr: '130.19'),
              BattingStats(name: 'S. Samson (wk)', dismissal: 'not out', runs: '24', balls: '21', fours: '2', sixes: '1', sr: '114.29'),
            ],
            fow: ['10/1', '20/2', '77/3', '137/4'],
            bowling: [
              BowlingStats(name: 'S. Afridi', overs: '4.0', maidens: '0', runs: '20', wickets: '1', er: '5.00'),
              BowlingStats(name: 'M. Nawaz', overs: '1.0', maidens: '0', runs: '6', wickets: '0', er: '6.00'),
              BowlingStats(name: 'H. Rauf', overs: '3.4', maidens: '0', runs: '50', wickets: '1', er: '13.64'),
            ],
          ),
          CricketInnings(
            teamName: 'Poly Strikers',
            totalScore: '153/6 (19.3)',
            batting: [
              BattingStats(name: 'A. Patil', dismissal: 'c Player b R. Deshmukh', runs: '62', balls: '38', fours: '5', sixes: '2', sr: '163.15'),
              BattingStats(name: 'P. Shaw', dismissal: 'run out', runs: '21', balls: '15', fours: '3', sixes: '0', sr: '140.00'),
            ],
            fow: ['35/1', '80/2', '110/3', '140/4'],
            bowling: [
               BowlingStats(name: 'R. Deshmukh', overs: '4.0', maidens: '0', runs: '22', wickets: '3', er: '5.50'),
               BowlingStats(name: 'V. Kumar', overs: '3.3', maidens: '0', runs: '30', wickets: '1', er: '8.57'),
            ],
          )
        ],
      );
    }
    return null;
  }
  
  static List<MatchResult> getLiveMatches(String sportName) {
    switch (sportName) {
      case 'Cricket':
        return [LiveMatch(teamA: 'Vidyalankar Warriors', teamB: 'Polytechnic Titans', score: '125/4 (15.2)', status: 'Vidyalankar needs 35 runs in 28 balls')];
      case 'Football':
        return [LiveMatch(teamA: 'Vidyalankar FC', teamB: 'Polytechnic United', score: '1 - 1', status: '2nd Half Ongoing')];
      case 'Kabaddi':
        return [LiveMatch(teamA: 'Vidyalankar Raiders', teamB: 'Polytechnic Panthers', score: '34 - 31', status: 'Close contest!')];
      case 'Volleyball':
        return [LiveMatch(teamA: 'Vidyalankar Spikers', teamB: 'Polytechnic Smashers', score: 'Set 4', status: 'Vidyalankar leading 18-15')];
      case 'Table Tennis':
         return [LiveMatch(teamA: 'R. Patel', teamB: 'M. Joshi', score: '2-1', status: 'Game 4 ongoing (7-5)')];
      case 'Badminton':
        return [LiveMatch(teamA: 'S. Patil', teamB: 'R. Sharma', score: '16-15', status: 'Tight Decider!')];
      case 'Chess':
        return [LiveMatch(teamA: 'A. Nair', teamB: 'S. Khan', score: 'Board 1', status: 'Move 28: Balanced position')];
      case 'Carrom':
         return [LiveMatch(teamA: 'K. Shetty', teamB: 'P. Gawade', score: '21-17', status: 'Round 2 in progress')];
       case 'Athletics':
        return [LiveMatch(teamA: 'Men\'s 100m', teamB: 'R. Singh (Polytechnic)', score: '10.9 sec', status: 'Heat 2 of 4')];
      default:
        return [];
    }
  }

  static List<MatchResult> getUpcomingMatches(String sportName) {
     switch (sportName) {
      case 'Cricket':
        return [UpcomingMatch(title: 'Match 4', teamA: 'Polytechnic Titans', teamB: 'Engineering Eagles', date: 'Oct 8', time: '10:00 AM', venue: 'Main Ground')];
      case 'Football':
        return [UpcomingMatch(title: 'Quarterfinal', teamA: 'Vidyalankar FC', teamB: 'DYP United', date: 'Oct 8', time: '3:00 PM', venue: 'Turf Ground A')];
      case 'Kabaddi':
        return [UpcomingMatch(title: 'Final', teamA: 'Polytechnic Panthers', teamB: 'Vidyalankar Raiders', date: 'Oct 9', time: '11:00 AM', venue: 'Sports Complex')];
      case 'Volleyball':
        return [UpcomingMatch(title: 'Semifinal 1', teamA: 'Vidyalankar Spikers', teamB: 'DYP Smashers', date: 'Oct 8', time: '2:30 PM', venue: 'Indoor Court 2')];
      case 'Athletics':
        return [UpcomingMatch(title: '100m Finals', date: 'Oct 8', time: '9:30 AM', venue: 'Athletics Track')];
      case 'Table Tennis':
        return [UpcomingMatch(title: 'Semifinal', teamA: 'R. Patel', teamB: 'S. Jadhav', date: 'Oct 8', time: '11:00 AM', venue: 'TT Hall')];
      case 'Chess':
        return [UpcomingMatch(title: 'Round 3', teamA: 'Vidyalankar Chess Club', teamB: 'Polytechnic Mind Masters', date: 'Oct 8', time: '1:00 PM', venue: 'Library Hall')];
      case 'Carrom':
        return [UpcomingMatch(title: 'Finals', teamA: 'K. Shetty', teamB: 'M. Patel', date: 'Oct 9', time: '12:00 PM', venue: 'Recreation Room')];
      case 'Badminton':
        return [UpcomingMatch(title: 'Girls\' Singles Final', teamA: 'A. Desai', teamB: 'R. Pawar', date: 'Oct 8', time: '4:00 PM', venue: 'Badminton Court 1')];
      default:
        return [];
    }
  }

  static List<MatchResult> getRecentMatches(String sportName) {
    switch (sportName) {
      case 'Cricket':
        return [
          TeamMatchResult(
            teamA: 'Vidyalankar Warriors',
            teamB: 'Poly Strikers',
            scoreA: '152/7 (20.0)',
            scoreB: '153/6 (19.3)',
            result: 'Poly Strikers won by 4 wickets',
            highlights: ['Top Scorer: A. Patil - 62 (38)', 'Best Bowler: R. Deshmukh - 3/22 (4)'],
          )
        ];
      case 'Football':
        return [
          TeamMatchResult(
            teamA: 'Vidyalankar FC',
            teamB: 'Polytechnic United',
            scoreA: '1',
            scoreB: '2',
            result: 'Polytechnic United won 2-1',
            highlights: ['Goal Scorers:', 'Vidyalankar FC: R. Khan (12\')', 'Polytechnic United: S. Pawar (48\'), M. Ghosh (71\')'],
          )
        ];
      case 'Kabaddi':
        return [
          TeamMatchResult(
            teamA: 'Vidyalankar Raiders',
            teamB: 'Polytechnic Panthers',
            scoreA: '39',
            scoreB: '47',
            result: 'Polytechnic Panthers won by 8 points',
            highlights: ['Top Raider: S. Jadhav (15 raid points)', 'Top Defender: A. More (5 tackle points)'],
          )
        ];
      case 'Volleyball':
        return [
          VolleyballMatchResult(
            teamA: 'Vidyalankar Spikers',
            teamB: 'Polytechnic Smashers',
            result: '3-2 Sets (Polytechnic Smashers won)',
            bestPlayer: 'Best Player: R. Naik (12 spikes, 3 blocks)',
            setScores: ['25-20', '22-25', '23-25', '25-18', '9-15'],
          )
        ];
      case 'Athletics':
        return [
          AthleticsResult(
            event: '100m Race',
            winner: 'S. Mehta (Vidyalankar)',
            podium: [
              {'position': '1st', 'athlete': 'S. Mehta', 'time': '11.2s'},
              {'position': '2nd', 'athlete': 'R. Singh', 'time': '11.5s'},
              {'position': '3rd', 'athlete': 'M. Khan', 'time': '11.8s'},
            ]
          )
        ];
      case 'Table Tennis':
        return [
          PlayerMatchResult(
            playerA: 'R. Patel',
            playerB: 'M. Joshi',
            result: 'R. Patel won 3-1',
            gameScores: ['11-8', '7-11', '11-9', '11-6'],
          )
        ];
      case 'Badminton':
        return [
          PlayerMatchResult(
            playerA: 'S. Patil',
            playerB: 'R. Sharma',
            result: 'S. Patil won 2-1',
            gameScores: ['21-18', '18-21', '21-17'],
          )
        ];
      case 'Chess':
        return [
          ChessMatchResult(
            teamA: 'Vidyalankar',
            teamB: 'Polytechnic',
            result: 'Match Draw (1.5 - 1.5)',
            boardResults: [
              {'playerWhite': 'A. Nair', 'playerBlack': 'R. Shah', 'result': '1-0'},
              {'playerWhite': 'P. Desai', 'playerBlack': 'S. Khan', 'result': '0-1'},
              {'playerWhite': 'V. Mehta', 'playerBlack': 'T. Rao', 'result': '½-½'},
            ],
          )
        ];
      case 'Carrom':
        return [
          CarromMatchResult(
            playerA: 'K. Shetty',
            playerB: 'P. Gawade',
            result: 'K. Shetty won 2-0',
            roundScores: ['25-18', '25-22'],
          )
        ];
      default:
        return [];
    }
  }
}

