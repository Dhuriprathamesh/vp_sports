import decimal
import json # Make sure json is imported
from flask import Flask, request, jsonify, send_file # <-- IMPORT send_file
from flask_cors import CORS
import psycopg2
from datetime import datetime
import traceback # Import traceback for detailed error logging
import io # <-- ADD THIS IMPORT

# --- ADD ALL REPORTLAB IMPORTS ---
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle # <-- Add ParagraphStyle
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import inch
from reportlab.lib import colors
# --- END REPORTLAB IMPORTS ---


# Helper to convert Decimal/Datetime to JSON serializable types
class CustomEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            # Convert Decimal to string to preserve precision, then float if needed client-side
            return str(o) # Or float(o) if precision loss is acceptable
        if isinstance(o, datetime):
            return o.isoformat() # Convert datetime to ISO 8601 string format
        return super(CustomEncoder, self).default(o)

# -------------------- APP SETUP --------------------
app = Flask(__name__)
app.json_encoder = CustomEncoder # Use the custom encoder
CORS(app)

# --- Your Database Credentials ---
DB_NAME = "vpsports"
DB_USER = "postgres"
DB_PASS = "post27"
DB_HOST = "localhost"
DB_PORT = "5432"  # Default PostgreSQL port

def get_db_connection():
    try:
        conn = psycopg2.connect( dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT )
        return conn
    except psycopg2.OperationalError as e:
        print(f"Error connecting to database: {e}")
        return None

# --- Function to ensure DB schema ---
def check_and_update_schema():
    # Targets 'cricket_match_livescore'
    conn_check = get_db_connection()
    if not conn_check:
        print("Schema Check Failed: Could not connect to DB.")
        return
    cur_check = conn_check.cursor()
    target_table = 'cricket_match_livescore' # Define target table name
    try:
        # Check if table exists, create if not
        cur_check.execute(f"""
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = '{target_table}'
            );
        """)
        table_exists = cur_check.fetchone()[0]

        if not table_exists:
            print(f"Table '{target_table}' does not exist. Creating it...")
            # Execute the CREATE TABLE query from the previous step
            create_table_query = """
                CREATE TABLE cricket_match_livescore (
                    live_score_id SERIAL PRIMARY KEY,
                    match_id INTEGER NOT NULL UNIQUE REFERENCES cricket_match(match_id) ON DELETE CASCADE,
                    toss_winner TEXT,
                    toss_decision TEXT CHECK (toss_decision IN ('Bat', 'Bowl')),
                    current_status TEXT DEFAULT 'upcoming',
                    live_result TEXT,
                    break_status TEXT,
                    team1_name TEXT,
                    team2_name TEXT,
                    team1_runs INTEGER DEFAULT 0 NOT NULL,
                    team1_wickets INTEGER DEFAULT 0 NOT NULL,
                    team1_balls INTEGER DEFAULT 0 NOT NULL,
                    team2_runs INTEGER DEFAULT 0 NOT NULL,
                    team2_wickets INTEGER DEFAULT 0 NOT NULL,
                    team2_balls INTEGER DEFAULT 0 NOT NULL,
                    team1_extras INTEGER DEFAULT 0 NOT NULL,
                    team2_extras INTEGER DEFAULT 0 NOT NULL,
                    summary_text TEXT,
                    striker_id INTEGER,
                    non_striker_id INTEGER,
                    bowler_id INTEGER,
                    is_first_innings BOOLEAN DEFAULT TRUE NOT NULL,
                    target_score INTEGER,
                    first_innings_balls INTEGER,
                    team1_batting_stats JSONB DEFAULT '[]'::jsonb,
                    team2_bowling_stats JSONB DEFAULT '[]'::jsonb,
                    team2_batting_stats JSONB DEFAULT '[]'::jsonb,
                    team1_bowling_stats JSONB DEFAULT '[]'::jsonb,
                    team1_timeline TEXT[] DEFAULT ARRAY[]::TEXT[],
                    team2_timeline TEXT[] DEFAULT ARRAY[]::TEXT[],
                    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
            """
            cur_check.execute(create_table_query)
            conn_check.commit()
            print(f"Table '{target_table}' created successfully.")
        else:
             print(f"Table '{target_table}' already exists. Checking columns...")
             # If table exists, proceed with column checks/adds
             alter_commands = [
                 # Check/Add match_id column and constraints (only if table wasn't just created)
                 f"""DO $$ BEGIN
                   IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='{target_table}' AND column_name='match_id') THEN
                       ALTER TABLE {target_table} ADD COLUMN match_id INTEGER; RAISE NOTICE 'Column match_id added.';
                   ELSE RAISE NOTICE 'Column match_id already exists.'; END IF;

                   IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'cricket_match') AND
                      NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name='{target_table}' AND constraint_name='{target_table}_match_id_fkey') THEN
                       ALTER TABLE {target_table} ADD CONSTRAINT {target_table}_match_id_fkey FOREIGN KEY (match_id) REFERENCES cricket_match(match_id) ON DELETE CASCADE; RAISE NOTICE 'Foreign key {target_table}_match_id_fkey added.';
                   END IF;

                   IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name='{target_table}' AND constraint_name='{target_table}_match_id_key') THEN
                       ALTER TABLE {target_table} ADD CONSTRAINT {target_table}_match_id_key UNIQUE (match_id); RAISE NOTICE 'Unique constraint {target_table}_match_id_key added.';
                   END IF;
                END $$;""",
                # Add other necessary columns if they don't exist
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS toss_winner TEXT",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS toss_decision TEXT CHECK (toss_decision IN ('Bat', 'Bowl'))",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS current_status TEXT DEFAULT 'upcoming'",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS live_result TEXT",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS break_status TEXT",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_name TEXT",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_name TEXT",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_runs INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_wickets INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_balls INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_runs INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_wickets INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_balls INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_extras INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_extras INTEGER DEFAULT 0 NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS summary_text TEXT",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS striker_id INTEGER",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS non_striker_id INTEGER",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS bowler_id INTEGER",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS is_first_innings BOOLEAN DEFAULT TRUE NOT NULL",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS target_score INTEGER",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS first_innings_balls INTEGER",
                # Add JSONB columns for player stats
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_batting_stats JSONB DEFAULT '[]'::jsonb",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_bowling_stats JSONB DEFAULT '[]'::jsonb",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_batting_stats JSONB DEFAULT '[]'::jsonb",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_bowling_stats JSONB DEFAULT '[]'::jsonb",
                # Add last_updated column
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
                # --- MODIFICATION: Add separate timelines ---
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team1_timeline TEXT[] DEFAULT ARRAY[]::TEXT[]",
                f"ALTER TABLE {target_table} ADD COLUMN IF NOT EXISTS team2_timeline TEXT[] DEFAULT ARRAY[]::TEXT[]"
                # f"ALTER TABLE {target_table} DROP COLUMN IF EXISTS timeline" # Optional: to clean up
                # --- END MODIFICATION ---
            ]
             for command in alter_commands:
                 # print(f"Executing: {command}") # Optional: uncomment for verbose logging
                 cur_check.execute(command)
             conn_check.commit()
             print(f"Checked/Added necessary columns to {target_table}.")

        # Ensure the trigger function exists
        cur_check.execute("""
            CREATE OR REPLACE FUNCTION update_last_updated_column()
            RETURNS TRIGGER AS $$
            BEGIN
               NEW.last_updated = NOW();
               RETURN NEW;
            END;
            $$ language 'plpgsql';
        """)

        # Ensure the trigger exists on the target table
        cur_check.execute(f"""
            DO $$ BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_trigger
                    WHERE tgname = 'update_{target_table}_last_updated' AND tgrelid = '{target_table}'::regclass
                ) THEN
                    CREATE TRIGGER update_{target_table}_last_updated
                    BEFORE UPDATE ON {target_table}
                    FOR EACH ROW
                    EXECUTE FUNCTION update_last_updated_column();
                    RAISE NOTICE 'Trigger update_{target_table}_last_updated created.';
                ELSE
                    RAISE NOTICE 'Trigger update_{target_table}_last_updated already exists.';
                END IF;
            END $$;
        """)
        conn_check.commit()
        print(f"Ensured last_updated trigger exists for {target_table}.")

    except (Exception, psycopg2.Error) as e:
        print(f"Error checking/creating/altering table {target_table}: {e}")
        traceback.print_exc()
        try: conn_check.rollback()
        except Exception as rb_e: print(f"Rollback failed: {rb_e}")
    finally:
        if cur_check and not cur_check.closed: cur_check.close()
        if conn_check and not conn_check.closed: conn_check.close()


