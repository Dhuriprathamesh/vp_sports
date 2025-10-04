class MockData {
  static final List<Map<String, dynamic>> matches = [
    {
      "id": 1,
      "sport": "Cricket",
      "teams": "CO3KA vs IF4KB",
      "time": "10:00 AM",
      "date": "2025-10-05",
      "venue": "Ground A",
      "status": "Upcoming",
      "score": ""
    },
    {
      "id": 2,
      "sport": "Football",
      "teams": "TE2KC vs EJ6KA",
      "time": "12:30 PM",
      "date": "2025-10-05",
      "venue": "Ground B",
      "status": "Live",
      "score": "1 - 0"
    },
    {
      "id": 3,
      "sport": "Badminton",
      "teams": "IF1KB vs CO2KA",
      "time": "2:00 PM",
      "date": "2025-10-06",
      "venue": "Indoor Hall",
      "status": "Finished",
      "score": "21-18, 19-21, 21-17"
    },
  ];

  static final List<Map<String, dynamic>> leaderboard = [
    {
      "class": "CO3KA",
      "played": 3,
      "won": 3,
      "lost": 0,
      "points": 9,
    },
    {
      "class": "IF4KB",
      "played": 3,
      "won": 2,
      "lost": 1,
      "points": 6,
    },
    {
      "class": "TE2KC",
      "played": 2,
      "won": 1,
      "lost": 1,
      "points": 3,
    },
    {
      "class": "EJ6KA",
      "played": 2,
      "won": 0,
      "lost": 2,
      "points": 0,
    },
  ];
}
