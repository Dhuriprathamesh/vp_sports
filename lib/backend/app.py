#!/usr/bin/env python3
import decimal
import json
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import mysql.connector
from datetime import datetime, date
import traceback
import io

# --- REPORTLAB IMPORTS (Required for PDF) ---
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors

# --- JSON Encoder ---
class CustomEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal): 
            return str(o)
        if isinstance(o, (datetime, date)): 
            return o.isoformat()
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
    'database': 'vpsports', 
    'port': 3306,
    'charset': 'utf8mb4'
}

def get_db_connection():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except mysql.connector.Error as e:
        print(f"--- MYSQL CONNECTION FAILED ---")
        print(f"Error Code: {e.errno}")
        print(f"Message: {e.msg}")
        return None

def parse_json_col(val):
    if val is None: return []
    if isinstance(val, list) or isinstance(val, dict): return val
    if isinstance(val, (bytes, bytearray)):
        try: val = val.decode('utf-8')
        except: pass
    try: return json.loads(val)
    except: return []

# --- DATABASE SCHEMA MIGRATION HELPER ---
def update_db_schema():
    """Checks for missing columns in tables and adds them if necessary."""
    conn = get_db_connection()
    if not conn:
        print("Skipping schema update: DB connection failed")
        return
    
    cursor = conn.cursor()
    try:
        print("Checking database schema...")
        
        # 1. Update football_match_livescore columns
        football_cols = [
            ("team_a_fouls", "INT DEFAULT 0"),
            ("team_b_fouls", "INT DEFAULT 0"),
            ("team_a_freekicks", "INT DEFAULT 0"),
            ("team_b_freekicks", "INT DEFAULT 0"),
            ("team_a_penalties", "INT DEFAULT 0"),
            ("team_b_penalties", "INT DEFAULT 0"),
            ("team_a_goal_details", "TEXT"), 
            ("team_b_goal_details", "TEXT"),
            ("team_a_foul_details", "TEXT"),
            ("team_b_foul_details", "TEXT"),
            ("last_resume_time", "DATETIME"),
            ("accumulated_seconds", "INT DEFAULT 0")
        ]
        
        cursor.execute("SHOW TABLES LIKE 'football_match_livescore'")
        if cursor.fetchone():
            cursor.execute("SHOW COLUMNS FROM football_match_livescore")
            existing_columns = [row[0] for row in cursor.fetchall()]
            for col_name, col_def in football_cols:
                if col_name not in existing_columns:
                    print(f"Adding missing column to football_match_livescore: {col_name}")
                    cursor.execute(f"ALTER TABLE football_match_livescore ADD COLUMN {col_name} {col_def}")
        
        # 2. Update basketball_match_livescore columns (Ensures robust basketball support)
        basketball_cols = [
            ("team1_q1_score", "INT DEFAULT 0"), ("team2_q1_score", "INT DEFAULT 0"),
            ("team1_q2_score", "INT DEFAULT 0"), ("team2_q2_score", "INT DEFAULT 0"),
            ("team1_q3_score", "INT DEFAULT 0"), ("team2_q3_score", "INT DEFAULT 0"),
            ("team1_q4_score", "INT DEFAULT 0"), ("team2_q4_score", "INT DEFAULT 0"),
            ("team1_ot_score", "INT DEFAULT 0"), ("team2_ot_score", "INT DEFAULT 0"),
            ("team1_fouls", "INT DEFAULT 0"), ("team2_fouls", "INT DEFAULT 0"),
            ("team1_timeouts", "INT DEFAULT 0"), ("team2_timeouts", "INT DEFAULT 0"),
            ("current_quarter", "INT DEFAULT 1")
        ]
        
        cursor.execute("SHOW TABLES LIKE 'basketball_match_livescore'")
        if cursor.fetchone():
            cursor.execute("SHOW COLUMNS FROM basketball_match_livescore")
            existing_columns = [row[0] for row in cursor.fetchall()]
            for col_name, col_def in basketball_cols:
                if col_name not in existing_columns:
                    print(f"Adding missing column to basketball_match_livescore: {col_name}")
                    cursor.execute(f"ALTER TABLE basketball_match_livescore ADD COLUMN {col_name} {col_def}")

        conn.commit()
        print("Database schema check complete.")
        
    except Exception as e:
        print(f"Schema update failed: {e}")
    finally:
        cursor.close()
        conn.close()

# ==============================================================================
#                                BASKETBALL ENDPOINTS
# ==============================================================================