# -------------------- cricket_match endpoints --------------------
@app.route('/api/add_cricket_match', methods=['POST'])
def add_cricket_match():
    data = request.get_json()
    conn = None
    cur = None
    if not data: return jsonify({"status": "error", "message": "No data received"}), 400
    new_match_id = None # Initialize new_match_id
    try:
        team_a_name = data.get('team_a_name'); team_b_name = data.get('team_b_name'); team_a_players = data.get('team_a_players', []); team_b_players = data.get('team_b_players', []); overs_str = data.get('overs'); start_time_str = data.get('start_time'); venue = data.get('venue'); umpires = data.get('umpires', [])
        if not all([team_a_name, team_b_name, overs_str, start_time_str, venue]): return jsonify({"status": "error", "message": "Missing required fields"}), 400
        overs_per_innings = int(overs_str)
        try: start_time = datetime.fromisoformat(start_time_str.replace('Z', '+00:00'))
        except ValueError: start_time = datetime.fromisoformat(start_time_str.replace(' ', 'T').replace('Z', '+00:00'))

        conn = get_db_connection()
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()

        # Insert into cricket_match
        insert_query = "INSERT INTO cricket_match (team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming') RETURNING match_id"
        sql_data = (team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires)
        cur.execute(insert_query, sql_data)
        result = cur.fetchone()
        if result is None:
             raise Exception("Failed to retrieve new match_id after inserting into cricket_match.")
        new_match_id = result[0]
        print(f"Successfully inserted into cricket_match, new match_id: {new_match_id}") # Log success

        # Insert initial livescore record
        init_live_update_query = "INSERT INTO cricket_match_livescore (match_id, team1_name, team2_name, current_status, summary_text) VALUES (%s, %s, %s, %s, %s) ON CONFLICT (match_id) DO NOTHING"
        init_live_update_data = (new_match_id, team_a_name, team_b_name, 'upcoming', 'Match hasn\'t started yet.')
        cur.execute(init_live_update_query, init_live_update_data)
        # --- Add Logging ---
        print(f"Executed initial INSERT/ON CONFLICT for cricket_match_livescore for match_id: {new_match_id}. Rowcount: {cur.rowcount}")
        if cur.rowcount == 0:
            print(f"WARN: Initial livescore row for match_id {new_match_id} might have already existed (ON CONFLICT triggered).")
        # --- End Logging ---

        conn.commit() # Commit both inserts together
        print(f"Committed transaction for match_id: {new_match_id}") # Log commit

        return jsonify({"status": "success", "message": "Match added successfully", "match_id": new_match_id}), 201
    except (Exception, psycopg2.Error) as e:
        print(f"Error adding match (match_id might be {new_match_id}): {e}") # Include match_id if available
        traceback.print_exc()
        try:
            if conn: conn.rollback()
        except Exception as rb_e: print(f"Rollback failed: {rb_e}")
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()

# ... rest of the code is unchanged ...

