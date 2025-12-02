#!/usr/bin/env python3
import decimal
import json
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import mysql.connector
from datetime import datetime, date
import traceback
import io
import csv
import requests

# --- REPORTLAB IMPORTS (For PDF Generation - Optional) ---
try:
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
except ImportError:
    print("ReportLab not installed. PDF generation will be disabled.")

class CustomEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal): return str(o)
        if isinstance(o, (datetime, date)): return o.isoformat()
        if isinstance(o, (bytes, bytearray)): 
            try: return o.decode('utf-8')
            except: pass
        return super(CustomEncoder, self).default(o)

app = Flask(__name__)
app.json_encoder = CustomEncoder
CORS(app)

# --- DATABASE CONFIGURATION ---
DB_CONFIG = {
    'user': 'root', 
    'password': '', 
    'host': 'localhost', 
    'database': 'vpsports1', 
    'port': 3306,
    'charset': 'utf8mb4'
}

def get_db_connection():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except mysql.connector.Error as e:
        print(f"DB Connection Error: {e}")
        return None

def parse_json_col(val):
    if val is None: return []
    if isinstance(val, list): return val
    try: return json.loads(val)
    except: return []

# ==============================================================================
#                       DATABASE SCHEMA AUTOMATION
# ==============================================================================
def update_db_schema():
    """Ensures tables exist with gender and sport-specific columns."""
    conn = get_db_connection()
    if not conn:
        print("Skipping schema update: DB connection failed")
        return
    
    cursor = conn.cursor()
    try:
        print("Checking database schema...")
        
        # 1. SCHEDULE TABLE (New)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS schedule_events (
                id INT AUTO_INCREMENT PRIMARY KEY,
                day_label VARCHAR(50),
                event_time VARCHAR(50),
                event_name VARCHAR(255),
                venue VARCHAR(255),
                gender ENUM('Boys', 'Girls') DEFAULT 'Boys',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # 2. Update Team Tables (team_co, team_if, team_ej)
        team_tables = ['team_co', 'team_if', 'team_ej']
        
        # Columns to ensure exist
        required_cols = [
            ("gender", "ENUM('Boys', 'Girls') DEFAULT 'Boys'"),
            ("dodgeball_player", "VARCHAR(255)"),
            ("cricket_player", "VARCHAR(255)"),
            ("football_player", "VARCHAR(255)"),
            ("basketball_player", "VARCHAR(255)"),
            ("kabaddi_player", "VARCHAR(255)"),
            ("volleyball_player", "VARCHAR(255)"),
            ("athletics_player", "VARCHAR(255)"),
            ("chess_player", "VARCHAR(255)"),
            ("carrom_player", "VARCHAR(255)"),
            ("table_tennis_player", "VARCHAR(255)"),
            ("badminton_player", "VARCHAR(255)"),
        ]

        for table in team_tables:
            # Check existing columns
            cursor.execute(f"SHOW COLUMNS FROM {table}")
            existing_cols = [row[0] for row in cursor.fetchall()]
            
            for col_name, col_def in required_cols:
                if col_name not in existing_cols:
                    print(f"Adding {col_name} to {table}...")
                    cursor.execute(f"ALTER TABLE {table} ADD COLUMN {col_name} {col_def}")

        # 3. Update Match Tables to have 'gender'
        match_tables = [
            'cricket_match', 'football_match', 'basketball_matches', 
            'kabaddi_match', 'volleyball_match', 'athletics_match', 
            'chess_match', 'carrom_matches', 'table_tennis_match', 
            'badminton_match', 'dodgeball_match'
        ]
        
        for table in match_tables:
            try:
                cursor.execute(f"SHOW TABLES LIKE '{table}'")
                if cursor.fetchone():
                    cursor.execute(f"SHOW COLUMNS FROM {table}")
                    cols = [row[0] for row in cursor.fetchall()]
                    if 'gender' not in cols:
                        print(f"Adding gender to {table}...")
                        cursor.execute(f"ALTER TABLE {table} ADD COLUMN gender ENUM('Boys', 'Girls') DEFAULT 'Boys'")
            except Exception as ex:
                print(f"Skipping table {table} (might not exist yet): {ex}")

        conn.commit()
        print("Database schema verified.")
        
    except Exception as e:
        print(f"Schema update failed: {e}")
    finally:
        cursor.close()
        conn.close()

# ... [Existing Helper Functions] ...
def get_column_for_sport(sport_name):
    """Maps Google Form sport names to DB column names."""
    if not sport_name: return None
    s = sport_name.lower().strip()
    if 'cricket' in s: return 'cricket_player'
    if 'football' in s: return 'football_player'
    if 'basketball' in s: return 'basketball_player'
    if 'kabaddi' in s: return 'kabaddi_player'
    if 'volleyball' in s: return 'volleyball_player'
    if 'athletics' in s: return 'athletics_player'
    if 'chess' in s: return 'chess_player'
    if 'carrom' in s: return 'carrom_player'
    if 'table' in s or 'tennis' in s: return 'table_tennis_player'
    if 'badminton' in s: return 'badminton_player'
    if 'dodgeball' in s: return 'dodgeball_player'
    return None

# ==============================================================================
#                                SCHEDULE ENDPOINTS (NEW)
# ==============================================================================

@app.route('/api/get_schedule', methods=['GET'])
def get_schedule():
    gender = request.args.get('gender', 'Boys')
    conn = get_db_connection()
    if not conn: return jsonify([]), 500
    try:
        cur = conn.cursor(dictionary=True)
        # Fetch all events for the gender, ordered by Day then Time (simplistic sort)
        cur.execute("SELECT * FROM schedule_events WHERE gender = %s ORDER BY day_label, event_time", (gender,))
        rows = cur.fetchall()
        return jsonify(rows), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/add_schedule_event', methods=['POST'])
def add_schedule_event():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    try:
        cur = conn.cursor()
        sql = "INSERT INTO schedule_events (day_label, event_time, event_name, venue, gender) VALUES (%s, %s, %s, %s, %s)"
        vals = (data['day'], data['time'], data['event'], data['venue'], data['gender'])
        cur.execute(sql, vals)
        conn.commit()
        return jsonify({"status": "success"}), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/delete_schedule_event', methods=['POST'])
def delete_schedule_event():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM schedule_events WHERE id = %s", (data['id'],))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        conn.close()

# ==============================================================================
#                                PLAYER DATA SYNC (EXISTING)
# ==============================================================================

CSV_URLS_BOYS = {
    'CO': 'https://docs.google.com/spreadsheets/d/e/2PACX-1vR44hh2_ate6gON95q4-BTzdebfZM2k6Sg-SYD9pq3wY_fbbOQr_RiRkJ1NRjGynCD73RJ282KT2dCx/pub?gid=658788574&single=true&output=csv',
    'IF': 'https://docs.google.com/spreadsheets/d/e/2PACX-1vT9N7lwCdwLXcvSoe6Btz5qwbAcOctrzub4auqQpQi2OKow2OXWWaBbeIjJeXEx68PDzKwbDxk2TNbo/pub?gid=1584125774&single=true&output=csv',
    'EJ': 'https://docs.google.com/spreadsheets/d/e/2PACX-1vTgsDpVd4hnaukYXXg5I3PaBrFZCEX3B8UwSWsS6eviglIS0zcGJyFyjF6oPgGq4adUE-wzR4FzSgel/pub?gid=2018174338&single=true&output=csv'
}