@app.route('/api/add_basketball_match', methods=['POST'])
def add_basketball_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        # Prepare Players List (10 Main + 5 Subs = 15 total slots)
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        
        def pad_list(lst, size):
            return lst + [''] * (size - len(lst)) if len(lst) < size else lst[:size]

        t1_full = pad_list(t1_players, 15)
        t2_full = pad_list(t2_players, 15)

        umpires = data.get('umpires', [])
        umpires_str = ", ".join(umpires) if isinstance(umpires, list) else str(umpires)
        
        start_time = data.get('start_time')
        venue = data.get('venue')
        category = data.get('category', 'full_game')
        total_quarters = data.get('total_quarters', 4) 
        
        sql = """INSERT INTO basketball_matches
                 (team_1_name, team_2_name, start_time, venue, total_quarters, category, match_status, umpires,
                  team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                  team1_player6, team1_player7, team1_player8, team1_player9, team1_player10,
                  team1_sub1, team1_sub2, team1_sub3, team1_sub4, team1_sub5,
                  team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                  team2_player6, team2_player7, team2_player8, team2_player9, team2_player10,
                  team2_sub1, team2_sub2, team2_sub3, team2_sub4, team2_sub5)
                  VALUES 
                  (%s, %s, %s, %s, %s, %s, 'upcoming', %s,
                   %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                   %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        
        vals = [data['team_a_name'], data['team_b_name'], start_time, venue, total_quarters, category, umpires_str]
        vals.extend(t1_full)
        vals.extend(t2_full)
        
        cur.execute(sql, tuple(vals))
        new_id = cur.lastrowid
        
        # Initialize Livescore
        cur.execute("""INSERT INTO basketball_match_livescore 
                       (match_id, current_quarter, match_status, 
                        team1_score, team2_score, 
                        team1_q1_score, team2_q1_score,
                        team1_q2_score, team2_q2_score,
                        team1_q3_score, team2_q3_score,
                        team1_q4_score, team2_q4_score,
                        team1_ot_score, team2_ot_score,
                        team1_fouls, team2_fouls,
                        team1_timeouts, team2_timeouts) 
                       VALUES (%s, 1, 'not_started', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)""", (new_id,))
        
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_basketball_live_score/<int:match_id>', methods=['GET'])
def get_basketball_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        sql = """SELECT bm.team_1_name, bm.team_2_name, bm.total_quarters, bm.category,
                        ls.* FROM basketball_matches bm 
                 JOIN basketball_match_livescore ls ON bm.match_id = ls.match_id
                 WHERE bm.match_id = %s"""
        cur.execute(sql, (match_id,))
        row = cur.fetchone()
        
        if not row: return jsonify({"status": "error", "message": "Match not found"}), 404
        return jsonify(row), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_basketball_score/<int:match_id>', methods=['POST'])
def update_basketball_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        sql = """UPDATE basketball_match_livescore SET 
                 team1_score=%s, team2_score=%s,
                 team1_q1_score=%s, team2_q1_score=%s,
                 team1_q2_score=%s, team2_q2_score=%s,
                 team1_q3_score=%s, team2_q3_score=%s,
                 team1_q4_score=%s, team2_q4_score=%s,
                 team1_ot_score=%s, team2_ot_score=%s,
                 current_quarter=%s,
                 team1_fouls=%s, team2_fouls=%s,
                 team1_timeouts=%s, team2_timeouts=%s,
                 match_status=%s
                 WHERE match_id=%s"""
                 
        vals = (
            data.get('team1_score', 0), data.get('team2_score', 0),
            data.get('team1_q1_score', 0), data.get('team2_q1_score', 0),
            data.get('team1_q2_score', 0), data.get('team2_q2_score', 0),
            data.get('team1_q3_score', 0), data.get('team2_q3_score', 0),
            data.get('team1_q4_score', 0), data.get('team2_q4_score', 0),
            data.get('team1_ot_score', 0), data.get('team2_ot_score', 0),
            data.get('current_quarter', 1),
            data.get('team1_fouls', 0), data.get('team2_fouls', 0),
            data.get('team1_timeouts', 0), data.get('team2_timeouts', 0),
            data.get('match_status', 'live'),
            match_id
        )
        cur.execute(sql, vals)
        
        status = data.get('match_status')
        if status in ['live', 'finished']:
             cur.execute("UPDATE basketball_matches SET match_status = %s WHERE match_id = %s", (status, match_id))

        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                ATHLETICS ENDPOINTS
# ==============================================================================

@app.route('/api/add_athletics_match', methods=['POST'])
def add_athletics_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        t1_players = json.dumps(data.get('team_a_players', []))
        t2_players = json.dumps(data.get('team_b_players', []))
        t3_players = json.dumps(data.get('team_c_players', []))
        
        officials = json.dumps(data.get('officials', []))
        event_category = data.get('event_category', '100m Race')

        sql = """INSERT INTO athletics_match 
                 (team_a_name, team_b_name, team_c_name, 
                  team_a_players, team_b_players, team_c_players,
                  start_time, venue, officials, event_category, match_status) 
                  VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        
        vals = (
            data['team_a_name'], data['team_b_name'], data.get('team_c_name', 'Team C'),
            t1_players, t2_players, t3_players,
            data['start_time'], data['venue'], officials, event_category
        )
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        
        cur.execute("""INSERT INTO athletics_match_livescore 
                       (match_id, game_status_text) 
                       VALUES (%s, 'Race Not Started')""", (new_id,))
        
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_athletics_live_score/<int:match_id>', methods=['GET'])
def get_athletics_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        sql = """SELECT am.team_a_name, am.team_b_name, am.team_c_name, am.event_category, am.match_status,
                        ls.winner, ls.runner_up, ls.third_place, ls.game_status_text
                 FROM athletics_match am 
                 JOIN athletics_match_livescore ls ON am.match_id = ls.match_id 
                 WHERE am.match_id = %s"""
        cur.execute(sql, (match_id,))
        row = cur.fetchone()
        
        if row: return jsonify(row), 200
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_athletics_score/<int:match_id>', methods=['POST'])
def update_athletics_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor()
        sql = """UPDATE athletics_match_livescore 
                 SET winner = %s, runner_up = %s, third_place = %s, 
                     game_status_text = %s 
                 WHERE match_id = %s"""
        vals = (data.get('winner'), data.get('runner_up'), data.get('third_place'), data.get('game_status_text'), match_id)
        cur.execute(sql, vals)
        status = data.get('status')
        if status in ['live', 'finished']:
             cur.execute("UPDATE athletics_match SET match_status = %s WHERE match_id = %s", (status, match_id))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                BADMINTON ENDPOINTS
# ==============================================================================