@app.route('/api/get_matches/<sport_name>', methods=['GET'])
def get_matches(sport_name):
    status_param = request.args.get('status', 'upcoming') # Get requested status
    matches = []
    conn = None
    cur = None

    if sport_name.lower() != 'cricket':
        return jsonify([])

    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()

        # Determine the target status for the DB query
        if status_param == 'recent':
            db_status = 'finished'
        elif status_param == 'live':
            db_status = 'live'
        elif status_param == 'upcoming':
            db_status = 'upcoming'
        else:
            return jsonify({"status": "error", "message": "Invalid status parameter"}), 400

        # Build the query
        base_query = """
            SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status,
                   ls.team1_runs, ls.team1_wickets, ls.team1_balls,
                   ls.team2_runs, ls.team2_wickets, ls.team2_balls, ls.summary_text, ls.live_result
            FROM cricket_match cm
            LEFT JOIN cricket_match_livescore ls ON cm.match_id = ls.match_id
            WHERE cm.match_status = %s
        """
        order_by = ""

        if db_status == 'live':
            order_by = " ORDER BY cm.start_time ASC"
        elif db_status == 'finished':
            order_by = " ORDER BY cm.start_time DESC" # Recent first
        elif db_status == 'upcoming':
            base_query += " AND cm.start_time > NOW()" # Only future upcoming
            order_by = " ORDER BY cm.start_time ASC"

        query = base_query + order_by
        cur.execute(query, (db_status,)) # Use the determined db_status
        match_rows = cur.fetchall()

        for row in match_rows:
            # --- Helper to format score string ---
            def format_score(runs, wickets, balls):
                if runs is None or wickets is None or balls is None:
                    return "0/0 (0.0)" # Default if no score data
                overs = balls // 6
                balls_rem = balls % 6
                return f"{runs}/{wickets} ({overs}.{balls_rem})"

            match_data = {
                "id": row[0],
                "teamA": row[1],
                "teamB": row[2],
                "venue": row[3],
                "date": row[4].strftime('%b %d'),
                "time": row[4].strftime('%I:%M %p'),
                "status": row[5], # Actual status from cricket_match table
                "scoreA": format_score(row[6], row[7], row[8]), # Formatted score A
                "scoreB": format_score(row[9], row[10], row[11]), # Formatted score B
                "summary": row[12], # Live summary or potentially pre-match text
                "result": row[13] # Final result text (only relevant for 'finished')
            }
            matches.append(match_data)

        return jsonify(matches)
    except (Exception, psycopg2.Error) as e:
        print(f"Error fetching matches ({status_param}): {e}") # Log the original param
        traceback.print_exc()
        return jsonify([]) # Return empty list on error
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()