CSV_URLS_GIRLS = {
    'CO': 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSXlSQJ_qlfkCO16xsdNFGdRLA4zDqWyM3nBP2EQ5JS7nbPapRSHxh2k4jatvzV6izL7qqOL6v64Ume/pub?gid=975501789&single=true&output=csv',
    'IF': 'https://docs.google.com/spreadsheets/d/e/2PACX-1vRHX_IR9PivkEMskqwn7ary29wvO08KXIRqZV3wrFczjiFdS2OzNZdIfdruT9CYueSkadrna_KMsOx0/pub?gid=1363664865&single=true&output=csv',
    'EJ': 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSKnPXauzAdM2DvdvMRel-gVWPi6Du1TWdbjKAzkrY4MHhqvN1OZMZE_64nioBHDXlmvXXkgh5htndr/pub?gid=466749134&single=true&output=csv'
}

@app.route('/api/sync_players', methods=['GET'])
def sync_players():
    target_sport = request.args.get('sport') 
    gender = request.args.get('gender', 'Boys') 
    
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    
    cur = None
    try:
        cur = conn.cursor()
        total_added = 0
        
        target_col_name = None
        if target_sport:
            target_col_name = get_column_for_sport(target_sport)
            if not target_col_name:
                 return jsonify({"status": "error", "message": f"Unknown sport: {target_sport}"}), 400

        current_csv_urls = CSV_URLS_GIRLS if gender == 'Girls' else CSV_URLS_BOYS

        for team_name, url in current_csv_urls.items():
            table_name = f"team_{team_name.lower()}" 
            if target_sport:
                cur.execute(f"DELETE FROM {table_name} WHERE {target_col_name} IS NOT NULL AND gender = %s", (gender,))
            else:
                cur.execute(f"DELETE FROM {table_name} WHERE gender = %s", (gender,))
            
            try:
                response = requests.get(url)
                if response.status_code != 200: continue
            except: continue

            stream = io.StringIO(response.content.decode('utf-8'))
            csv_reader = csv.reader(stream)
            try: header = next(csv_reader) 
            except: continue 
            
            sport_indices = [i for i, h in enumerate(header) if 'Select the Sport' in h or 'Sport' in h]
            player_start_index = sport_indices[-1] + 1 if sport_indices else 4

            for row in csv_reader:
                if len(row) < 5: continue 
                row_sport = ""
                if len(row) > 2 and row[2].strip(): row_sport = row[2].strip()
                if not row_sport and len(row) > 3 and row[3].strip(): row_sport = row[3].strip()
                if not row_sport: continue 

                if target_sport and target_sport.lower() not in row_sport.lower(): continue

                current_row_col = get_column_for_sport(row_sport)
                if not current_row_col: continue

                for i in range(player_start_index, len(row)):
                    if i >= len(row): break
                    p_name = row[i].strip()
                    if p_name and "player" not in p_name.lower(): 
                        sql = f"INSERT INTO {table_name} ({current_row_col}, gender) VALUES (%s, %s)"
                        cur.execute(sql, (p_name, gender))
                        total_added += 1
                            
        conn.commit()
        return jsonify({"status": "success", "message": f"Synced {total_added} {gender} players."}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_players_by_team', methods=['GET'])
def get_players_by_team():
    team = request.args.get('team') 
    sport = request.args.get('sport')
    gender = request.args.get('gender', 'Boys')

    if not team or not sport: return jsonify([]), 400
    table_name = f"team_{team.lower()}" 
    target_col = get_column_for_sport(sport)
    if not target_col: return jsonify([]), 200 

    conn = get_db_connection()
    if not conn: return jsonify([]), 500
    try:
        cur = conn.cursor()
        cur.execute(f"SELECT {target_col} FROM {table_name} WHERE {target_col} IS NOT NULL AND {target_col} != '' AND gender = %s ORDER BY {target_col} ASC", (gender,))
        players = cur.fetchall()
        return jsonify([p[0] for p in players]), 200
    except: return jsonify([]), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                MATCH CRUD ENDPOINTS
# ==============================================================================

@app.route('/api/add_cricket_match', methods=['POST'])
def add_cricket_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        vals = (data['team_a_name'], data['team_b_name'], json.dumps(data.get('team_a_players', [])), json.dumps(data.get('team_b_players', [])), int(data.get('overs', 20)), data['start_time'], data['venue'], json.dumps(data.get('umpires', [])), data.get('gender', 'Boys'))
        cur.execute("INSERT INTO cricket_match (team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')", vals)
        new_id = cur.lastrowid
        cur.execute("INSERT INTO cricket_match_livescore (match_id, team1_name, team2_name, current_status, summary_text) VALUES (%s, %s, %s, 'upcoming', 'Match not started')", (new_id, data['team_a_name'], data['team_b_name']))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/update_live_score/<int:match_id>', methods=['POST'])
def update_cricket_live_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        update_fields = []
        params = []
        excluded_keys = ['match_id', 'team1_timeline', 'team2_timeline', 'team1_batting', 'team2_bowling', 'team2_batting', 'team1_bowling']
        for key, value in data.items():
            if key not in excluded_keys:
                update_fields.append(f"{key} = %s")
                params.append(value)
        if 'team1_batting' in data:
            update_fields.append("team1_batting_stats = %s")
            params.append(json.dumps(data['team1_batting']))
        if 'team2_bowling' in data:
            update_fields.append("team2_bowling_stats = %s")
            params.append(json.dumps(data['team2_bowling']))
        if 'team2_batting' in data:
            update_fields.append("team2_batting_stats = %s")
            params.append(json.dumps(data['team2_batting']))
        if 'team1_bowling' in data:
            update_fields.append("team1_bowling_stats = %s")
            params.append(json.dumps(data['team1_bowling']))
        if 'team1_timeline' in data:
            update_fields.append("team1_timeline = %s")
            params.append(json.dumps(data['team1_timeline']))
        if 'team2_timeline' in data:
            update_fields.append("team2_timeline = %s")
            params.append(json.dumps(data['team2_timeline']))
        params.append(match_id)
        if update_fields:
            sql = f"UPDATE cricket_match_livescore SET {', '.join(update_fields)}, last_updated = NOW() WHERE match_id = %s"
            cur.execute(sql, tuple(params))
            if 'current_status' in data:
                status = data['current_status']
                if status.lower() in ['live', 'finished', 'upcoming']:
                    cur.execute("UPDATE cricket_match SET match_status = %s WHERE match_id = %s", (status.lower(), match_id))
            conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/get_live_score/<int:match_id>', methods=['GET'])
def get_cricket_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT * FROM cricket_match_livescore WHERE match_id = %s", (match_id,))
        row = cur.fetchone()
        if not row:
             cur.execute("SELECT team_a_name, team_b_name, match_status FROM cricket_match WHERE match_id = %s", (match_id,))
             match_info = cur.fetchone()
             if not match_info: return jsonify({"status": "error"}), 404
             return jsonify({"match_id": match_id, "current_status": match_info['match_status'], "team1_batting": [], "team2_bowling": [], "team2_batting": [], "team1_bowling": []}), 200
        data = {}
        for k, v in row.items():
            if isinstance(v, (bytes, bytearray)):
                 try: data[k] = v.decode('utf-8')
                 except: data[k] = str(v)
            elif isinstance(v, decimal.Decimal): data[k] = str(v)
            elif isinstance(v, (datetime, date)): data[k] = v.isoformat()
            else: data[k] = v
        data["team1_batting"] = parse_json_col(data.get("team1_batting_stats"))
        data["team2_bowling"] = parse_json_col(data.get("team2_bowling_stats"))
        data["team2_batting"] = parse_json_col(data.get("team2_batting_stats"))
        data["team1_bowling"] = parse_json_col(data.get("team1_bowling_stats"))
        data["team1_timeline"] = parse_json_col(data.get("team1_timeline"))
        data["team2_timeline"] = parse_json_col(data.get("team2_timeline"))
        return jsonify(data), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

# --- FOOTBALL ---
@app.route('/api/add_football_match', methods=['POST'])
def add_football_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        vals = (data['team_a_name'], data['team_b_name'], json.dumps(data.get('team_a_players', [])), json.dumps(data.get('team_b_players', [])), int(data.get('match_duration', 90)), data['start_time'], data['venue'], json.dumps(data.get('referees', [])), data.get('gender', 'Boys'))
        cur.execute("INSERT INTO football_match (team_a_name, team_b_name, team_a_players, team_b_players, match_duration, start_time, venue, referees, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')", vals)
        new_id = cur.lastrowid
        cur.execute("INSERT INTO football_match_livescore (match_id, team_a_goals, team_b_goals, match_time, current_half, match_status) VALUES (%s, 0, 0, '00:00', '1st Half', 'upcoming')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/get_football_live_score/<int:match_id>', methods=['GET'])
def get_football_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT ls.*, fm.match_duration, fm.team_a_players, fm.team_b_players FROM football_match_livescore ls JOIN football_match fm ON ls.match_id = fm.match_id WHERE ls.match_id = %s", (match_id,))
        row = cur.fetchone()
        if not row: return jsonify({"status": "error"}), 404
        current_seconds = row.get('accumulated_seconds') or 0
        if row.get('last_resume_time') is not None and row.get('match_status') == 'live':
            diff = (datetime.now() - row['last_resume_time']).total_seconds()
            current_seconds += int(diff)
        mins, secs = divmod(current_seconds, 60)
        row['match_time'] = f"{int(mins):02}:{int(secs):02}"
        row['calculated_seconds'] = int(current_seconds)
        for k in ['team_a_players', 'team_b_players', 'team_a_goal_details', 'team_b_goal_details', 'team_a_foul_details', 'team_b_foul_details']:
            row[k] = parse_json_col(row.get(k))
        return jsonify(row), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/update_football_score/<int:match_id>', methods=['POST'])
def update_football_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        timer_action = data.get('timer_action')
        if timer_action == 'start':
            cur.execute("UPDATE football_match_livescore SET last_resume_time = NOW(), match_status = 'live' WHERE match_id = %s", (match_id,))
        elif timer_action == 'stop':
            cur.execute("SELECT last_resume_time, accumulated_seconds FROM football_match_livescore WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row and row[0]:
                diff = (datetime.now() - row[0]).total_seconds()
                cur.execute("UPDATE football_match_livescore SET accumulated_seconds = %s, last_resume_time = NULL, match_status = 'paused' WHERE match_id = %s", ((row[1] or 0) + int(diff), match_id))
        
        vals = (data.get('team_a_goals'), data.get('team_b_goals'), data.get('team_a_fouls',0), data.get('team_b_fouls',0), data.get('team_a_freekicks',0), data.get('team_b_freekicks',0), data.get('team_a_penalties',0), data.get('team_b_penalties',0), json.dumps(data.get('team_a_goal_details',[])), json.dumps(data.get('team_b_goal_details',[])), json.dumps(data.get('team_a_foul_details',[])), json.dumps(data.get('team_b_foul_details',[])), data.get('match_time'), data.get('current_half'), data.get('status'), match_id)
        cur.execute("UPDATE football_match_livescore SET team_a_goals=%s, team_b_goals=%s, team_a_fouls=%s, team_b_fouls=%s, team_a_freekicks=%s, team_b_freekicks=%s, team_a_penalties=%s, team_b_penalties=%s, team_a_goal_details=%s, team_b_goal_details=%s, team_a_foul_details=%s, team_b_foul_details=%s, match_time=%s, current_half=%s, match_status=%s, last_updated=NOW() WHERE match_id=%s", vals)
        if data.get('status') == 'finished':
             cur.execute("UPDATE football_match SET match_status = 'finished' WHERE match_id = %s", (match_id,))
             cur.execute("UPDATE football_match_livescore SET match_status = 'finished', last_resume_time = NULL WHERE match_id = %s", (match_id,))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

# --- DODGEBALL ---
@app.route('/api/add_dodgeball_match', methods=['POST'])
def add_dodgeball_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        vals = (data['team_a_name'], data['team_b_name'], json.dumps(data.get('team_a_players', [])), json.dumps(data.get('team_b_players', [])), 
                data['start_time'], data['venue'], json.dumps(data.get('officials', [])), data.get('gender', 'Girls'))
        cur.execute("INSERT INTO dodgeball_match (team_a_name, team_b_name, team_a_players, team_b_players, start_time, venue, officials, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')", vals)
        new_id = cur.lastrowid
        cur.execute("INSERT INTO dodgeball_match_livescore (match_id, team_a_score, team_b_score, match_status) VALUES (%s, 0, 0, 'upcoming')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/get_dodgeball_live_score/<int:match_id>', methods=['GET'])
def get_dodgeball_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT ls.*, dm.team_a_name, dm.team_b_name, dm.match_status as main_status FROM dodgeball_match_livescore ls JOIN dodgeball_match dm ON ls.match_id = dm.match_id WHERE ls.match_id = %s", (match_id,))
        row = cur.fetchone()
        if not row: return jsonify({"status": "error"}), 404
        return jsonify(row), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/update_dodgeball_score/<int:match_id>', methods=['POST'])
def update_dodgeball_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        vals = (data.get('team_a_score'), data.get('team_b_score'), data.get('status'), match_id)
        cur.execute("UPDATE dodgeball_match_livescore SET team_a_score=%s, team_b_score=%s, match_status=%s, last_updated=NOW() WHERE match_id=%s", vals)
        if data.get('status') == 'finished':
             cur.execute("UPDATE dodgeball_match SET match_status = 'finished' WHERE match_id = %s", (match_id,))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

# --- OTHER SPORTS ---
@app.route('/api/add_basketball_match', methods=['POST'])
def add_basketball_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        t1_p = (data.get('team_a_players', []) + [''] * 15)[:15]
        t2_p = (data.get('team_b_players', []) + [''] * 15)[:15]
        umpires = ", ".join(data.get('umpires', []))
        vals = [data['team_a_name'], data['team_b_name'], data['start_time'], data['venue'], data.get('total_quarters', 4), data.get('category', 'full_game'), umpires, data.get('gender', 'Boys')] + t1_p + t2_p
        sql = "INSERT INTO basketball_matches (team_1_name, team_2_name, start_time, venue, total_quarters, category, match_status, umpires, gender, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team1_player6, team1_player7, team1_player8, team1_player9, team1_player10, team1_sub1, team1_sub2, team1_sub3, team1_sub4, team1_sub5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, team2_player6, team2_player7, team2_player8, team2_player9, team2_player10, team2_sub1, team2_sub2, team2_sub3, team2_sub4, team2_sub5) VALUES (%s, %s, %s, %s, %s, %s, 'upcoming', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
        cur.execute(sql, tuple(vals))
        new_id = cur.lastrowid
        cur.execute("INSERT INTO basketball_match_livescore (match_id, current_quarter, match_status) VALUES (%s, 1, 'not_started')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/get_basketball_live_score/<int:match_id>', methods=['GET'])
def get_basketball_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT bm.team_1_name, bm.team_2_name, bm.total_quarters, bm.category, ls.* FROM basketball_matches bm JOIN basketball_match_livescore ls ON bm.match_id = ls.match_id WHERE bm.match_id = %s", (match_id,))
        row = cur.fetchone()
        if row: return jsonify(row), 200
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/update_basketball_match_score/<int:match_id>', methods=['POST'])
def update_basketball_match_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        sql = "UPDATE basketball_match_livescore SET team1_score=%s, team2_score=%s, team1_q1_score=%s, team2_q1_score=%s, team1_q2_score=%s, team2_q2_score=%s, team1_q3_score=%s, team2_q3_score=%s, team1_q4_score=%s, team2_q4_score=%s, team1_ot_score=%s, team2_ot_score=%s, current_quarter=%s, team1_fouls=%s, team2_fouls=%s, team1_timeouts=%s, team2_timeouts=%s, match_status=%s WHERE match_id=%s"
        vals = (data.get('team1_score',0), data.get('team2_score',0), data.get('team1_q1_score',0), data.get('team2_q1_score',0), data.get('team1_q2_score',0), data.get('team2_q2_score',0), data.get('team1_q3_score',0), data.get('team2_q3_score',0), data.get('team1_q4_score',0), data.get('team2_q4_score',0), data.get('team1_ot_score',0), data.get('team2_ot_score',0), data.get('current_quarter',1), data.get('team1_fouls',0), data.get('team2_fouls',0), data.get('team1_timeouts',0), data.get('team2_timeouts',0), data.get('match_status','live'), match_id)
        cur.execute(sql, vals)
        if data.get('match_status') in ['live', 'finished']:
             cur.execute("UPDATE basketball_matches SET match_status=%s WHERE match_id=%s", (data['match_status'], match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/add_athletics_match', methods=['POST'])
def add_athletics_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        t1 = json.dumps(data.get('team_a_players', []))
        t2 = json.dumps(data.get('team_b_players', []))
        t3 = json.dumps(data.get('team_c_players', []))
        officials = json.dumps(data.get('officials', []))
        cur.execute("INSERT INTO athletics_match (team_a_name, team_b_name, team_c_name, team_a_players, team_b_players, team_c_players, start_time, venue, officials, event_category, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')", (data['team_a_name'], data['team_b_name'], data.get('team_c_name', 'Team C'), t1, t2, t3, data['start_time'], data['venue'], officials, data.get('event_category', 'Race'), data.get('gender', 'Boys')))
        new_id = cur.lastrowid
        cur.execute("INSERT INTO athletics_match_livescore (match_id, game_status_text) VALUES (%s, 'Race Not Started')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/get_athletics_live_score/<int:match_id>', methods=['GET'])
def get_athletics_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT am.*, ls.winner, ls.runner_up, ls.third_place, ls.game_status_text FROM athletics_match am JOIN athletics_match_livescore ls ON am.match_id = ls.match_id WHERE am.match_id = %s", (match_id,))
        row = cur.fetchone()
        if row: return jsonify(row), 200
        return jsonify({"status": "error", "message": "Not found"}), 404
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/update_athletics_score/<int:match_id>', methods=['POST'])
def update_athletics_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        cur.execute("UPDATE athletics_match_livescore SET winner=%s, runner_up=%s, third_place=%s, game_status_text=%s WHERE match_id=%s", (data.get('winner'), data.get('runner_up'), data.get('third_place'), data.get('game_status_text'), match_id))
        if data.get('status') in ['live', 'finished']:
             cur.execute("UPDATE athletics_match SET match_status=%s WHERE match_id=%s", (data['status'], match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/add_badminton_match', methods=['POST'])
def add_badminton_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        if not isinstance(t1_players, list): t1_players = []
        if not isinstance(t2_players, list): t2_players = []
        t1_players += [''] * (5 - len(t1_players))
        t2_players += [''] * (5 - len(t2_players))
        umpires = json.dumps(data.get('umpires', []))
        total_sets = data.get('total_sets', 3)
        category = data.get('category', 'singles')
        sql = "INSERT INTO badminton_match (team_1_name, team_2_name, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, start_time, venue, umpires, total_sets, category, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"
        vals = (data['team_a_name'], data['team_b_name'], t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4], t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4], data['start_time'], data['venue'], umpires, total_sets, category, data.get('gender', 'Boys'))
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        cur.execute("INSERT INTO badminton_match_livescore (match_id, current_set, match_status) VALUES (%s, 1, 'Match not started')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_badminton_live_score/<int:match_id>', methods=['GET'])
def get_badminton_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT cm.team_1_name as team_a_name, cm.team_2_name as team_b_name, cm.match_status as main_status, cm.category, ls.*, ls.match_status as game_status_text, cm.total_sets FROM badminton_match cm JOIN badminton_match_livescore ls ON cm.match_id = ls.match_id WHERE cm.match_id = %s", (match_id,))
        row = cur.fetchone()
        if not row: return jsonify({"status": "error", "message": "Match not found"}), 404
        row['match_status'] = row['main_status']
        return jsonify(row), 200
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_badminton_score/<int:match_id>', methods=['POST'])
def update_badminton_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        sql_live = "UPDATE badminton_match_livescore SET current_set=%s, team1_set1_points=%s, team2_set1_points=%s, team1_set2_points=%s, team2_set2_points=%s, team1_set3_points=%s, team2_set3_points=%s, match_status=%s WHERE match_id=%s"
        vals = (data.get('new_current_set', 1), data.get('team1_set1_points', 0), data.get('team2_set1_points', 0), data.get('team1_set2_points', 0), data.get('team2_set2_points', 0), data.get('team1_set3_points', 0), data.get('team2_set3_points', 0), data.get('status_text'), match_id)
        cur.execute(sql_live, vals)
        status = data.get('status')
        if status in ['live', 'finished']: cur.execute("UPDATE badminton_match SET match_status=%s WHERE match_id=%s", (status, match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/add_table_tennis_match', methods=['POST'])
def add_table_tennis_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        if not isinstance(t1_players, list): t1_players = []
        if not isinstance(t2_players, list): t2_players = []
        t1_players += [''] * (5 - len(t1_players))
        t2_players += [''] * (5 - len(t2_players))
        umpires = json.dumps(data.get('umpires', []))
        total_sets = data.get('total_sets', 3)
        category = data.get('category', 'singles')
        pA = data.get('player_a_selected', 'Player A')
        pB = data.get('player_b_selected', 'Player B')
        sql = "INSERT INTO table_tennis_match (team_1_name, team_2_name, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, start_time, venue, umpires, total_sets, category, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"
        vals = (data['team_a_name'], data['team_b_name'], t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4], t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4], data['start_time'], data['venue'], umpires, total_sets, category, data.get('gender', 'Boys'))
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        status_text = f"Selected: {pA} vs {pB}"
        cur.execute("INSERT INTO table_tennis_livescore (match_id, current_set, total_sets, team1_set1_points, team2_set1_points, game_status_text) VALUES (%s, 1, %s, 0, 0, %s)", (new_id, total_sets, status_text))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_table_tennis_live_score/<int:match_id>', methods=['GET'])
def get_table_tennis_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT cm.team_1_name as team_a_name, cm.team_2_name as team_b_name, cm.match_status, cm.category, ls.*, cm.total_sets FROM table_tennis_match cm JOIN table_tennis_livescore ls ON cm.match_id = ls.match_id WHERE cm.match_id = %s", (match_id,))
        row = cur.fetchone()
        if not row: return jsonify({"status": "error", "message": "Match not found"}), 404
        return jsonify(row), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_table_tennis_score/<int:match_id>', methods=['POST'])
def update_table_tennis_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        sql_live = "UPDATE table_tennis_livescore SET current_set=%s, team1_set1_points=%s, team2_set1_points=%s, team1_set2_points=%s, team2_set2_points=%s, team1_set3_points=%s, team2_set3_points=%s, game_status_text=%s, winner=%s, last_updated=NOW() WHERE match_id=%s"
        vals = (data.get('new_current_set', 1), data.get('team1_set1_points', 0), data.get('team2_set1_points', 0), data.get('team1_set2_points', 0), data.get('team2_set2_points', 0), data.get('team1_set3_points', 0), data.get('team2_set3_points', 0), data.get('status_text'), data.get('winner'), match_id)
        cur.execute(sql_live, vals)
        status = data.get('status')
        if status in ['live', 'finished']: cur.execute("UPDATE table_tennis_match SET match_status=%s WHERE match_id=%s", (status, match_id))
        conn.commit()
        return jsonify({"status": "success", "message": "Score updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/add_chess_match', methods=['POST'])
def add_chess_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        t1_players = (t1_players if isinstance(t1_players, list) else []) + [''] * 5
        t2_players = (t2_players if isinstance(t2_players, list) else []) + [''] * 5
        umpires = json.dumps(data.get('umpires', []))
        sql = "INSERT INTO chess_match (team_a_name, team_b_name, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, start_time, venue, umpires, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"
        vals = (data['team_a_name'], data['team_b_name'], t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4], t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4], data['start_time'], data['venue'], umpires, data.get('gender', 'Boys'))
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        cur.execute("INSERT INTO chess_match_livescore (match_id, game_status_text, winner) VALUES (%s, 'Match Not Started', NULL)", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_chess_live_score/<int:match_id>', methods=['GET'])
def get_chess_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT cm.team_a_name, cm.team_b_name, cm.match_status, ls.game_status_text, ls.winner FROM chess_match cm JOIN chess_match_livescore ls ON cm.match_id = ls.match_id WHERE cm.match_id = %s", (match_id,))
        row = cur.fetchone()
        if row: return jsonify(row), 200
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_chess_score/<int:match_id>', methods=['POST'])
def update_chess_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        cur.execute("UPDATE chess_match_livescore SET game_status_text = %s, winner = %s, last_updated = NOW() WHERE match_id = %s", (data.get('game_status_text', ''), data.get('winner'), match_id))
        status = data.get('status')
        if status in ['live', 'finished']: cur.execute("UPDATE chess_match SET match_status = %s WHERE match_id = %s", (status, match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/add_carrom_match', methods=['POST'])
def add_carrom_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        t1_players = (t1_players if isinstance(t1_players, list) else []) + [''] * 5
        t2_players = (t2_players if isinstance(t2_players, list) else []) + [''] * 5
        umpires = json.dumps(data.get('umpires', []))
        sql = "INSERT INTO carrom_matches (team_1_name, team_2_name, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, start_time, venue, umpires, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"
        vals = (data['team_a_name'], data['team_b_name'], t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4], t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4], data['start_time'], data['venue'], umpires, data.get('gender', 'Boys'))
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        cur.execute("INSERT INTO carrom_match_livescore (match_id, game_status_text, winner) VALUES (%s, 'Match Not Started', NULL)", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_carrom_live_score/<int:match_id>', methods=['GET'])
def get_carrom_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT cm.team_1_name as team_a_name, cm.team_2_name as team_b_name, cm.match_status, ls.game_status_text, ls.winner FROM carrom_matches cm JOIN carrom_match_livescore ls ON cm.match_id = ls.match_id WHERE cm.match_id = %s", (match_id,))
        row = cur.fetchone()
        if row: return jsonify(row), 200
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_carrom_score/<int:match_id>', methods=['POST'])
def update_carrom_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        cur.execute("UPDATE carrom_match_livescore SET game_status_text = %s, winner = %s, last_updated = NOW() WHERE match_id = %s", (data.get('game_status_text', ''), data.get('winner'), match_id))
        status = data.get('status')
        if status in ['live', 'finished']: cur.execute("UPDATE carrom_matches SET match_status = %s WHERE match_id = %s", (status, match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/add_volleyball_match', methods=['POST'])
def add_volleyball_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        officials = json.dumps(data.get('officials', []))
        cur.execute("INSERT INTO volleyball_match (team_a_name, team_b_name, team_a_players, team_b_players, venue, start_time, match_format, officials, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')", (data['team_a_name'], data['team_b_name'], team_a_players, team_b_players, data['venue'], data['start_time'], data.get('match_format', 'Best of 3 Sets'), officials, data.get('gender', 'Boys')))
        new_id = cur.lastrowid
        cur.execute("INSERT INTO volleyball_match_livescore (match_id, current_set, team_a_sets_won, team_b_sets_won, team_a_current_points, team_b_current_points, set_scores) VALUES (%s, 1, 0, 0, 0, 0, '{}')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_volleyball_live_score/<int:match_id>', methods=['GET'])
def get_volleyball_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT ls.*, vm.team_a_name, vm.team_b_name, vm.match_format, vm.match_status FROM volleyball_match_livescore ls JOIN volleyball_match vm ON ls.match_id = vm.match_id WHERE ls.match_id = %s", (match_id,))
        row = cur.fetchone()
        if row: 
            row['set_scores'] = parse_json_col(row.get('set_scores'))
            return jsonify(row), 200
        return jsonify({"message": "Not found"}), 404
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_volleyball_score/<int:match_id>', methods=['POST'])
def update_volleyball_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        sql = "UPDATE volleyball_match_livescore SET current_set=%s, team_a_sets_won=%s, team_b_sets_won=%s, team_a_current_points=%s, team_b_current_points=%s, set_scores=%s WHERE match_id=%s"
        vals = (data['current_set'], data['team_a_sets_won'], data['team_b_sets_won'], data['team_a_current_points'], data['team_b_current_points'], json.dumps(data.get('set_scores', {})), match_id)
        cur.execute(sql, vals)
        if 'match_status' in data: cur.execute("UPDATE volleyball_match SET match_status=%s WHERE match_id=%s", (data['match_status'], match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/add_kabaddi_match', methods=['POST'])
def add_kabaddi_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        officials = json.dumps(data.get('officials', []))
        cur.execute("INSERT INTO kabaddi_match (team_a_name, team_b_name, team_a_players, team_b_players, venue, start_time, match_duration, officials, gender, match_status) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')", (data['team_a_name'], data['team_b_name'], team_a_players, team_b_players, data['venue'], data['start_time'], int(data.get('match_duration', 40)), officials, data.get('gender', 'Boys')))
        new_id = cur.lastrowid
        cur.execute("INSERT INTO kabaddi_match_livescore (match_id, team_a_score, team_b_score, match_time, current_half) VALUES (%s, 0, 0, '00:00', '1st Half')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_kabaddi_score/<int:match_id>', methods=['POST'])
def update_kabaddi_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    try:
        sql = "UPDATE kabaddi_match_livescore SET team_a_score=%s, team_b_score=%s, match_time=%s, current_half=%s WHERE match_id=%s"
        vals = (data['team_a_score'], data['team_b_score'], data['match_time'], data['current_half'], match_id)
        cur.execute(sql, vals)
        if 'match_status' in data: cur.execute("UPDATE kabaddi_match SET match_status=%s WHERE match_id=%s", (data['match_status'], match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_kabaddi_live_score/<int:match_id>', methods=['GET'])
def get_kabaddi_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute("SELECT ls.*, km.team_a_name, km.team_b_name, km.match_duration, km.match_status FROM kabaddi_match_livescore ls JOIN kabaddi_match km ON ls.match_id = km.match_id WHERE ls.match_id = %s", (match_id,))
        row = cur.fetchone()
        if row: return jsonify(row), 200
        return jsonify({"message": "Not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                       MATCH DETAILS & START (FIXED)
# ==============================================================================

@app.route('/api/get_match_details/<int:match_id>', methods=['GET'])
def get_match_details(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor(dictionary=True)
    
    # Normalize sport string
    raw_sport = request.args.get('sport', 'Cricket')
    sport = raw_sport.lower().replace('_', ' ').strip()
    
    try:
        data = None
        
        # --- 1. CRICKET ---
        if sport == 'cricket':
            cur.execute("SELECT * FROM cricket_match WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                data = {
                    "id": row['match_id'], "sport": "Cricket",
                    "team_a_name": row['team_a_name'], "team_b_name": row['team_b_name'],
                    "team_a_players": parse_json_col(row['team_a_players']),
                    "team_b_players": parse_json_col(row['team_b_players']),
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Overs": row['overs_per_innings'], "Umpires": parse_json_col(row['umpires']) }
                }

        # --- 2. FOOTBALL ---
        elif sport == 'football':
            cur.execute("SELECT * FROM football_match WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                data = {
                    "id": row['match_id'], "sport": "Football",
                    "team_a_name": row['team_a_name'], "team_b_name": row['team_b_name'],
                    "team_a_players": parse_json_col(row['team_a_players']),
                    "team_b_players": parse_json_col(row['team_b_players']),
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Duration": f"{row['match_duration']} mins", "Referees": parse_json_col(row['referees']) }
                }

        # --- 3. KABADDI ---
        elif sport == 'kabaddi':
            cur.execute("SELECT * FROM kabaddi_match WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                data = {
                    "id": row['match_id'], "sport": "Kabaddi",
                    "team_a_name": row['team_a_name'], "team_b_name": row['team_b_name'],
                    "team_a_players": parse_json_col(row['team_a_players']),
                    "team_b_players": parse_json_col(row['team_b_players']),
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Duration": f"{row['match_duration']} mins", "Officials": parse_json_col(row['officials']) }
                }

        # --- 4. BASKETBALL (Column-based players) ---
        elif sport == 'basketball':
            cur.execute("SELECT * FROM basketball_matches WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                # Extract players from columns team1_player1...team1_sub5
                t1_p = [row[f'team1_player{i}'] for i in range(1, 11) if row.get(f'team1_player{i}')]
                t1_s = [row[f'team1_sub{i}'] for i in range(1, 6) if row.get(f'team1_sub{i}')]
                t2_p = [row[f'team2_player{i}'] for i in range(1, 11) if row.get(f'team2_player{i}')]
                t2_s = [row[f'team2_sub{i}'] for i in range(1, 6) if row.get(f'team2_sub{i}')]
                
                data = {
                    "id": row['match_id'], "sport": "Basketball",
                    "team_a_name": row['team_1_name'], "team_b_name": row['team_2_name'],
                    "team_a_players": t1_p + t1_s,
                    "team_b_players": t2_p + t2_s,
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Quarters": row['total_quarters'], "Category": row['category'], "Umpires": row['umpires'] }
                }

        # --- 5. VOLLEYBALL ---
        elif sport == 'volleyball':
            cur.execute("SELECT * FROM volleyball_match WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                data = {
                    "id": row['match_id'], "sport": "Volleyball",
                    "team_a_name": row['team_a_name'], "team_b_name": row['team_b_name'],
                    "team_a_players": parse_json_col(row['team_a_players']),
                    "team_b_players": parse_json_col(row['team_b_players']),
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Format": row['match_format'], "Officials": parse_json_col(row['officials']) }
                }

        # --- 6. ATHLETICS (Has Team C) ---
        elif sport == 'athletics':
            cur.execute("SELECT * FROM athletics_match WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                data = {
                    "id": row['match_id'], "sport": "Athletics",
                    "team_a_name": row['team_a_name'], "team_b_name": row['team_b_name'],
                    "team_c_name": row['team_c_name'],
                    "team_a_players": parse_json_col(row['team_a_players']),
                    "team_b_players": parse_json_col(row['team_b_players']),
                    "team_c_players": parse_json_col(row['team_c_players']),
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Category": row['event_category'], "Officials": parse_json_col(row['officials']) }
                }
        
        # --- 7. GENERIC COLUMN SPORTS (Chess, Carrom, Badminton, TT) ---
        elif sport in ['chess', 'carrom', 'badminton', 'table tennis']:
            table_map = {
                'chess': 'chess_match', 'carrom': 'carrom_matches',
                'badminton': 'badminton_match', 'table tennis': 'table_tennis_match'
            }
            # Handle column name variations
            t1_name_col = 'team_1_name' if sport in ['badminton', 'table tennis', 'carrom'] else 'team_a_name'
            t2_name_col = 'team_2_name' if sport in ['badminton', 'table tennis', 'carrom'] else 'team_b_name'
            
            table = table_map.get(sport)
            cur.execute(f"SELECT * FROM {table} WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            
            if row:
                # Extract up to 5 players
                t1_p = [row[f'team1_player{i}'] for i in range(1, 6) if row.get(f'team1_player{i}')]
                t2_p = [row[f'team2_player{i}'] for i in range(1, 6) if row.get(f'team2_player{i}')]

                data = {
                    "id": row['match_id'], "sport": sport.title(),
                    "team_a_name": row[t1_name_col], "team_b_name": row[t2_name_col],
                    "team_a_players": t1_p,
                    "team_b_players": t2_p,
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Umpires": row.get('umpires') }
                }
        
        # --- 8. DODGEBALL ---
        elif sport == 'dodgeball':
            cur.execute("SELECT * FROM dodgeball_match WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row:
                data = {
                    "id": row['match_id'], "sport": "Dodgeball",
                    "team_a_name": row['team_a_name'], "team_b_name": row['team_b_name'],
                    "team_a_players": parse_json_col(row['team_a_players']),
                    "team_b_players": parse_json_col(row['team_b_players']),
                    "date": row['start_time'].isoformat(), "venue": row['venue'],
                    "match_status": row['match_status'],
                    "info": { "Officials": parse_json_col(row['officials']) }
                }

        if data:
            return jsonify(data), 200
        return jsonify({"status": "error", "message": "Match not found"}), 404

    except Exception as e:
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/api/start_match/<int:match_id>', methods=['POST'])
def start_match(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = conn.cursor()
    
    raw_sport = request.args.get('sport', 'Cricket')
    sport = raw_sport.lower().replace('_', ' ').strip()
    
    try:
        table_map = {
            'cricket': 'cricket_match',
            'football': 'football_match',
            'kabaddi': 'kabaddi_match',
            'basketball': 'basketball_matches',
            'volleyball': 'volleyball_match',
            'athletics': 'athletics_match',
            'badminton': 'badminton_match',
            'table tennis': 'table_tennis_match',
            'chess': 'chess_match',
            'carrom': 'carrom_matches',
            'dodgeball': 'dodgeball_match'
        }
        
        table = table_map.get(sport)
        
        if table:
            cur.execute(f"UPDATE {table} SET match_status='live' WHERE match_id=%s", (match_id,))
            conn.commit()
            return jsonify({"status": "success"}), 200
        else:
            return jsonify({"status": "error", "message": "Sport not recognized"}), 400
            
    except Exception as e: 
        return jsonify({"status": "error", "message": str(e)}), 500
    finally: 
        conn.close()

@app.route('/api/get_matches/<sport_name>', methods=['GET'])
def get_matches(sport_name):
    status_param = request.args.get('status', 'upcoming')
    gender = request.args.get('gender', 'Boys')
    
    conn = get_db_connection()
    if not conn: return jsonify([])
    cur = conn.cursor()
    matches = []
    try:
        sport = sport_name.lower().replace('_', ' ')
        db_status = 'finished' if status_param == 'recent' else status_param
        sort_order = "DESC" if status_param == 'recent' else "ASC"
        
        def fmt_date(d):
            if isinstance(d, (datetime, date)): return d.strftime('%b %d')
            if isinstance(d, str):
                 try: return datetime.strptime(d, '%Y-%m-%d %H:%M:%S').strftime('%b %d')
                 except: return d
            return ''
            
        def fmt_time(d):
            if isinstance(d, (datetime, date)): return d.strftime('%I:%M %p')
            if isinstance(d, str):
                 try: return datetime.strptime(d, '%Y-%m-%d %H:%M:%S').strftime('%I:%M %p')
                 except: return d
            return ''

        # UPDATED: FETCH REAL SCORES WITH JOIN
        if sport == 'cricket':
            cur.execute(f"""SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status,
                        ls.team1_runs, ls.team1_wickets, ls.team2_runs, ls.team2_wickets
                        FROM cricket_match cm
                        LEFT JOIN cricket_match_livescore ls ON cm.match_id = ls.match_id
                        WHERE cm.match_status = %s AND cm.gender = %s ORDER BY cm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for r in rows: 
                s1 = f"{r[6]}/{r[7]}" if r[6] is not None else "0/0"
                s2 = f"{r[8]}/{r[9]}" if r[8] is not None else "0/0"
                matches.append({"id": r[0], "teamA": r[1], "teamB": r[2], "venue": r[3], "date": fmt_date(r[4]), "time": fmt_time(r[4]), "status": r[5], "scoreA": s1, "scoreB": s2})
        
        elif sport == 'football':
             cur.execute(f"""SELECT fm.match_id, fm.team_a_name, fm.team_b_name, fm.venue, fm.start_time, fm.match_status,
                         ls.team_a_goals, ls.team_b_goals 
                         FROM football_match fm 
                         LEFT JOIN football_match_livescore ls ON fm.match_id = ls.match_id
                         WHERE fm.match_status = %s AND fm.gender = %s ORDER BY fm.start_time {sort_order}""", (db_status, gender))
             rows = cur.fetchall()
             for r in rows: 
                 s1 = str(r[6]) if r[6] is not None else "0"
                 s2 = str(r[7]) if r[7] is not None else "0"
                 matches.append({"id": r[0], "teamA": r[1], "teamB": r[2], "venue": r[3], "date": fmt_date(r[4]), "time": fmt_time(r[4]), "status": r[5], "scoreA": s1, "scoreB": s2})
        
        elif sport == 'kabaddi':
            cur.execute(f"""SELECT km.match_id, km.team_a_name, km.team_b_name, km.venue, km.start_time, km.match_status,
                       kls.team_a_score, kls.team_b_score FROM kabaddi_match km LEFT JOIN kabaddi_match_livescore kls ON km.match_id = kls.match_id
                WHERE km.match_status = %s AND km.gender = %s ORDER BY km.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows:
                score_a = row[6] or 0
                score_b = row[7] or 0
                result_text = "Tie"
                if score_a > score_b: result_text = f"{row[1]} won"
                elif score_b > score_a: result_text = f"{row[2]} won"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": fmt_date(row[4]), "time": fmt_time(row[4]), 
                    "status": row[5], "scoreA": str(score_a), "scoreB": str(score_b), "summary": result_text
                })
        
        elif sport == 'basketball':
            cur.execute(f"""SELECT bm.match_id, bm.team_1_name, bm.team_2_name, bm.venue, bm.start_time, bm.match_status,
                            ls.team1_score, ls.team2_score, ls.current_quarter
                     FROM basketball_matches bm 
                     LEFT JOIN basketball_match_livescore ls ON bm.match_id = ls.match_id
                     WHERE bm.match_status = %s AND bm.gender = %s ORDER BY bm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows:
                t1s = row[6] or 0; t2s = row[7] or 0; cq = row[8] or 1
                summary = "Final" if row[5] == 'finished' else f"Q{cq} Live"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": fmt_date(row[4]), "time": fmt_time(row[4]), 
                    "status": row[5], "scoreA": str(t1s), "scoreB": str(t2s), "summary": summary
                })

        elif sport == 'athletics':
            cur.execute(f"""SELECT am.match_id, am.team_a_name, am.team_b_name, am.team_c_name, am.venue, am.start_time, am.match_status, am.event_category,
                       ls.winner, ls.game_status_text 
                FROM athletics_match am LEFT JOIN athletics_match_livescore ls ON am.match_id = ls.match_id
                WHERE am.match_status = %s AND am.gender = %s ORDER BY am.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows:
                summary = f"{row[7]}"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "teamC": row[3], "venue": row[4], 
                    "date": fmt_date(row[5]), "time": fmt_time(row[5]), 
                    "status": row[6], "scoreA": "", "scoreB": "", "summary": summary, "event_category": row[7]
                })

        elif sport == 'volleyball':
            cur.execute(f"""SELECT vm.match_id, vm.team_a_name, vm.team_b_name, vm.venue, vm.start_time, vm.match_status,
                       vls.team_a_sets_won, vls.team_b_sets_won FROM volleyball_match vm LEFT JOIN volleyball_match_livescore vls ON vm.match_id = vls.match_id
                WHERE vm.match_status = %s AND vm.gender = %s ORDER BY vm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows:
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": fmt_date(row[4]), "time": fmt_time(row[4]), 
                    "status": row[5], "scoreA": str(row[6] or 0), "scoreB": str(row[7] or 0), "summary": "Volleyball"
                })
        
        elif sport == 'badminton':
            cur.execute(f"""SELECT cm.match_id, cm.team_1_name, cm.team_2_name, cm.venue, cm.start_time, cm.match_status,
                        ls.team1_set1_points, ls.team1_set2_points, ls.team1_set3_points,
                        ls.team2_set1_points, ls.team2_set2_points, ls.team2_set3_points,
                        ls.current_set
                        FROM badminton_match cm 
                        LEFT JOIN badminton_match_livescore ls ON cm.match_id = ls.match_id
                        WHERE cm.match_status = %s AND cm.gender = %s ORDER BY cm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for r in rows:
                # Calculate basic sum for preview, or just show set wins. Showing points for now.
                # Simplified: showing current set points or total sets? Let's show points of current set
                c_set = r[12] if r[12] else 1
                if c_set == 1: sA = r[6] or 0; sB = r[9] or 0
                elif c_set == 2: sA = r[7] or 0; sB = r[10] or 0
                else: sA = r[8] or 0; sB = r[11] or 0
                
                matches.append({"id": r[0], "teamA": r[1], "teamB": r[2], "venue": r[3], "date": fmt_date(r[4]), "time": fmt_time(r[4]), "status": r[5], "scoreA": str(sA), "scoreB": str(sB)})

        elif sport == 'table tennis':
            cur.execute(f"""SELECT cm.match_id, cm.team_1_name, cm.team_2_name, cm.venue, cm.start_time, cm.match_status,
                         ls.team1_set1_points, ls.team2_set1_points 
                         FROM table_tennis_match cm 
                         LEFT JOIN table_tennis_livescore ls ON cm.match_id = ls.match_id
                         WHERE cm.match_status = %s AND cm.gender = %s ORDER BY cm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for r in rows: 
                sA = r[6] or 0; sB = r[7] or 0
                matches.append({"id": r[0], "teamA": r[1], "teamB": r[2], "venue": r[3], "date": fmt_date(r[4]), "time": fmt_time(r[4]), "status": r[5], "scoreA": str(sA), "scoreB": str(sB)})
        
        elif sport == 'carrom':
            cur.execute(f"""SELECT cm.match_id, cm.team_1_name, cm.team_2_name, cm.venue, cm.start_time, cm.match_status,
                        ls.game_status_text
                        FROM carrom_matches cm 
                        LEFT JOIN carrom_match_livescore ls ON cm.match_id = ls.match_id
                        WHERE cm.match_status = %s AND cm.gender = %s ORDER BY cm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows: matches.append({"id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], "date": fmt_date(row[4]), "time": fmt_time(row[4]), "status": row[5], "scoreA": "", "scoreB": "", "summary": row[6] or "Live"})

        elif sport == 'chess':
            cur.execute(f"""SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status,
                        ls.game_status_text
                        FROM chess_match cm 
                        LEFT JOIN chess_match_livescore ls ON cm.match_id = ls.match_id
                        WHERE cm.match_status = %s AND cm.gender = %s ORDER BY cm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows: matches.append({"id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], "date": fmt_date(row[4]), "time": fmt_time(row[4]), "status": row[5], "scoreA": "", "scoreB": "", "summary": row[6] or "Live"})
        
        elif sport == 'dodgeball':
            cur.execute(f"""SELECT dm.match_id, dm.team_a_name, dm.team_b_name, dm.venue, dm.start_time, dm.match_status,
                        ls.team_a_score, ls.team_b_score
                        FROM dodgeball_match dm
                        LEFT JOIN dodgeball_match_livescore ls ON dm.match_id = ls.match_id
                        WHERE dm.match_status = %s AND dm.gender = %s ORDER BY dm.start_time {sort_order}""", (db_status, gender))
            rows = cur.fetchall()
            for row in rows:
                sA = str(row[6]) if row[6] is not None else "0"
                sB = str(row[7]) if row[7] is not None else "0"
                summary = "Live" if row[5] == "live" else ("Upcoming" if row[5] == "upcoming" else "Finished")
                matches.append({"id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], "date": fmt_date(row[4]), "time": fmt_time(row[4]), "status": row[5], "scoreA": sA, "scoreB": sB, "summary": summary})

        return jsonify(matches)
    except Exception as e:
        print("Error fetching matches:", e)
        traceback.print_exc()
        return jsonify([])
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/download_scorecard_pdf/<int:match_id>', methods=['GET'])
def download_scorecard_pdf(match_id):
    # This is a placeholder for the PDF logic which wasn't fully detailed in the prompt
    # but the route was requested to be present.
    return jsonify({"status": "error", "message": "PDF generation not implemented on backend yet."}), 501

if __name__ == '__main__':
    update_db_schema() 
    app.run(host='0.0.0.0', port=5000, debug=True)