@app.route('/api/add_badminton_match', methods=['POST'])
def add_badminton_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        if not isinstance(t1_players, list): t1_players = []
        if not isinstance(t2_players, list): t2_players = []
        t1_players += [''] * (5 - len(t1_players))
        t2_players += [''] * (5 - len(t2_players))

        umpires = json.dumps(data.get('umpires', []))
        total_sets = data.get('total_sets', 3)
        category = data.get('category', 'singles')

        sql = """INSERT INTO badminton_match 
                 (team_1_name, team_2_name, 
                  team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                  team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                  start_time, venue, umpires, total_sets, category, match_status) 
                  VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        
        vals = (
            data['team_a_name'], data['team_b_name'],
            t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4],
            t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4],
            data['start_time'], data['venue'], umpires, 
            total_sets, category
        )
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        
        status_text = f"Match not started"
        cur.execute("""INSERT INTO badminton_match_livescore 
                       (match_id, current_set, match_status) 
                       VALUES (%s, 1, %s)""", (new_id, status_text))
        
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
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        sql = """SELECT cm.team_1_name as team_a_name, cm.team_2_name as team_b_name, cm.match_status as main_status, cm.category,
                        ls.current_set, cm.total_sets,
                        ls.team1_set1_points, ls.team2_set1_points,
                        ls.team1_set2_points, ls.team2_set2_points,
                        ls.team1_set3_points, ls.team2_set3_points,
                        ls.match_status as game_status_text
                 FROM badminton_match cm 
                 JOIN badminton_match_livescore ls ON cm.match_id = ls.match_id
                 WHERE cm.match_id = %s"""
        cur.execute(sql, (match_id,))
        row = cur.fetchone()
        
        if not row: return jsonify({"status": "error", "message": "Match not found"}), 404
        
        row['match_status'] = row['main_status'] 
        return jsonify(row), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_badminton_score/<int:match_id>', methods=['POST'])
def update_badminton_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        sql_live = """UPDATE badminton_match_livescore 
                      SET current_set = %s, 
                          team1_set1_points = %s, team2_set1_points = %s,
                          team1_set2_points = %s, team2_set2_points = %s,
                          team1_set3_points = %s, team2_set3_points = %s,
                          match_status = %s 
                      WHERE match_id = %s"""
        
        vals = (
            data.get('new_current_set', 1),
            data.get('team1_set1_points', 0), data.get('team2_set1_points', 0),
            data.get('team1_set2_points', 0), data.get('team2_set2_points', 0),
            data.get('team1_set3_points', 0), data.get('team2_set3_points', 0),
            data.get('status_text'),
            match_id
        )
        cur.execute(sql_live, vals)
        
        status = data.get('status')
        if status in ['live', 'finished']:
             cur.execute("UPDATE badminton_match SET match_status = %s WHERE match_id = %s", (status, match_id))

        conn.commit()
        return jsonify({"status": "success", "message": "Score updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                TABLE TENNIS ENDPOINTS
# ==============================================================================

@app.route('/api/add_table_tennis_match', methods=['POST'])
def add_table_tennis_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
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

        sql = """INSERT INTO table_tennis_match 
                 (team_1_name, team_2_name, 
                  team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                  team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                  start_time, venue, umpires, total_sets, category, match_status) 
                  VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        vals = (
            data['team_a_name'], data['team_b_name'],
            t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4],
            t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4],
            data['start_time'], data['venue'], umpires, total_sets, category
        )
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        
        status_text = f"Selected: {pA} vs {pB}"
        cur.execute("""INSERT INTO table_tennis_livescore 
                       (match_id, current_set, total_sets, 
                        team1_set1_points, team2_set1_points,
                        game_status_text) 
                       VALUES (%s, 1, %s, 0, 0, %s)""", 
                       (new_id, total_sets, status_text))
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
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        sql = """SELECT cm.team_1_name as team_a_name, cm.team_2_name as team_b_name, cm.match_status, cm.category,
                        ls.current_set, cm.total_sets,
                        ls.team1_set1_points, ls.team2_set1_points,
                        ls.team1_set2_points, ls.team2_set2_points,
                        ls.team1_set3_points, ls.team2_set3_points,
                        ls.game_status_text, ls.winner
                 FROM table_tennis_match cm 
                 JOIN table_tennis_livescore ls ON cm.match_id = ls.match_id
                 WHERE cm.match_id = %s"""
        cur.execute(sql, (match_id,))
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
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        sql_live = """UPDATE table_tennis_livescore 
                      SET current_set = %s, 
                          team1_set1_points = %s, team2_set1_points = %s,
                          team1_set2_points = %s, team2_set2_points = %s,
                          team1_set3_points = %s, team2_set3_points = %s,
                          game_status_text = %s, winner = %s, last_updated = NOW() 
                      WHERE match_id = %s"""
        vals = (
            data.get('new_current_set', 1),
            data.get('team1_set1_points', 0), data.get('team2_set1_points', 0),
            data.get('team1_set2_points', 0), data.get('team2_set2_points', 0),
            data.get('team1_set3_points', 0), data.get('team2_set3_points', 0),
            data.get('status_text'), data.get('winner'),
            match_id
        )
        cur.execute(sql_live, vals)
        status = data.get('status')
        if status in ['live', 'finished']:
             cur.execute("UPDATE table_tennis_match SET match_status = %s WHERE match_id = %s", (status, match_id))
        conn.commit()
        return jsonify({"status": "success", "message": "Score updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                CHESS ENDPOINTS
# ==============================================================================

@app.route('/api/add_chess_match', methods=['POST'])
def add_chess_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        t1_players = (t1_players if isinstance(t1_players, list) else []) + [''] * 5
        t2_players = (t2_players if isinstance(t2_players, list) else []) + [''] * 5
        
        umpires = json.dumps(data.get('umpires', []))
        
        sql = """INSERT INTO chess_match 
                 (team_a_name, team_b_name, 
                  team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                  team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                  start_time, venue, umpires, match_status) 
                  VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        
        vals = (
            data['team_a_name'], data['team_b_name'],
            t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4],
            t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4],
            data['start_time'], data['venue'], umpires
        )
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
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        sql = """SELECT cm.team_a_name, cm.team_b_name, cm.match_status, 
                        ls.game_status_text, ls.winner 
                 FROM chess_match cm 
                 JOIN chess_match_livescore ls ON cm.match_id = ls.match_id 
                 WHERE cm.match_id = %s"""
        cur.execute(sql, (match_id,))
        row = cur.fetchone()
        
        if row: return jsonify(row), 200
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_chess_score/<int:match_id>', methods=['POST'])
def update_chess_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        sql = "UPDATE chess_match_livescore SET game_status_text = %s, winner = %s, last_updated = NOW() WHERE match_id = %s"
        cur.execute(sql, (data.get('game_status_text', ''), data.get('winner'), match_id))
        
        status = data.get('status')
        if status in ['live', 'finished']:
             cur.execute("UPDATE chess_match SET match_status = %s WHERE match_id = %s", (status, match_id))
             
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                CARROM ENDPOINTS
# ==============================================================================

@app.route('/api/add_carrom_match', methods=['POST'])
def add_carrom_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        t1_players = data.get('team_a_players', [])
        t2_players = data.get('team_b_players', [])
        t1_players = (t1_players if isinstance(t1_players, list) else []) + [''] * 5
        t2_players = (t2_players if isinstance(t2_players, list) else []) + [''] * 5
        
        umpires = json.dumps(data.get('umpires', []))
        
        sql = """INSERT INTO carrom_matches 
                 (team_1_name, team_2_name, 
                  team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                  team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                  start_time, venue, umpires, match_status) 
                  VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        
        vals = (
            data['team_a_name'], data['team_b_name'],
            t1_players[0], t1_players[1], t1_players[2], t1_players[3], t1_players[4],
            t2_players[0], t2_players[1], t2_players[2], t2_players[3], t2_players[4],
            data['start_time'], data['venue'], umpires
        )
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
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        sql = """SELECT cm.team_1_name as team_a_name, cm.team_2_name as team_b_name, cm.match_status, 
                        ls.game_status_text, ls.winner 
                 FROM carrom_matches cm 
                 JOIN carrom_match_livescore ls ON cm.match_id = ls.match_id 
                 WHERE cm.match_id = %s"""
        cur.execute(sql, (match_id,))
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
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        sql = "UPDATE carrom_match_livescore SET game_status_text = %s, winner = %s, last_updated = NOW() WHERE match_id = %s"
        cur.execute(sql, (data.get('game_status_text', ''), data.get('winner'), match_id))
        
        status = data.get('status')
        if status in ['live', 'finished']:
             cur.execute("UPDATE carrom_matches SET match_status = %s WHERE match_id = %s", (status, match_id))
             
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                VOLLEYBALL ENDPOINTS
# ==============================================================================

@app.route('/api/add_volleyball_match', methods=['POST'])
def add_volleyball_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        officials = json.dumps(data.get('officials', []))
        
        cur.execute("""
            INSERT INTO volleyball_match 
            (team_a_name, team_b_name, team_a_players, team_b_players, venue, start_time, match_format, officials, match_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')
        """, (
            data['team_a_name'], data['team_b_name'], 
            team_a_players, team_b_players, 
            data['venue'], data['start_time'], data.get('match_format', 'Best of 3 Sets'), 
            officials
        ))
        new_id = cur.lastrowid
        
        cur.execute("""
            INSERT INTO volleyball_match_livescore 
            (match_id, current_set, team_a_sets_won, team_b_sets_won, team_a_current_points, team_b_current_points, set_scores) 
            VALUES (%s, 1, 0, 0, 0, 0, '{}')
        """, (new_id,))
        
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
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT ls.*, vm.team_a_name, vm.team_b_name, vm.match_format, vm.match_status
            FROM volleyball_match_livescore ls 
            JOIN volleyball_match vm ON ls.match_id = vm.match_id 
            WHERE ls.match_id = %s
        """, (match_id,))
        row = cur.fetchone()
        
        if row:
            row['set_scores'] = parse_json_col(row.get('set_scores'))
            return jsonify(row), 200
        return jsonify({"message": "Not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_volleyball_score/<int:match_id>', methods=['POST'])
def update_volleyball_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        sql = """UPDATE volleyball_match_livescore SET 
                 current_set=%s, team_a_sets_won=%s, team_b_sets_won=%s,
                 team_a_current_points=%s, team_b_current_points=%s,
                 set_scores=%s
                 WHERE match_id=%s"""
        vals = (
            data['current_set'], data['team_a_sets_won'], data['team_b_sets_won'],
            data['team_a_current_points'], data['team_b_current_points'],
            json.dumps(data.get('set_scores', {})), 
            match_id
        )
        cur.execute(sql, vals)
        
        if 'match_status' in data:
             cur.execute("UPDATE volleyball_match SET match_status=%s WHERE match_id=%s", (data['match_status'], match_id))
             
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                KABADDI ENDPOINTS
# ==============================================================================

@app.route('/api/add_kabaddi_match', methods=['POST'])
def add_kabaddi_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        officials = json.dumps(data.get('officials', []))
        
        cur.execute("""
            INSERT INTO kabaddi_match 
            (team_a_name, team_b_name, team_a_players, team_b_players, venue, start_time, match_duration, officials, match_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')
        """, (
            data['team_a_name'], data['team_b_name'], 
            team_a_players, team_b_players, 
            data['venue'], data['start_time'], int(data.get('match_duration', 40)), 
            officials
        ))
        new_id = cur.lastrowid
        
        cur.execute("""
            INSERT INTO kabaddi_match_livescore 
            (match_id, team_a_score, team_b_score, match_time, current_half) 
            VALUES (%s, 0, 0, '00:00', '1st Half')
        """, (new_id,))
        
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
    cur = None
    try:
        cur = conn.cursor()
        
        sql = """UPDATE kabaddi_match_livescore SET 
                 team_a_score=%s, team_b_score=%s,
                 match_time=%s, current_half=%s
                 WHERE match_id=%s"""
        vals = (
            data['team_a_score'], data['team_b_score'],
            data['match_time'], data['current_half'],
            match_id
        )
        cur.execute(sql, vals)
        
        if 'match_status' in data:
             cur.execute("UPDATE kabaddi_match SET match_status=%s WHERE match_id=%s", (data['match_status'], match_id))
             
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
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT ls.*, km.team_a_name, km.team_b_name, km.match_duration, km.match_status
            FROM kabaddi_match_livescore ls 
            JOIN kabaddi_match km ON ls.match_id = km.match_id 
            WHERE ls.match_id = %s
        """, (match_id,))
        row = cur.fetchone()
        if row: return jsonify(row), 200
        return jsonify({"message": "Not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                CRICKET ENDPOINTS
# ==============================================================================

@app.route('/api/add_cricket_match', methods=['POST'])
def add_cricket_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        umpires = json.dumps(data.get('umpires', []))
        
        sql = """INSERT INTO cricket_match 
                 (team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires, match_status) 
                 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        
        vals = (data['team_a_name'], data['team_b_name'], team_a_players, team_b_players, int(data.get('overs', 20)), data['start_time'], data['venue'], umpires)
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        
        cur.execute("INSERT INTO cricket_match_livescore (match_id, team1_name, team2_name, current_status, summary_text) VALUES (%s, %s, %s, 'upcoming', 'Match not started')", (new_id, data['team_a_name'], data['team_b_name']))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_live_score/<int:match_id>', methods=['POST'])
def update_cricket_live_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
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
        return jsonify({"status": "success", "message": "Live score updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_live_score/<int:match_id>', methods=['GET'])
def get_cricket_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM cricket_match_livescore WHERE match_id = %s", (match_id,))
        row = cur.fetchone()
        
        if not row:
             cur.execute("SELECT team_a_name, team_b_name, match_status FROM cricket_match WHERE match_id = %s", (match_id,))
             match_info = cur.fetchone()
             if not match_info: return jsonify({"status": "error", "message": "Match not found"}), 404
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
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                FOOTBALL ENDPOINTS
# ==============================================================================

@app.route('/api/add_football_match', methods=['POST'])
def add_football_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        referees = json.dumps(data.get('referees', []))
        
        sql = """INSERT INTO football_match 
                 (team_a_name, team_b_name, team_a_players, team_b_players, match_duration, start_time, venue, referees, match_status) 
                 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'upcoming')"""
        
        vals = (data['team_a_name'], data['team_b_name'], team_a_players, team_b_players, int(data.get('match_duration', 90)), data['start_time'], data['venue'], referees)
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        
        cur.execute("INSERT INTO football_match_livescore (match_id, team_a_goals, team_b_goals, match_time, current_half, match_status) VALUES (%s, 0, 0, '00:00', '1st Half', 'upcoming')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_football_live_score/<int:match_id>', methods=['GET'])
def get_football_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT ls.*, fm.match_duration, fm.team_a_players, fm.team_b_players
            FROM football_match_livescore ls
            JOIN football_match fm ON ls.match_id = fm.match_id
            WHERE ls.match_id = %s
        """, (match_id,))
        row = cur.fetchone()
        
        if not row: return jsonify({"status": "error", "message": "Match data not initialized"}), 404

        # --- SERVER-SIDE TIME CALCULATION ---
        current_seconds = row.get('accumulated_seconds') or 0
        if row.get('last_resume_time') is not None and row.get('match_status') == 'live':
            now = datetime.now()
            diff = (now - row['last_resume_time']).total_seconds()
            current_seconds += int(diff)
        
        mins = current_seconds // 60
        secs = current_seconds % 60
        row['match_time'] = f"{int(mins):02}:{int(secs):02}"
        row['calculated_seconds'] = int(current_seconds)

        row['team_a_players'] = parse_json_col(row.get('team_a_players'))
        row['team_b_players'] = parse_json_col(row.get('team_b_players'))
        row['team_a_goal_details'] = parse_json_col(row.get('team_a_goal_details'))
        row['team_b_goal_details'] = parse_json_col(row.get('team_b_goal_details'))
        row['team_a_foul_details'] = parse_json_col(row.get('team_a_foul_details'))
        row['team_b_foul_details'] = parse_json_col(row.get('team_b_foul_details'))

        return jsonify(row), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/update_football_score/<int:match_id>', methods=['POST'])
def update_football_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        # Timer control actions: 'start' or 'stop'
        timer_action = data.get('timer_action')
        
        if timer_action == 'start':
            cur.execute("UPDATE football_match_livescore SET last_resume_time = NOW(), match_status = 'live' WHERE match_id = %s", (match_id,))
        elif timer_action == 'stop':
            cur.execute("SELECT last_resume_time, accumulated_seconds FROM football_match_livescore WHERE match_id = %s", (match_id,))
            row = cur.fetchone()
            if row and row[0]:
                last_resume = row[0]
                accumulated = row[1] or 0
                diff = (datetime.now() - last_resume).total_seconds()
                new_accumulated = accumulated + int(diff)
                cur.execute("UPDATE football_match_livescore SET accumulated_seconds = %s, last_resume_time = NULL, match_status = 'paused' WHERE match_id = %s", (new_accumulated, match_id))
        
        # Save fouls and goal details and other stats
        sql = """UPDATE football_match_livescore 
                 SET team_a_goals = %s, team_b_goals = %s, 
                     team_a_fouls = %s, team_b_fouls = %s,
                     team_a_freekicks = %s, team_b_freekicks = %s,
                     team_a_penalties = %s, team_b_penalties = %s,
                     team_a_goal_details = %s, team_b_goal_details = %s,
                     team_a_foul_details = %s, team_b_foul_details = %s,
                     match_time = %s, current_half = %s, match_status = %s, last_updated = NOW() 
                 WHERE match_id = %s"""
        
        vals = (
            data.get('team_a_goals'), data.get('team_b_goals'), 
            data.get('team_a_fouls', 0), data.get('team_b_fouls', 0),
            data.get('team_a_freekicks', 0), data.get('team_b_freekicks', 0),
            data.get('team_a_penalties', 0), data.get('team_b_penalties', 0),
            json.dumps(data.get('team_a_goal_details', [])), json.dumps(data.get('team_b_goal_details', [])),
            json.dumps(data.get('team_a_foul_details', [])), json.dumps(data.get('team_b_foul_details', [])),
            data.get('match_time'), data.get('current_half'), data.get('status'), match_id
        )
        cur.execute(sql, vals)
        
        if 'status' in data and data['status'] == 'finished':
             # Ensure accumulated time updated if was running
             cur.execute("SELECT last_resume_time, accumulated_seconds FROM football_match_livescore WHERE match_id = %s", (match_id,))
             row = cur.fetchone()
             if row and row[0]:
                last_resume = row[0]
                accumulated = row[1] or 0
                diff = (datetime.now() - last_resume).total_seconds()
                new_accumulated = accumulated + int(diff)
                cur.execute("UPDATE football_match_livescore SET accumulated_seconds = %s, last_resume_time = NULL, match_status = 'finished' WHERE match_id = %s", (new_accumulated, match_id))
             else:
                cur.execute("UPDATE football_match_livescore SET match_status = 'finished' WHERE match_id = %s", (match_id,))
             
             cur.execute("UPDATE football_match SET match_status = 'finished' WHERE match_id = %s", (match_id,))
             
        conn.commit()
        return jsonify({"status": "success", "message": "Football score/timer updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()


# ==============================================================================
#                                SHARED ENDPOINTS
# ==============================================================================

@app.route('/api/get_matches/<sport_name>', methods=['GET'])
def get_matches(sport_name):
    status_param = request.args.get('status', 'upcoming')
    matches = []
    conn = get_db_connection()
    if not conn: return jsonify([])
    cur = None
    try:
        cur = conn.cursor()
        sport = sport_name.lower().replace('_', ' ')
        db_status = 'finished' if status_param == 'recent' else status_param
        # Sort: Recent = DESC, Upcoming/Live = ASC
        sort_order = "DESC" if status_param == 'recent' else "ASC"
        
        # --- BASKETBALL ---
        if sport == 'basketball':
            sql = f"""SELECT bm.match_id, bm.team_1_name, bm.team_2_name, bm.venue, bm.start_time, bm.match_status,
                            ls.team1_score, ls.team2_score, ls.current_quarter
                     FROM basketball_matches bm 
                     LEFT JOIN basketball_match_livescore ls ON bm.match_id = ls.match_id
                     WHERE bm.match_status = %s ORDER BY bm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                status_text = row[5]
                t1s = row[6] or 0
                t2s = row[7] or 0
                cq = row[8] or 1
                
                summary = "Vs"
                scoreA = ""
                scoreB = ""
                
                if status_text == 'finished':
                    summary = "Final"
                    scoreA = str(t1s)
                    scoreB = str(t2s)
                elif status_text == 'live':
                    summary = f"Q{cq} Live"
                    scoreA = str(t1s)
                    scoreB = str(t2s)
                
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', 
                    "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], "scoreA": scoreA, "scoreB": scoreB, "summary": summary
                })

        # --- ATHLETICS ---
        elif sport == 'athletics':
            sql = f"""SELECT am.match_id, am.team_a_name, am.team_b_name, am.team_c_name, am.venue, am.start_time, am.match_status, am.event_category,
                       ls.winner, ls.game_status_text 
                FROM athletics_match am LEFT JOIN athletics_match_livescore ls ON am.match_id = ls.match_id
                WHERE am.match_status = %s ORDER BY am.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                status_text = row[6]
                winner = row[8]
                game_status = row[9]
                
                summary = f"{row[7]}"
                if status_text == 'finished': 
                    summary = f"Winner: {winner}" if winner else "Race Finished"
                elif status_text == 'live':
                    summary = game_status if game_status else "Race Live"

                matches.append({
                    "id": row[0], 
                    "teamA": row[1], "teamB": row[2], "teamC": row[3], 
                    "venue": row[4], 
                    "date": row[5].strftime('%b %d') if row[5] else '', 
                    "time": row[5].strftime('%I:%M %p') if row[5] else '', 
                    "status": row[6], 
                    "scoreA": "", "scoreB": "", 
                    "summary": summary,
                    "event_category": row[7]
                })

        # --- BADMINTON ---
        elif sport == 'badminton':
            sql = f"""SELECT cm.match_id, cm.team_1_name, cm.team_2_name, cm.venue, cm.start_time, cm.match_status,
                        ls.current_set, ls.match_status
                FROM badminton_match cm 
                LEFT JOIN badminton_match_livescore ls ON cm.match_id = ls.match_id
                WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                status_text = row[5]
                game_status = row[7] 
                summary = "Vs"
                if status_text == 'finished': summary = "Finished"
                elif status_text == 'live': summary = game_status if game_status else "Live"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], "scoreA": "", "scoreB": "", "summary": summary
                })

        # --- TABLE TENNIS ---
        elif sport == 'table tennis':
            sql = f"""SELECT cm.match_id, cm.team_1_name, cm.team_2_name, cm.venue, cm.start_time, cm.match_status,
                        ls.current_set, ls.winner, ls.game_status_text, cm.total_sets
                FROM table_tennis_match cm 
                LEFT JOIN table_tennis_livescore ls ON cm.match_id = ls.match_id
                WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                status_text = row[5]
                current_set = row[6]
                winner = row[7]
                game_status_text = row[8]
                total_sets = row[9]
                summary = "Vs"
                scoreA = ""
                scoreB = ""
                if status_text == 'finished':
                    summary = f"Winner: {winner}" if winner else "Finished"
                    scoreA = "1" if winner == row[1] or winner == 'Draw' else "0" 
                    scoreB = "1" if winner == row[2] or winner == 'Draw' else "0"
                elif status_text == 'live':
                    summary = game_status_text if game_status_text and game_status_text != 'Match not started' else f"Set {current_set} of {total_sets} Live"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], "scoreA": scoreA, "scoreB": scoreB, "summary": summary
                })

        # --- CARROM ---
        elif sport == 'carrom':
            sql = f"""SELECT cm.match_id, cm.team_1_name, cm.team_2_name, cm.venue, cm.start_time, cm.match_status,
                        ls.winner, ls.game_status_text
                FROM carrom_matches cm 
                LEFT JOIN carrom_match_livescore ls ON cm.match_id = ls.match_id
                WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                status_text = row[5]
                winner = row[6]
                result_display = f"Winner: {winner}" if status_text == 'finished' and winner else "Live"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], "scoreA": "0", "scoreB": "0", "summary": result_display
                })
        
        # --- CHESS ---
        elif sport == 'chess':
            sql = f"""SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status, ls.game_status_text, ls.winner 
                      FROM chess_match cm LEFT JOIN chess_match_livescore ls ON cm.match_id = ls.match_id 
                      WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                status_text = row[5]
                game_status = row[6]
                winner = row[7]
                result_display = "Vs"
                if status_text == 'finished': result_display = f"Winner: {winner}" if winner else "Match Finished"
                elif status_text == 'live': result_display = game_status if game_status else "Live"
                matches.append({"id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', "status": row[5], "scoreA": "White", "scoreB": "Black", "summary": result_display})
        
        # --- CRICKET ---
        elif sport == 'cricket':
            sql = f"""SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status, ls.team1_runs, ls.team1_wickets, ls.team2_runs, ls.team2_wickets, ls.summary_text
                      FROM cricket_match cm LEFT JOIN cricket_match_livescore ls ON cm.match_id = ls.match_id 
                      WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                result_text = row[10] if row[10] else "Match Finished"
                matches.append({"id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', "status": row[5], "scoreA": f"{row[6] or 0}/{row[7] or 0}", "scoreB": f"{row[8] or 0}/{row[9] or 0}", "result": result_text, "summary": result_text})
        
        # --- FOOTBALL ---
        elif sport == 'football':
             sql = f"""SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status, ls.team_a_goals, ls.team_b_goals 
                       FROM football_match cm LEFT JOIN football_match_livescore ls ON cm.match_id = ls.match_id 
                       WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
             cur.execute(sql, (db_status,))
             rows = cur.fetchall()
             for row in rows:
                score_a = row[6] or 0
                score_b = row[7] or 0
                result_text = "Draw"
                if score_a > score_b: result_text = f"{row[1]} won"
                elif score_b > score_a: result_text = f"{row[2]} won"
                matches.append({"id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', "status": row[5], "scoreA": str(row[6] or 0), "scoreB": str(row[7] or 0), "summary": result_text})

        # --- KABADDI ---
        elif sport == 'kabaddi':
            sql = f"""SELECT km.match_id, km.team_a_name, km.team_b_name, km.venue, km.start_time, km.match_status,
                       kls.team_a_score, kls.team_b_score FROM kabaddi_match km LEFT JOIN kabaddi_match_livescore kls ON km.match_id = kls.match_id
                WHERE km.match_status = %s ORDER BY km.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                score_a = row[6] or 0
                score_b = row[7] or 0
                result_text = "Tie"
                if score_a > score_b: result_text = f"{row[1]} won"
                elif score_b > score_a: result_text = f"{row[2]} won"
                
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], "scoreA": str(score_a), "scoreB": str(score_b), "summary": result_text
                })
        
        # --- VOLLEYBALL ---
        elif sport == 'volleyball':
            sql = f"""SELECT vm.match_id, vm.team_a_name, vm.team_b_name, vm.venue, vm.start_time, vm.match_status,
                       vls.team_a_sets_won, vls.team_b_sets_won, vls.team_a_current_points, vls.team_b_current_points,
                       vm.match_format
                FROM volleyball_match vm LEFT JOIN volleyball_match_livescore vls ON vm.match_id = vls.match_id
                WHERE vm.match_status = %s ORDER BY vm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                sets_a = row[6] or 0
                sets_b = row[7] or 0
                match_format = row[10] or 'Best of 3 Sets'
                result_text = "Match in progress"
                if sets_a > sets_b and row[5] == 'finished': result_text = f"{row[1]} won {sets_a}-{sets_b}"
                elif sets_b > sets_a and row[5] == 'finished': result_text = f"{row[2]} won {sets_b}-{sets_a}"
                
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], 
                    "scoreA": str(sets_a), "scoreB": str(sets_b), 
                    "summary": result_text, "matchFormat": match_format
                })

        return jsonify(matches)
    except Exception as e:
        print("Error fetching matches:", e)
        traceback.print_exc()
        return jsonify([])
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_match_details/<int:match_id>', methods=['GET'])
def get_match_details(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "Connection failed"}), 500
    cur = None
    sport = request.args.get('sport', 'Cricket').lower().replace('_', ' ')
    try:
        cur = conn.cursor(dictionary=True)
        
        if sport == 'basketball':
             cur.execute("SELECT * FROM basketball_matches WHERE match_id = %s", (match_id,))
             match = cur.fetchone()
             if match:
                 t1_p = [match[f'team1_player{i}'] for i in range(1, 11) if match.get(f'team1_player{i}')]
                 t1_s = [match[f'team1_sub{i}'] for i in range(1, 6) if match.get(f'team1_sub{i}')]
                 t2_p = [match[f'team2_player{i}'] for i in range(1, 11) if match.get(f'team2_player{i}')]
                 t2_s = [match[f'team2_sub{i}'] for i in range(1, 6) if match.get(f'team2_sub{i}')]
                 
                 umpires_data = match['umpires']
                 umpires_list = []
                 if umpires_data:
                     if isinstance(umpires_data, list): umpires_list = umpires_data
                     elif isinstance(umpires_data, str): umpires_list = umpires_data.split(', ')

                 return jsonify({
                     "id": match['match_id'], "team_a_name": match['team_1_name'], "team_b_name": match['team_2_name'],
                     "team_a_players": t1_p + t1_s, "team_b_players": t2_p + t2_s,
                     "start_time": match['start_time'].isoformat(), "venue": match['venue'], 
                     "umpires": umpires_list, 
                     "match_status": match['match_status'], "sport": "Basketball"
                 })

        elif sport == 'athletics':
             cur.execute("""SELECT match_id, team_a_name, team_b_name, team_c_name, 
                            team_a_players, team_b_players, team_c_players,
                            start_time, venue, officials, match_status, event_category 
                            FROM athletics_match WHERE match_id = %s""", (match_id,))
             match = cur.fetchone()
             if match:
                 return jsonify({ 
                     "id": match['match_id'], 
                     "team_a_name": match['team_a_name'], "team_b_name": match['team_b_name'], "team_c_name": match['team_c_name'],
                     "team_a_players": parse_json_col(match['team_a_players']), 
                     "team_b_players": parse_json_col(match['team_b_players']), 
                     "team_c_players": parse_json_col(match['team_c_players']), 
                     "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], 
                     "officials": parse_json_col(match['officials']), 
                     "match_status": match['match_status'], 
                     "event_category": match['event_category'],
                     "sport": "Athletics" 
                 })

        elif sport == 'badminton':
             cur.execute("""
                SELECT match_id, team_1_name, team_2_name, 
                       team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                       team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                       start_time, venue, umpires, match_status, total_sets, category
                FROM badminton_match WHERE match_id = %s
             """, (match_id,))
             match = cur.fetchone()
             if match:
                 team_a_players = [match[f'team1_player{i}'] for i in range(1, 6) if match.get(f'team1_player{i}')]
                 team_b_players = [match[f'team2_player{i}'] for i in range(1, 6) if match.get(f'team2_player{i}')]
                 return jsonify({ 
                     "id": match['match_id'], "team_a_name": match['team_1_name'], "team_b_name": match['team_2_name'], 
                     "team_a_players": team_a_players, "team_b_players": team_b_players, 
                     "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], "umpires": parse_json_col(match['umpires']),
                     "total_sets": match['total_sets'], "category": match['category'],
                     "match_status": match['match_status'], "sport": "Badminton" 
                 })
        
        elif sport == 'table tennis':
             cur.execute("""
                SELECT match_id, team_1_name, team_2_name, 
                       team1_player1, team1_player2, team1_player3, team1_player4, team1_player5,
                       team2_player1, team2_player2, team2_player3, team2_player4, team2_player5,
                       start_time, venue, umpires, match_status, total_sets, category
                FROM table_tennis_match WHERE match_id = %s
             """, (match_id,))
             match = cur.fetchone()
             if match:
                 team_a_players = [match[f'team1_player{i}'] for i in range(1, 6) if match.get(f'team1_player{i}')]
                 team_b_players = [match[f'team2_player{i}'] for i in range(1, 6) if match.get(f'team2_player{i}')]
                 return jsonify({ 
                     "id": match['match_id'], "team_a_name": match['team_1_name'], "team_b_name": match['team_2_name'], 
                     "team_a_players": team_a_players, "team_b_players": team_b_players, 
                     "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], "umpires": parse_json_col(match['umpires']),
                     "total_sets": match['total_sets'], "category": match['category'],
                     "match_status": match['match_status'], "sport": "Table Tennis" 
                 })

        elif sport == 'carrom':
             cur.execute("""SELECT match_id, team_1_name, team_2_name, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, start_time, venue, umpires, match_status FROM carrom_matches WHERE match_id = %s""", (match_id,))
             match = cur.fetchone()
             if match:
                 team_a_players = [match[f'team1_player{i}'] for i in range(1, 6) if match.get(f'team1_player{i}')]
                 team_b_players = [match[f'team2_player{i}'] for i in range(1, 6) if match.get(f'team2_player{i}')]
                 return jsonify({ "id": match['match_id'], "team_a_name": match['team_1_name'], "team_b_name": match['team_2_name'], "team_a_players": team_a_players, "team_b_players": team_b_players, "start_time": match['start_time'].isoformat(), "venue": match['venue'], "umpires": parse_json_col(match['umpires']), "match_status": match['match_status'], "sport": "Carrom" })
        
        elif sport == 'chess':
             cur.execute("""SELECT match_id, team_a_name, team_b_name, team1_player1, team1_player2, team1_player3, team1_player4, team1_player5, team2_player1, team2_player2, team2_player3, team2_player4, team2_player5, start_time, venue, umpires, match_status FROM chess_match WHERE match_id = %s""", (match_id,))
             match = cur.fetchone()
             if match:
                 team_a_players = [match[f'team1_player{i}'] for i in range(1, 6) if match.get(f'team1_player{i}')]
                 team_b_players = [match[f'team2_player{i}'] for i in range(1, 6) if match.get(f'team2_player{i}')]
                 pA = team_a_players[0] if team_a_players else 'N/A'
                 pB = team_b_players[0] if team_b_players else 'N/A'
                 return jsonify({ "id": match['match_id'], "team_a_name": match['team_a_name'], "team_b_name": match['team_b_name'], "team_a_players": team_a_players, "team_b_players": team_b_players, "match_format": "Standard", "start_time": match['start_time'].isoformat(), "venue": match['venue'], "umpires": parse_json_col(match['umpires']), "player_a_selected": pA, "player_b_selected": pB, "match_status": match['match_status'], "sport": "Chess" })

        elif sport == 'football':
             cur.execute("SELECT match_id, team_a_name, team_b_name, team_a_players, team_b_players, match_duration, start_time, venue, referees, match_status FROM football_match WHERE match_id = %s", (match_id,))
             match = cur.fetchone()
             if match:
                 return jsonify({ 
                     "id": match['match_id'], "team_a_name": match['team_a_name'], "team_b_name": match['team_b_name'], 
                     "team_a_players": parse_json_col(match['team_a_players']), "team_b_players": parse_json_col(match['team_b_players']), 
                     "match_duration": match['match_duration'], "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], "referees": parse_json_col(match['referees']), 
                     "match_status": match['match_status'], "sport": "Football" 
                 })

        elif sport == 'kabaddi':
             cur.execute("SELECT match_id, team_a_name, team_b_name, team_a_players, team_b_players, match_duration, start_time, venue, officials, match_status FROM kabaddi_match WHERE match_id = %s", (match_id,))
             match = cur.fetchone()
             if match:
                 return jsonify({ 
                     "id": match['match_id'], "team_a_name": match['team_a_name'], "team_b_name": match['team_b_name'], 
                     "team_a_players": parse_json_col(match['team_a_players']), "team_b_players": parse_json_col(match['team_b_players']), 
                     "match_duration": match['match_duration'], "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], "officials": parse_json_col(match['officials']), 
                     "match_status": match['match_status'], "sport": "Kabaddi" 
                 })

        elif sport == 'volleyball':
             cur.execute("SELECT match_id, team_a_name, team_b_name, team_a_players, team_b_players, match_format, start_time, venue, officials, match_status FROM volleyball_match WHERE match_id = %s", (match_id,))
             match = cur.fetchone()
             if match:
                 return jsonify({ 
                     "id": match['match_id'], "team_a_name": match['team_a_name'], "team_b_name": match['team_b_name'], 
                     "team_a_players": parse_json_col(match['team_a_players']), "team_b_players": parse_json_col(match['team_b_players']), 
                     "match_format": match['match_format'], "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], "officials": parse_json_col(match['officials']), 
                     "match_status": match['match_status'], "sport": "Volleyball" 
                 })

        else: # Default Cricket
            cur.execute("SELECT match_id, team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires, match_status FROM cricket_match WHERE match_id = %s", (match_id,))
            match = cur.fetchone()
            if match:
                 return jsonify({ 
                     "id": match['match_id'], "team_a_name": match['team_a_name'], "team_b_name": match['team_b_name'], 
                     "team_a_players": parse_json_col(match['team_a_players']), "team_b_players": parse_json_col(match['team_b_players']), 
                     "overs_per_innings": match['overs_per_innings'], "start_time": match['start_time'].isoformat(), 
                     "venue": match['venue'], "umpires": parse_json_col(match['umpires']), 
                     "match_status": match['match_status'], "sport": "Cricket" 
                 })
                 
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/start_match/<int:match_id>', methods=['POST'])
def start_match(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "Connection failed"}), 500
    cur = None
    sport = request.args.get('sport', 'Cricket').lower().replace('_', ' ')
    try:
        cur = conn.cursor()
        table_name = ''
        ls_table = ''
        
        # Determine Tables
        if sport == 'athletics':
            table_name = 'athletics_match'
            ls_table = 'athletics_match_livescore'
        elif sport == 'football':
            table_name = 'football_match'
            ls_table = 'football_match_livescore'
        elif sport == 'kabaddi':
            table_name = 'kabaddi_match'
            ls_table = 'kabaddi_match_livescore'
        elif sport == 'volleyball':
            table_name = 'volleyball_match'
            ls_table = 'volleyball_match_livescore'
        elif sport == 'badminton':
            table_name = 'badminton_match'
            ls_table = 'badminton_match_livescore'
        elif sport == 'table tennis':
            table_name = 'table_tennis_match'
            ls_table = 'table_tennis_livescore'
        elif sport == 'carrom':
            table_name = 'carrom_matches'
            ls_table = 'carrom_match_livescore'
        elif sport == 'chess':
            table_name = 'chess_match'
            ls_table = 'chess_match_livescore'
        elif sport == 'basketball':
            table_name = 'basketball_matches'
            ls_table = 'basketball_match_livescore'
        else:
            table_name = 'cricket_match'
            ls_table = 'cricket_match_livescore'
        
        # Update Main Status
        cur.execute(f"UPDATE {table_name} SET match_status = 'live' WHERE match_id = %s", (match_id,))
        
        # Create livescore row if missing
        cur.execute(f"SELECT match_id FROM {ls_table} WHERE match_id = %s", (match_id,))
        if not cur.fetchone():
             if sport == 'athletics':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, game_status_text) VALUES (%s, 'Race Started')", (match_id,))
             elif sport == 'football':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, team_a_goals, team_b_goals, match_time, current_half, match_status) VALUES (%s, 0, 0, '00:00', '1st Half', 'live')", (match_id,))
             elif sport == 'kabaddi':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, team_a_score, team_b_score, match_time, current_half) VALUES (%s, 0, 0, '00:00', '1st Half')", (match_id,))
             elif sport == 'volleyball':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, current_set, team_a_sets_won, team_b_sets_won, team_a_current_points, team_b_current_points, set_scores) VALUES (%s, 1, 0, 0, 0, 0, '{{}}')", (match_id,))
             elif sport == 'cricket':
                 cur.execute("SELECT team_a_name, team_b_name FROM cricket_match WHERE match_id = %s", (match_id,))
                 names = cur.fetchone()
                 if names:
                    cur.execute(f"INSERT INTO {ls_table} (match_id, team1_name, team2_name, current_status) VALUES (%s, %s, %s, 'live')", (match_id, names[0], names[1]))
             elif sport == 'badminton':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, current_set, team1_set1_points, match_status) VALUES (%s, 1, 0, 'Match Started')", (match_id,))
             elif sport == 'table tennis':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, current_set, team1_set1_points, game_status_text) VALUES (%s, 1, 0, 'Match Started')", (match_id,))
             elif sport == 'carrom':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, game_status_text) VALUES (%s, 'Match Started')", (match_id,))
             elif sport == 'chess':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, game_status_text) VALUES (%s, 'Match Started')", (match_id,))
             elif sport == 'basketball':
                 # Initialize basketball livescore according to new schema
                 cur.execute(f"INSERT INTO {ls_table} (match_id, current_quarter, team1_score, team2_score, match_status) VALUES (%s, 1, 0, 0, 'live')", (match_id,))
        else:
             # Just ensure status is live in ls table if applicable
             if sport == 'football':
                 cur.execute(f"UPDATE {ls_table} SET match_status = 'live' WHERE match_id = %s", (match_id,))
             elif sport == 'cricket':
                 cur.execute(f"UPDATE {ls_table} SET current_status = 'live' WHERE match_id = %s", (match_id,))
             elif sport == 'basketball':
                 cur.execute(f"UPDATE {ls_table} SET match_status = 'live' WHERE match_id = %s", (match_id,))

        conn.commit()
        return jsonify({"status": "success", "message": "Match started"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# ==============================================================================
#                                PDF GENERATION (CRICKET)
# ==============================================================================

@app.route('/api/download_scorecard_pdf/<int:match_id>', methods=['GET'])
def download_scorecard_pdf(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        # Fetch Match Data
        cur.execute("SELECT * FROM cricket_match WHERE match_id = %s", (match_id,))
        match = cur.fetchone()
        
        # Fetch Live Score Data
        cur.execute("SELECT * FROM cricket_match_livescore WHERE match_id = %s", (match_id,))
        score = cur.fetchone()
        
        if not match or not score:
            return jsonify({"status": "error", "message": "Match data not found"}), 404

        # Parse JSON Stats
        team1_batting = parse_json_col(score.get("team1_batting_stats"))
        team1_bowling = parse_json_col(score.get("team1_bowling_stats"))
        team2_batting = parse_json_col(score.get("team2_batting_stats"))
        team2_bowling = parse_json_col(score.get("team2_bowling_stats"))

        # Create PDF Buffer
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        elements = []
        styles = getSampleStyleSheet()

        # Title
        title = f"{match['team_a_name']} vs {match['team_b_name']}"
        elements.append(Paragraph(title, styles['Title']))
        elements.append(Paragraph(f"Venue: {match['venue']} | Status: {score.get('current_status', '')}", styles['Normal']))
        elements.append(Spacer(1, 12))
        
        # Summary
        elements.append(Paragraph(f"Summary: {score.get('summary_text', '')}", styles['Heading2']))
        elements.append(Spacer(1, 12))

        # Helper to build table data
        def build_batting_table(players):
            data = [['Batsman', 'Runs', 'Balls', 'Status']]
            for p in players:
                if isinstance(p, dict):
                     data.append([p.get('name', 'Unknown'), p.get('runs', 0), p.get('ballsFaced', 0), p.get('status', '-')])
            return data

        def build_bowling_table(players):
            data = [['Bowler', 'O', 'R', 'W']]
            for p in players:
                 if isinstance(p, dict) and p.get('ballsBowled', 0) > 0:
                    overs = f"{p.get('ballsBowled', 0) // 6}.{p.get('ballsBowled', 0) % 6}"
                    data.append([p.get('name', 'Unknown'), overs, p.get('runsConceded', 0), p.get('wicketsTaken', 0)])
            return data

        # Team 1 Innings
        elements.append(Paragraph(f"{match['team_a_name']} Innings", styles['Heading3']))
        t1_bat_data = build_batting_table(team1_batting)
        if len(t1_bat_data) > 1:
            t1_table = Table(t1_bat_data)
            t1_table.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 1, colors.black)]))
            elements.append(t1_table)
        
        elements.append(Spacer(1, 12))
        
        # Team 2 Innings
        elements.append(Paragraph(f"{match['team_b_name']} Innings", styles['Heading3']))
        t2_bat_data = build_batting_table(team2_batting)
        if len(t2_bat_data) > 1:
            t2_table = Table(t2_bat_data)
            t2_table.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 1, colors.black)]))
            elements.append(t2_table)

        doc.build(elements)
        buffer.seek(0)
        
        return send_file(buffer, as_attachment=True, download_name=f"scorecard_{match_id}.pdf", mimetype='application/pdf')

    except Exception as e:
        print(f"PDF Generation Error: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

if __name__ == '__main__':
    update_db_schema() # Check and update DB schema before running app
    app.run(host='0.0.0.0', port=5000, debug=True)