@app.route('/api/get_match_details/<int:match_id>', methods=['GET'])
def get_match_details(match_id):
    conn = None
    cur = None
    try:
        conn = get_db_connection()
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()
        query = "SELECT match_id, team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires, match_status FROM cricket_match WHERE match_id = %s"
        cur.execute(query, (match_id,))
        match = cur.fetchone()
        if not match: return jsonify({"status": "error", "message": "Match not found"}), 404
        match_details = { "id": match[0], "team_a_name": match[1], "team_b_name": match[2], "team_a_players": match[3] if match[3] else [], "team_b_players": match[4] if match[4] else [], "overs_per_innings": match[5], "start_time": match[6].isoformat(), "venue": match[7], "umpires": match[8] if match[8] else [], "match_status": match[9] }
        return jsonify(match_details)
    except (Exception, psycopg2.Error) as e:
        print(f"Error fetching match details: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()

@app.route('/api/start_match/<int:match_id>', methods=['POST'])
def start_match(match_id):
    conn = None
    cur = None
    try:
        conn = get_db_connection()
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()
        # Check current status first
        cur.execute("SELECT match_status FROM cricket_match WHERE match_id = %s", (match_id,))
        current_status_row = cur.fetchone()
        if not current_status_row:
             return jsonify({"status": "error", "message": "Match not found"}), 404
        current_status = current_status_row[0]

        if current_status == 'live':
             return jsonify({"status": "error", "message": "Match is already live"}), 400
        if current_status == 'finished':
             return jsonify({"status": "error", "message": "Match has already finished"}), 400
        if current_status != 'upcoming':
             return jsonify({"status": "error", "message": f"Match cannot be started (status: {current_status})"}), 400

        # Proceed with update if status is 'upcoming'
        query_match = "UPDATE cricket_match SET match_status = 'live' WHERE match_id = %s"
        cur.execute(query_match, (match_id,))
        # No need to check rowcount again, already validated status

        query_live = "UPDATE cricket_match_livescore SET current_status = 'live' WHERE match_id = %s"
        cur.execute(query_live, (match_id,))
        conn.commit()
        return jsonify({"status": "success", "message": "Match started successfully"}), 200
    except (Exception, psycopg2.Error) as e:
        print(f"Error starting match: {e}")
        traceback.print_exc()
        try:
            if conn: conn.rollback()
        except Exception as rb_e: print(f"Rollback failed: {rb_e}")
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()


# --- DEPRECATED admin_cri_live, upcoming, recent endpoints ---


# -------------------- cricket_match_livescore endpoints --------------------

@app.route('/api/update_live_score/<int:match_id>', methods=['POST'])
def update_live_score(match_id):
    data = request.get_json()
    conn = None
    cur = None
    if not data: return jsonify({"status": "error", "message": "No data received"}), 400
    try:
        conn = get_db_connection()
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()

        # Core columns to update directly
        core_columns = [
            "toss_winner", "toss_decision", "current_status", "live_result", "break_status",
            "team1_name", "team2_name", "team1_runs", "team1_wickets", "team1_balls",
            "team2_runs", "team2_wickets", "team2_balls", "team1_extras", "team2_extras",
            "summary_text", "striker_id", "non_striker_id", "bowler_id",
            "is_first_innings", "target_score", "first_innings_balls",
            # "timeline" # <-- REMOVED
        ]
        values_dict = {"match_id": match_id}
        for col in core_columns:
            values_dict[col] = data.get(col) # Use .get() for safety

        # --- MODIFICATION: Add new timeline values ---
        values_dict["team1_timeline"] = data.get("team1_timeline", [])
        values_dict["team2_timeline"] = data.get("team2_timeline", [])
        # --- END MODIFICATION ---

        # Prepare JSON data for player stats, ensuring it's valid JSON string
        values_dict["team1_batting_stats"] = json.dumps(data.get("team1_batting", []) or [])
        values_dict["team2_bowling_stats"] = json.dumps(data.get("team2_bowling", []) or [])
        values_dict["team2_batting_stats"] = json.dumps(data.get("team2_batting", []) or [])
        values_dict["team1_bowling_stats"] = json.dumps(data.get("team1_bowling", []) or [])

        # Build the UPSERT query targeting the correct table
        all_columns = ["match_id"] + core_columns + [
            "team1_batting_stats", "team2_bowling_stats",
            "team2_batting_stats", "team1_bowling_stats",
            "team1_timeline", "team2_timeline" # <-- ADDED THESE
        ]
        placeholders = ", ".join(["%s"] * len(all_columns))
        update_assignments = ", ".join([f"{col} = EXCLUDED.{col}" for col in all_columns if col != "match_id"])
        update_assignments += ", last_updated = NOW()" # Add automatic timestamp update

        sql = f"""
            INSERT INTO cricket_match_livescore ({", ".join(all_columns)})
            VALUES ({placeholders})
            ON CONFLICT (match_id) DO UPDATE SET {update_assignments}
        """

        values_tuple = tuple(values_dict[col] for col in all_columns)

        cur.execute(sql, values_tuple)
        conn.commit() # Commit livescore update first

        # --- MODIFICATION: Update cricket_match status if finished ---
        if values_dict.get("current_status") == "Finished":
            try:
                # Update the main cricket_match table status
                cur.execute("UPDATE cricket_match SET match_status = 'finished' WHERE match_id = %s AND match_status != 'finished'", (match_id,)) # Add condition to avoid redundant updates
                conn.commit() # Commit the status update
                print(f"Match {match_id} status updated to finished in cricket_match table.")
            except (Exception, psycopg2.Error) as update_err:
                print(f"Error updating match_status in cricket_match for {match_id}: {update_err}")
                # Log error, but don't rollback the livescore update
                # Optionally, you could try to rollback the status update only,
                # but it might be better to just log it and potentially fix manually.
        # --- END MODIFICATION ---

        return jsonify({"status": "success", "message": "Live score updated"}), 200
    except (Exception, psycopg2.Error) as e:
        print(f"Error updating live score {match_id}: {e}")
        traceback.print_exc()
        try:
            if conn: conn.rollback() # Rollback livescore update on error
        except Exception as rb_e: print(f"Rollback failed: {rb_e}")
        error_message = f"An error occurred: {str(e)}"
        if "check constraint" in str(e).lower():
             error_message = "Invalid data provided (e.g., toss decision wasn't 'Bat' or 'Bowl')."
        return jsonify({"status": "error", "message": error_message}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()


@app.route('/api/get_live_updates/<int:match_id>', methods=['GET'])
def get_live_updates(match_id):
    """ Fetches the latest full live update state for a specific match.
        Creates a default record if none exists. """
    conn = None
    cur = None
    try:
        conn = get_db_connection()
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()

        # --- MODIFICATION: Try to select first ---
        all_columns = [
            "match_id", "toss_winner", "toss_decision", "current_status", "live_result", "break_status",
            "team1_name", "team2_name", "team1_runs", "team1_wickets", "team1_balls",
            "team2_runs", "team2_wickets", "team2_balls", "team1_extras", "team2_extras",
            "summary_text", "striker_id", "non_striker_id", "bowler_id",
            "is_first_innings", "target_score", "first_innings_balls",
            "team1_batting_stats", "team2_bowling_stats",
            "team2_batting_stats", "team1_bowling_stats", "last_updated",
            # "timeline" # <-- REMOVED
            "team1_timeline", "team2_timeline" # <-- ADDED
        ]
        query = f"SELECT {', '.join(all_columns)} FROM cricket_match_livescore WHERE match_id = %s"
        cur.execute(query, (match_id,))
        row = cur.fetchone()

        if not row:
            # --- If no row found, try to create a default one ---
            print(f"No livescore data found for match_id {match_id}. Attempting to create default.")
            # 1. Check if the match exists in cricket_match and get team names/status
            cur.execute("SELECT team_a_name, team_b_name, match_status FROM cricket_match WHERE match_id = %s", (match_id,))
            match_info = cur.fetchone()

            if not match_info:
                # If match itself doesn't exist, return 404
                print(f"Match {match_id} not found in cricket_match table either.")
                return jsonify({"status": "error", "message": "Match not found"}), 404

            team_a_name, team_b_name, match_status = match_info
            initial_status = 'live' if match_status == 'live' else 'upcoming'
            initial_summary = 'Match hasn\'t started yet.' if initial_status == 'upcoming' else 'Toss will happen soon.'

            # 2. Insert the default row
            try:
                insert_default_query = """
                    INSERT INTO cricket_match_livescore (match_id, team1_name, team2_name, current_status, summary_text)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (match_id) DO NOTHING -- Safety net
                    RETURNING match_id, team1_name, team2_name, current_status, summary_text, is_first_innings, last_updated
                """
                cur.execute(insert_default_query, (match_id, team_a_name, team_b_name, initial_status, initial_summary))
                inserted_row_data = cur.fetchone()
                conn.commit()

                if inserted_row_data:
                    print(f"Successfully created default livescore row for match_id {match_id}.")
                    # Construct a default response dictionary similar to a full fetch
                    default_data = {
                        "match_id": inserted_row_data[0], "team1_name": inserted_row_data[1], "team2_name": inserted_row_data[2],
                        "current_status": inserted_row_data[3], "summary_text": inserted_row_data[4],
                        "is_first_innings": inserted_row_data[5], "last_updated": inserted_row_data[6],
                        # Add null/default values for all other fields expected by Flutter
                        "toss_winner": None, "toss_decision": None, "live_result": None, "break_status": None,
                        "team1_runs": 0, "team1_wickets": 0, "team1_balls": 0,
                        "team2_runs": 0, "team2_wickets": 0, "team2_balls": 0,
                        "team1_extras": 0, "team2_extras": 0,
                        "striker_id": None, "non_striker_id": None, "bowler_id": None,
                        "target_score": None, "first_innings_balls": None,
                        "team1_batting": [], "team2_bowling": [],
                        "team2_batting": [], "team1_bowling": [],
                        # "timeline": [] # <-- REMOVED
                        "team1_timeline": [], "team2_timeline": [] # <-- ADDED
                    }
                    return jsonify(default_data), 200 # Return 200 with default data
                else:
                    # Insert failed (likely due to conflict), re-query
                    print(f"Default insert for match_id {match_id} returned no data (maybe conflict). Re-querying.")
                    cur.execute(query, (match_id,))
                    row = cur.fetchone()
                    if not row: # Should not happen if conflict occurred, but safety check
                         print(f"ERROR: Failed to insert default and re-query failed for match_id {match_id}.")
                         return jsonify({"status": "error", "message": "Failed to initialize live score data"}), 500

            except (Exception, psycopg2.Error) as insert_err:
                print(f"Error creating default livescore row for match_id {match_id}: {insert_err}")
                traceback.print_exc()
                conn.rollback() # Rollback the failed insert attempt
                return jsonify({"status": "error", "message": "Failed to initialize live score data"}), 500
        # --- End of default row creation logic ---

        # --- If row was found initially (or after default creation and re-query) ---
        colnames = [desc[0] for desc in cur.description]
        data = dict(zip(colnames, row))

        # Rename JSONB columns for Flutter app
        data["team1_batting"] = data.get("team1_batting_stats") or []
        data["team2_bowling"] = data.get("team2_bowling_stats") or []
        data["team2_batting"] = data.get("team2_batting_stats") or []
        data["team1_bowling"] = data.get("team1_bowling_stats") or []

        return jsonify(data), 200
        # --- End row processing ---

    except (Exception, psycopg2.Error) as e:
        print(f"Error getting live updates {match_id}: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()


# -------------------- Simplified live score endpoint (for User View Polling) --------------------
@app.route('/api/get_live_score/<int:match_id>', methods=['GET'])
def get_live_score(match_id):
    """ Fetches simplified summary data plus detailed stats needed for the user view scorecard. """
    conn = None; cur = None
    try:
        conn = get_db_connection();
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()
        # --- Fetch ALL necessary columns for the detailed view ---
        query = """
            SELECT
                ls.team1_name, ls.team2_name, ls.team1_runs, ls.team1_wickets, ls.team1_balls,
                ls.team2_runs, ls.team2_wickets, ls.team2_balls, ls.summary_text,
                ls.striker_id, ls.non_striker_id, ls.bowler_id, ls.is_first_innings,
                ls.toss_winner, ls.toss_decision, ls.current_status,
                ls.team1_batting_stats, ls.team2_bowling_stats,
                ls.team2_batting_stats, ls.team1_bowling_stats,
                ls.live_result,
                ls.team1_extras, ls.team2_extras, -- Fetch extras
                -- ls.timeline -- <-- REMOVED
                ls.team1_timeline, ls.team2_timeline -- <-- ADDED
            FROM cricket_match_livescore ls
            WHERE ls.match_id = %s
            """
        cur.execute(query, (match_id,))
        live_data_row = cur.fetchone()

        if not live_data_row:
            # Fallback logic remains the same (returns minimal data)
            cur.execute("SELECT team_a_name, team_b_name, match_status FROM cricket_match WHERE match_id = %s", (match_id,))
            match_info = cur.fetchone()
            if not match_info: return jsonify({"status": "error", "message": "Match not found"}), 404

            t1_name_fallback, t2_name_fallback, status_fallback = match_info
            summary_fallback = "Match hasn't started yet."
            status_text_fallback = "Upcoming"
            if status_fallback == 'live':
                 summary_fallback = "Toss will happen soon."
                 status_text_fallback = "Live"
            elif status_fallback == 'finished':
                live_result_fallback = "Match Finished"
                try:
                    cur.execute("SELECT live_result FROM cricket_match_livescore WHERE match_id = %s", (match_id,))
                    result_row_fallback = cur.fetchone()
                    if result_row_fallback and result_row_fallback[0]:
                         live_result_fallback = result_row_fallback[0]
                except: pass
                summary_fallback = live_result_fallback
                status_text_fallback = "Finished"

            # --- Include default empty/zero values for detailed fields in fallback ---
            initial_score_data = {
                "match_id": match_id, "team_a_name": t1_name_fallback, "team_b_name": t2_name_fallback,
                "team_a_score": "0/0", "team_a_overs": "(0.0)",
                "team_b_score": "0/0", "team_b_overs": "(0.0)",
                "match_status_text": status_text_fallback, "summary_text": summary_fallback,
                "batting_team_name": None, "bowling_team_name": None,
                "batsman_on_strike_name": "N/A", "batsman_on_strike_score": "-",
                "batsman_off_strike_name": "N/A", "batsman_off_strike_score": "-",
                "bowler_on_strike_name": "N/A", "bowler_on_strike_figures": "-",
                "bowler_off_strike_name": "N/A", "bowler_off_strike_figures": "-",
                "team1_batting": [], "team2_bowling": [], # Send empty lists
                "team2_batting": [], "team1_bowling": [], # Send empty lists
                "team1_extras": 0, "team2_extras": 0, # Send zero extras
                "is_first_innings": True, # Assume first innings if upcoming/toss
                # "timeline": [] # <-- REMOVED
                "team1_timeline": [], "team2_timeline": [] # <-- ADDED
            }
            return jsonify(initial_score_data), 200

        # --- Process detailed live_data_row (Column order matters!) ---
        (t1_name, t2_name, t1_runs, t1_wickets, t1_balls, t2_runs, t2_wickets, t2_balls, summary,
         striker_id, non_striker_id, bowler_id, is_first,
         toss_winner_name, toss_decision_val, current_status,
         t1_bat_stats_json, t2_bowl_stats_json, t2_bat_stats_json, t1_bowl_stats_json,
         live_result, team1_extras, team2_extras,
         # timeline) = live_data_row # <-- REMOVED
         team1_timeline, team2_timeline) = live_data_row # <-- ADDED
        # --- END Process detailed live_data_row ---


        batting_team_name, bowling_team_name = None, None
        striker_name, striker_score = "N/A", "-"
        non_striker_name, non_striker_score = "N/A", "-"
        bowler_name, bowler_figures = "N/A", "-"

        # Determine batting/bowling teams
        if is_first is not None and toss_winner_name and toss_decision_val:
            team_a_bats_first = (toss_winner_name == t1_name and toss_decision_val.lower() == 'bat') or \
                                (toss_winner_name == t2_name and toss_decision_val.lower() == 'bowl')
            if is_first:
                batting_team_name = t1_name if team_a_bats_first else t2_name
                bowling_team_name = t2_name if team_a_bats_first else t1_name
            else:
                batting_team_name = t2_name if team_a_bats_first else t1_name
                bowling_team_name = t1_name if team_a_bats_first else t2_name

            # Function to find player stats from JSONB data (Remains the same)
            def get_player_stats_from_json(player_id, is_batsman):
                if player_id is None: return "N/A", "-"
                stats_list = []
                # Use correct JSON variable
                if is_batsman: stats_list = t1_bat_stats_json if batting_team_name == t1_name else t2_bat_stats_json
                else: stats_list = t1_bowl_stats_json if bowling_team_name == t1_name else t2_bowl_stats_json
                if stats_list is None: stats_list = []
                player_stat = next((p for p in stats_list if p.get('id') == player_id), None)
                if player_stat is None: return f"P{player_id}", "-"
                name = player_stat.get('name', f"P{player_id}")
                if is_batsman:
                    runs = player_stat.get('runs', 0); balls = player_stat.get('ballsFaced', 0)
                    return name, f"{runs}({balls})"
                else:
                    wickets=player_stat.get('wicketsTaken',0); runs_conceded=player_stat.get('runsConceded',0); balls_bowled=player_stat.get('ballsBowled',0)
                    overs = balls_bowled // 6; balls_in_over = balls_bowled % 6
                    return name, f"{wickets}/{runs_conceded} ({overs}.{balls_in_over})"

            striker_name, striker_score = get_player_stats_from_json(striker_id, True)
            non_striker_name, non_striker_score = get_player_stats_from_json(non_striker_id, True)
            bowler_name, bowler_figures = get_player_stats_from_json(bowler_id, False)

        t1_score_str = f"{t1_runs or 0}/{t1_wickets or 0}"
        t1_overs_str = f"({(t1_balls or 0) // 6}.{(t1_balls or 0) % 6})"
        t2_score_str = f"{t2_runs or 0}/{t2_wickets or 0}"
        t2_overs_str = f"({(t2_balls or 0) // 6}.{(t2_balls or 0) % 6})"

        db_current_status = current_status or "upcoming"
        display_summary = live_result if db_current_status.lower() == "finished" and live_result else summary

        # --- Construct the full response dictionary ---
        score_data = {
            "match_id": match_id,
            "team_a_name": t1_name, "team_b_name": t2_name,
            "team_a_score": t1_score_str, "team_a_overs": t1_overs_str,
            "team_b_score": t2_score_str, "team_b_overs": t2_overs_str,
            "match_status_text": db_current_status,
            "summary_text": display_summary or "Match in progress.",
            "batting_team_name": batting_team_name,
            "bowling_team_name": bowling_team_name,
            "batsman_on_strike_name": striker_name or "N/A",
            "batsman_on_strike_score": striker_score or "-",
            "batsman_off_strike_name": non_striker_name or "N/A",
            "batsman_off_strike_score": non_striker_score or "-",
            "bowler_on_strike_name": bowler_name or "N/A",
            "bowler_on_strike_figures": bowler_figures or "-",
            "bowler_off_strike_name": "N/A", # Only current bowler needed for summary
            "bowler_off_strike_figures": "-",
            # Include the detailed stats lists
            "team1_batting": t1_bat_stats_json or [],
            "team2_bowling": t2_bowl_stats_json or [],
            "team2_batting": t2_bat_stats_json or [],
            "team1_bowling": t1_bowl_stats_json or [],
            "team1_extras": team1_extras or 0,
            "team2_extras": team2_extras or 0,
            "is_first_innings": is_first, # Include innings flag
            # "timeline": timeline or [] # <-- REMOVED
            "team1_timeline": team1_timeline or [], # <-- ADDED
            "team2_timeline": team2_timeline or []  # <-- ADDED
        }
        # --- END Construct the full response dictionary ---

        return jsonify(score_data), 200
    except (Exception, psycopg2.Error) as e:
        print(f"Error fetching detailed live score {match_id}: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": f"An error occurred: {str(e)}"}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()


# -------------------- NEW PDF DOWNLOAD ENDPOINT --------------------

def _create_scorecard_pdf(data):
    """ Helper function to generate the PDF from match data with improved table styling. """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=0.5*inch, bottomMargin=0.5*inch, leftMargin=0.5*inch, rightMargin=0.5*inch)
    story = []
    styles = getSampleStyleSheet()
    
    # --- Custom Styles ---
    # Header style for tables
    header_style = ParagraphStyle(name='TableHeader', parent=styles['Normal'], fontName='Helvetica-Bold', alignment=1) # Center alignment=1
    # Right-aligned style for numbers in tables
    right_align_style = ParagraphStyle(name='RightAlign', parent=styles['Normal'], alignment=2) # Right alignment=2
    # --- End Custom Styles ---

    # --- Title & Result ---
    story.append(Paragraph("Official Match Scorecard", styles['h1']))
    story.append(Paragraph(f"{data.get('team1_name', 'Team A')} vs {data.get('team2_name', 'Team B')}", styles['h2']))
    story.append(Paragraph(data.get('live_result') or "Match in Progress", styles['h3']))
    
    # --- Match Info ---
    toss_winner = data.get('toss_winner')
    toss_decision = data.get('toss_decision')
    toss_text = f"Toss: {toss_winner} won the toss and chose to {toss_decision}." if toss_winner else "Toss not yet decided."
    story.append(Paragraph(toss_text, styles['Normal']))
    
    # --- Determine who batted first ---
    # ... (same logic as before to determine batting order) ...
    team1_name = data.get('team1_name')
    team2_name = data.get('team2_name')
    team1_batted_first = True 
    if toss_winner and toss_decision:
        if (toss_winner == team1_name and toss_decision.lower() == 'bowl') or \
           (toss_winner == team2_name and toss_decision.lower() == 'bat'):
            team1_batted_first = False
            
    first_batting_team_name = team1_name if team1_batted_first else team2_name
    second_batting_team_name = team2_name if team1_batted_first else team1_name
    
    first_batting_stats = data.get('team1_batting') if team1_batted_first else data.get('team2_batting')
    first_bowling_stats = data.get('team2_bowling') if team1_batted_first else data.get('team1_bowling')
    first_innings_runs = data.get('team1_runs') if team1_batted_first else data.get('team2_runs')
    first_innings_wickets = data.get('team1_wickets') if team1_batted_first else data.get('team2_wickets')
    first_innings_balls = data.get('team1_balls') if team1_batted_first else data.get('team2_balls')
    first_innings_extras = data.get('team1_extras') if team1_batted_first else data.get('team2_extras')
    first_innings_timeline = data.get('team1_timeline') if team1_batted_first else data.get('team2_timeline')
    
    second_batting_stats = data.get('team2_batting') if team1_batted_first else data.get('team1_batting')
    second_bowling_stats = data.get('team1_bowling') if team1_batted_first else data.get('team2_bowling')
    second_innings_runs = data.get('team2_runs') if team1_batted_first else data.get('team1_runs')
    second_innings_wickets = data.get('team2_wickets') if team1_batted_first else data.get('team1_wickets')
    second_innings_balls = data.get('team2_balls') if team1_batted_first else data.get('team1_balls')
    second_innings_extras = data.get('team2_extras') if team1_batted_first else data.get('team1_extras')
    second_innings_timeline = data.get('team2_timeline') if team1_batted_first else data.get('team1_timeline')
    

    # --- Define Table Styles ---
    batting_table_style = TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.grey),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ALIGN', (0,1), (0,-1), 'LEFT'), # Left align Batsman name
        ('ALIGN', (1,1), (1,-1), 'LEFT'), # Left align Status
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0,0), (-1,0), 10),
        ('BACKGROUND', (0,1), (-1,-1), colors.beige),
        ('GRID', (0,0), (-1,-1), 1, colors.black),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ])

    bowling_table_style = TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.darkslategray), # Different header color
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('ALIGN', (0,1), (0,-1), 'LEFT'), # Left align Bowler name
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0,0), (-1,0), 10),
        ('BACKGROUND', (0,1), (-1,-1), colors.lightgrey), # Different row color
        ('GRID', (0,0), (-1,-1), 1, colors.black),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ])
    # --- End Define Table Styles ---


    # --- Innings 1 ---
    story.append(Spacer(1, 0.2 * inch))
    story.append(Paragraph(f"<b>Innings 1: {first_batting_team_name} Batting</b>", styles['h4'])) # Make bold
    story.append(Spacer(1, 0.05 * inch)) # Less space before table

    # Batting Table 1
    # Wrap headers in Paragraphs for styling
    batting_header = [Paragraph('Batsman', header_style), Paragraph('Status', header_style), Paragraph('R', header_style), Paragraph('B', header_style)]
    batting_data = [batting_header]
    for p in (first_batting_stats or []):
        if p.get('ballsFaced', 0) > 0 or p.get('status') not in ['Yet to bat', 'Not Out']:
            # Wrap numbers in Paragraphs for right alignment
            batting_data.append([
                Paragraph(p.get('name', ''), styles['Normal']), # Name left-aligned by default
                Paragraph(p.get('status', ''), styles['Normal']), # Status left-aligned
                Paragraph(str(p.get('runs', 0)), right_align_style), # Runs right-aligned
                Paragraph(str(p.get('ballsFaced', 0)), right_align_style) # Balls right-aligned
            ])
    
    batting_table_1 = Table(batting_data, colWidths=[2.5*inch, 2.5*inch, 0.5*inch, 0.5*inch])
    batting_table_1.setStyle(batting_table_style)
    story.append(batting_table_1)
    
    story.append(Spacer(1, 0.05 * inch))
    story.append(Paragraph(f"Extras: {first_innings_extras}", styles['Normal']))
    first_overs = f"{(first_innings_balls or 0) // 6}.{(first_innings_balls or 0) % 6}"
    story.append(Paragraph(f"<b>Total: {first_innings_runs}/{first_innings_wickets} ({first_overs} Overs)</b>", styles['h4'])) # Make bold

    # Bowling Table 1
    story.append(Spacer(1, 0.1 * inch))
    story.append(Paragraph(f"<b>{second_batting_team_name} Bowling</b>", styles['h4'])) # Make bold
    story.append(Spacer(1, 0.05 * inch))
    
    bowling_header = [Paragraph('Bowler', header_style), Paragraph('O', header_style), Paragraph('R', header_style), Paragraph('W', header_style)]
    bowling_data = [bowling_header]
    for p in (first_bowling_stats or []):
        if p.get('ballsBowled', 0) > 0:
            overs = f"{(p.get('ballsBowled', 0) // 6)}.{(p.get('ballsBowled', 0) % 6)}"
            bowling_data.append([
                Paragraph(p.get('name', ''), styles['Normal']),
                Paragraph(overs, right_align_style),
                Paragraph(str(p.get('runsConceded', 0)), right_align_style),
                Paragraph(str(p.get('wicketsTaken', 0)), right_align_style)
            ])
            
    bowling_table_1 = Table(bowling_data, colWidths=[3.5*inch, 0.7*inch, 0.7*inch, 0.7*inch])
    bowling_table_1.setStyle(bowling_table_style)
    story.append(bowling_table_1)


    # --- Innings 2 ---
    story.append(Spacer(1, 0.2 * inch))
    story.append(Paragraph(f"<b>Innings 2: {second_batting_team_name} Batting</b>", styles['h4'])) # Make bold
    story.append(Spacer(1, 0.05 * inch))

    # Batting Table 2 (Apply same style)
    batting_data_2 = [batting_header] # Reuse header
    for p in (second_batting_stats or []):
        if p.get('ballsFaced', 0) > 0 or p.get('status') not in ['Yet to bat']:
             batting_data_2.append([
                Paragraph(p.get('name', ''), styles['Normal']),
                Paragraph(p.get('status', ''), styles['Normal']),
                Paragraph(str(p.get('runs', 0)), right_align_style),
                Paragraph(str(p.get('ballsFaced', 0)), right_align_style)
             ])
             
    batting_table_2 = Table(batting_data_2, colWidths=[2.5*inch, 2.5*inch, 0.5*inch, 0.5*inch])
    batting_table_2.setStyle(batting_table_style) # Apply the style
    story.append(batting_table_2)
    
    story.append(Spacer(1, 0.05 * inch))
    story.append(Paragraph(f"Extras: {second_innings_extras}", styles['Normal']))
    second_overs = f"{(second_innings_balls or 0) // 6}.{(second_innings_balls or 0) % 6}"
    story.append(Paragraph(f"<b>Total: {second_innings_runs}/{second_innings_wickets} ({second_overs} Overs)</b>", styles['h4'])) # Make bold
    
    # Bowling Table 2 (Apply same style)
    story.append(Spacer(1, 0.1 * inch))
    story.append(Paragraph(f"<b>{first_batting_team_name} Bowling</b>", styles['h4'])) # Make bold
    story.append(Spacer(1, 0.05 * inch))
    
    bowling_data_2 = [bowling_header] # Reuse header
    for p in (second_bowling_stats or []):
        if p.get('ballsBowled', 0) > 0:
            overs = f"{(p.get('ballsBowled', 0) // 6)}.{(p.get('ballsBowled', 0) % 6)}"
            bowling_data_2.append([
                Paragraph(p.get('name', ''), styles['Normal']),
                Paragraph(overs, right_align_style),
                Paragraph(str(p.get('runsConceded', 0)), right_align_style),
                Paragraph(str(p.get('wicketsTaken', 0)), right_align_style)
            ])
            
    bowling_table_2 = Table(bowling_data_2, colWidths=[3.5*inch, 0.7*inch, 0.7*inch, 0.7*inch])
    bowling_table_2.setStyle(bowling_table_style) # Apply the style
    story.append(bowling_table_2)


    # --- Timelines ---
    story.append(Spacer(1, 0.2 * inch))
    story.append(Paragraph("<b>Innings 1 Timeline</b>", styles['h4']))
    story.append(Paragraph(", ".join(first_innings_timeline or []), styles['Normal']))
    story.append(Spacer(1, 0.1 * inch))
    story.append(Paragraph("<b>Innings 2 Timeline</b>", styles['h4']))
    story.append(Paragraph(", ".join(second_innings_timeline or []), styles['Normal']))

    doc.build(story)
    buffer.seek(0)
    return buffer


