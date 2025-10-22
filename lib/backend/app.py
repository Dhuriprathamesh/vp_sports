from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
from datetime import datetime

# Initialize the Flask app
app = Flask(__name__)
# Enable CORS to allow requests from your Flutter app
CORS(app)

# --- Your Database Credentials ---
DB_NAME = "vpsports"
DB_USER = "postgres"
DB_PASS = "post27"
DB_HOST = "localhost"
DB_PORT = "5432"  # Default PostgreSQL port

def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            host=DB_HOST,
            port=DB_PORT
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"Error connecting to database: {e}")
        return None

@app.route('/api/add_cricket_match', methods=['POST'])
def add_cricket_match():
    """API endpoint to add a new cricket match."""
    data = request.get_json()
    if not data:
        return jsonify({"status": "error", "message": "No data received"}), 400

    print("Received data for new match:", data)

    try:
        team_a_name = data.get('team_a_name')
        team_b_name = data.get('team_b_name')
        team_a_players = data.get('team_a_players', [])
        team_b_players = data.get('team_b_players', [])
        overs_str = data.get('overs')
        start_time_str = data.get('start_time')
        venue = data.get('venue')
        umpires = data.get('umpires', [])

        if not all([team_a_name, team_b_name, overs_str, start_time_str, venue]):
             return jsonify({"status": "error", "message": "Missing required fields"}), 400

        overs_per_innings = int(overs_str)
        start_time = datetime.fromisoformat(start_time_str.replace(' ', 'T'))

        conn = get_db_connection()
        if conn is None:
            return jsonify({"status": "error", "message": "Database connection failed"}), 500
        
        cur = conn.cursor()
        insert_query = """
        INSERT INTO cricket_match (
            team_a_name, team_b_name, team_a_players, team_b_players, 
            overs_per_innings, start_time, venue, umpires, match_status
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming');
        """
        sql_data = (
            team_a_name, team_b_name, team_a_players, team_b_players,
            overs_per_innings, start_time, venue, umpires
        )

        cur.execute(insert_query, sql_data)
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "success", "message": "Match added successfully"}), 201

    except (Exception, psycopg2.Error) as e:
        print(f"Error during database operation: {e}")
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500

@app.route('/api/get_matches/<sport_name>', methods=['GET'])
def get_matches(sport_name):
    """API endpoint to fetch matches based on their status."""
    status = request.args.get('status', 'upcoming')

    if sport_name.lower() != 'cricket':
        return jsonify([]) 
    
    matches = []
    conn = get_db_connection()
    if conn is None:
        return jsonify({"status": "error", "message": "Database connection failed"}), 500
        
    try:
        cur = conn.cursor()
        
        # MODIFIED: Changed 'id' to 'match_id' to match your database schema
        if status == 'live':
            query = """
            SELECT match_id, team_a_name, team_b_name, venue, start_time 
            FROM cricket_match 
            WHERE match_status = 'live' 
            ORDER BY start_time ASC;
            """
        else: # Default to upcoming
            query = """
            SELECT match_id, team_a_name, team_b_name, venue, start_time 
            FROM cricket_match 
            WHERE match_status = 'upcoming' AND start_time > NOW()
            ORDER BY start_time ASC;
            """
            
        cur.execute(query)
        match_rows = cur.fetchall()
        
        cur.close()
        conn.close()

        for row in match_rows:
            matches.append({
                "id": row[0], # The app expects 'id', so we map 'match_id' to 'id' here
                "teamA": row[1],
                "teamB": row[2],
                "venue": row[3],
                "date": row[4].strftime('%b %d'),
                "time": row[4].strftime('%I:%M %p'),
            })
            
        return jsonify(matches)

    except (Exception, psycopg2.Error) as e:
        print(f"Error fetching matches for status '{status}': {e}")
        return jsonify([])

@app.route('/api/get_match_details/<int:match_id>', methods=['GET'])
def get_match_details(match_id):
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"status": "error", "message": "Database connection failed"}), 500
        
        cur = conn.cursor()
        # MODIFIED: Changed 'id' to 'match_id'
        query = "SELECT * FROM cricket_match WHERE match_id = %s;"
        cur.execute(query, (match_id,))
        match = cur.fetchone()
        cur.close()
        conn.close()

        if not match:
            return jsonify({"status": "error", "message": "Match not found"}), 404
        
        # MODIFIED: Correctly map the columns from your screenshot
        match_details = {
            "id": match[0],
            "team_a_name": match[1],
            "team_b_name": match[2],
            "team_a_players": match[3],
            "team_b_players": match[4],
            "overs_per_innings": match[5],
            "start_time": match[6].isoformat(),
            "venue": match[7],
            "umpires": match[8],
            "match_status": match[10] # match_status is the 11th column (index 10)
        }
        return jsonify(match_details)

    except (Exception, psycopg2.Error) as e:
        print(f"Error fetching match details: {e}")
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500

@app.route('/api/start_match/<int:match_id>', methods=['POST'])
def start_match(match_id):
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"status": "error", "message": "Database connection failed"}), 500

        cur = conn.cursor()
        # MODIFIED: Changed 'id' to 'match_id'
        query = "UPDATE cricket_match SET match_status = 'live' WHERE match_id = %s;"
        cur.execute(query, (match_id,))
        conn.commit()

        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "Match not found or already live"}), 404
        
        cur.close()
        conn.close()
        return jsonify({"status": "success", "message": "Match started successfully"}), 200

    except (Exception, psycopg2.Error) as e:
        print(f"Error starting match: {e}")
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