# ... (rest of the file, including the download_scorecard_pdf route, remains the same) ...

@app.route('/api/download_scorecard_pdf/<int:match_id>', methods=['GET'])
def download_scorecard_pdf(match_id):
    """ Fetches all match data and generates a PDF scorecard. """
    conn = None
    cur = None
    try:
        conn = get_db_connection()
        if conn is None: return jsonify({"status": "error", "message": "Database connection failed"}), 500
        cur = conn.cursor()
        
        # Use the same comprehensive query from get_live_updates
        all_columns = [
            "match_id", "toss_winner", "toss_decision", "current_status", "live_result", "break_status",
            "team1_name", "team2_name", "team1_runs", "team1_wickets", "team1_balls",
            "team2_runs", "team2_wickets", "team2_balls", "team1_extras", "team2_extras",
            "summary_text", "striker_id", "non_striker_id", "bowler_id",
            "is_first_innings", "target_score", "first_innings_balls",
            "team1_batting_stats", "team2_bowling_stats",
            "team2_batting_stats", "team1_bowling_stats", "last_updated",
            "team1_timeline", "team2_timeline"
        ]
        query = f"SELECT {', '.join(all_columns)} FROM cricket_match_livescore WHERE match_id = %s"
        cur.execute(query, (match_id,))
        row = cur.fetchone()
        
        if not row:
            return jsonify({"status": "error", "message": "Match data not found"}), 404
        
        # Convert row to dictionary
        colnames = [desc[0] for desc in cur.description]
        data = dict(zip(colnames, row))
        
        # Rename JSONB columns for consistency
        data["team1_batting"] = data.get("team1_batting_stats") or []
        data["team2_bowling"] = data.get("team2_bowling_stats") or []
        data["team2_batting"] = data.get("team2_batting_stats") or []
        data["team1_bowling"] = data.get("team1_bowling_stats") or []

        # Generate the PDF
        pdf_buffer = _create_scorecard_pdf(data) # Calls the updated function
        
        # Send the PDF file back to the client
        return send_file(
            pdf_buffer,
            as_attachment=True,
            download_name=f'scorecard_match_{match_id}.pdf',
            mimetype='application/pdf'
        )

    except (Exception, psycopg2.Error) as e:
        print(f"Error generating PDF for match {match_id}: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur and not cur.closed: cur.close()
        if conn and not conn.closed: conn.close()

# -------------------- RUN APP --------------------
if __name__ == '__main__':
    check_and_update_schema() # Ensure schema is ready before running
    app.run(host='0.0.0.0', port=5000, debug=True)

