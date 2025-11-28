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

class CustomEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal): return str(o)
        if isinstance(o, (datetime, date)): return o.isoformat()
        if isinstance(o, (bytes, bytearray)): return o.decode('utf-8') 
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
        print(f"Error connecting to database: {e}")
        return None

def parse_json_col(val):
    if val is None: return []
    if isinstance(val, list) or isinstance(val, dict): return val
    if isinstance(val, (bytes, bytearray)):
        try: val = val.decode('utf-8')
        except: pass
    try: return json.loads(val)
    except: return []

# -------------------- KABADDI ENDPOINTS (NEW) --------------------

@app.route('/api/add_kabaddi_match', methods=['POST'])
def add_kabaddi_match():
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Fail"}), 500
    cur = None
    try:
        cur = conn.cursor()
        
        # Serialize JSON fields for LONGTEXT columns
        team_a_players = json.dumps(data.get('team_a_players', []))
        team_b_players = json.dumps(data.get('team_b_players', []))
        officials = json.dumps(data.get('officials', []))
        
        # Insert into kabaddi_match
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
        
        # Initialize kabaddi_match_livescore with default 0-0
        cur.execute("""
            INSERT INTO kabaddi_match_livescore 
            (match_id, team_a_score, team_b_score, match_time, current_half) 
            VALUES (%s, 0, 0, '00:00', '1st Half')
        """, (new_id,))
        
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        print("Error adding kabaddi match:", e)
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
        
        # Update livescore table (Only totals as per your schema)
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
        
        # Update main match status if needed
        if 'match_status' in data:
             cur.execute("UPDATE kabaddi_match SET match_status=%s WHERE match_id=%s", (data['match_status'], match_id))
             
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        if conn: conn.rollback()
        print("Error updating kabaddi score:", e)
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
        # Join tables to get names and score
        cur.execute("""
            SELECT ls.*, km.team_a_name, km.team_b_name, km.match_duration, km.match_status
            FROM kabaddi_match_livescore ls 
            JOIN kabaddi_match km ON ls.match_id = km.match_id 
            WHERE ls.match_id = %s
        """, (match_id,))
        row = cur.fetchone()
        if row: 
            return jsonify(row), 200
        return jsonify({"message": "Not found"}), 404
    except Exception as e:
        print("Error getting kabaddi score:", e)
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# -------------------- EXISTING API ENDPOINTS (Cricket & Football) --------------------

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
        
        vals = (data['team_a_name'], data['team_b_name'], team_a_players, team_b_players, int(data['overs']), data['start_time'], data['venue'], umpires)
        cur.execute(sql, vals)
        new_id = cur.lastrowid
        
        # Initialize livescore table
        cur.execute("INSERT INTO cricket_match_livescore (match_id, team1_name, team2_name, current_status, summary_text) VALUES (%s, %s, %s, 'upcoming', 'Match not started')", (new_id, data['team_a_name'], data['team_b_name']))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

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
        
        # Initialize football livescore table with default 0-0 score
        cur.execute("INSERT INTO football_match_livescore (match_id, team_a_goals, team_b_goals, match_time, current_half, match_status) VALUES (%s, 0, 0, '00:00', '1st Half', 'upcoming')", (new_id,))
        conn.commit()
        return jsonify({"status": "success", "match_id": new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_matches/<sport_name>', methods=['GET'])
def get_matches(sport_name):
    status_param = request.args.get('status', 'upcoming')
    matches = []
    conn = get_db_connection()
    if not conn: return jsonify([])
    cur = None
    try:
        cur = conn.cursor()
        sport = sport_name.lower()
        db_status = 'finished' if status_param == 'recent' else status_param
        
        # Determine Sort Order: Recent = Newest First (DESC), Upcoming/Live = Oldest First (ASC)
        sort_order = "DESC" if status_param == 'recent' else "ASC"
        
        if sport == 'cricket':
            sql = f"""SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status,
                       ls.team1_runs, ls.team1_wickets, ls.team2_runs, ls.team2_wickets, ls.summary_text
                FROM cricket_match cm LEFT JOIN cricket_match_livescore ls ON cm.match_id = ls.match_id
                WHERE cm.match_status = %s ORDER BY cm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                result_text = row[10] if row[10] else "Match Finished"
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], 
                    "scoreA": f"{row[6] or 0}/{row[7] or 0}", "scoreB": f"{row[8] or 0}/{row[9] or 0}",
                    "result": result_text
                })
        
        elif sport == 'football':
            sql = f"""SELECT fm.match_id, fm.team_a_name, fm.team_b_name, fm.venue, fm.start_time, fm.match_status,
                       fls.team_a_goals, fls.team_b_goals FROM football_match fm LEFT JOIN football_match_livescore fls ON fm.match_id = fls.match_id
                WHERE fm.match_status = %s ORDER BY fm.start_time {sort_order}"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                score_a = row[6] or 0
                score_b = row[7] or 0
                result_text = "Draw"
                if score_a > score_b: result_text = f"{row[1]} won"
                elif score_b > score_a: result_text = f"{row[2]} won"
                
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], 
                    "scoreA": str(score_a), "scoreB": str(score_b),
                    "result": result_text
                })

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
                    "status": row[5], "scoreA": str(score_a), "scoreB": str(score_b), "result": result_text
                })
        
        return jsonify(matches)
    except Exception as e:
        print("Error fetching matches:", e)
        return jsonify([])
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_match_details/<int:match_id>', methods=['GET'])
def get_match_details(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "Connection failed"}), 500
    cur = None
    sport = request.args.get('sport', 'Cricket').lower()
    try:
        cur = conn.cursor(dictionary=True)
        
        if sport == 'football':
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
        else: 
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
    sport = request.args.get('sport', 'Cricket').lower()
    try:
        cur = conn.cursor()
        table_name = ''
        ls_table = ''
        
        if sport == 'football':
            table_name = 'football_match'
            ls_table = 'football_match_livescore'
        elif sport == 'kabaddi':
            table_name = 'kabaddi_match'
            ls_table = 'kabaddi_match_livescore'
        else:
            table_name = 'cricket_match'
            ls_table = 'cricket_match_livescore'
        
        cur.execute(f"UPDATE {table_name} SET match_status = 'live' WHERE match_id = %s", (match_id,))
        
        # Check if livescore row exists
        cur.execute(f"SELECT match_id FROM {ls_table} WHERE match_id = %s", (match_id,))
        if not cur.fetchone():
             # Create if missing (should exist from Add, but safety check)
             if sport == 'football':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, team_a_goals, team_b_goals, match_time, current_half, match_status) VALUES (%s, 0, 0, '00:00', '1st Half', 'live')", (match_id,))
             elif sport == 'kabaddi':
                 cur.execute(f"INSERT INTO {ls_table} (match_id, team_a_score, team_b_score, match_time, current_half) VALUES (%s, 0, 0, '00:00', '1st Half')", (match_id,))
             else: # Cricket
                 cur.execute("SELECT team_a_name, team_b_name FROM cricket_match WHERE match_id = %s", (match_id,))
                 names = cur.fetchone()
                 if names:
                    cur.execute(f"INSERT INTO {ls_table} (match_id, team1_name, team2_name, current_status) VALUES (%s, %s, %s, 'live')", (match_id, names[0], names[1]))
        else:
             # Update status in livescore table if applicable
             if sport == 'football':
                 cur.execute(f"UPDATE {ls_table} SET match_status = 'live' WHERE match_id = %s", (match_id,))
             elif sport == 'cricket':
                 cur.execute(f"UPDATE {ls_table} SET current_status = 'live' WHERE match_id = %s", (match_id,))
             # Kabaddi livescore table doesn't have a status column in the provided schema, handled in main table

        conn.commit()
        return jsonify({"status": "success", "message": "Match started"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# --- CRICKET SCORE ENDPOINTS ---
@app.route('/api/update_live_score/<int:match_id>', methods=['POST'])
def update_live_score(match_id):
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
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.route('/api/get_live_score/<int:match_id>', methods=['GET'])
def get_live_score(match_id):
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
        print(e)
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# --- FOOTBALL SCORE ENDPOINTS ---

@app.route('/api/get_football_live_score/<int:match_id>', methods=['GET'])
def get_football_live_score(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        # UPDATED: Fetch player lists from football_match using JOIN
        cur.execute("""
            SELECT ls.*, fm.match_duration, fm.team_a_players, fm.team_b_players
            FROM football_match_livescore ls
            JOIN football_match fm ON ls.match_id = fm.match_id
            WHERE ls.match_id = %s
        """, (match_id,))
        row = cur.fetchone()
        
        if not row:
             return jsonify({"status": "error", "message": "Match data not initialized"}), 404

        # Parse JSON columns
        row['team_a_players'] = parse_json_col(row.get('team_a_players'))
        row['team_b_players'] = parse_json_col(row.get('team_b_players'))
        row['team_a_goal_details'] = parse_json_col(row.get('team_a_goal_details'))
        row['team_b_goal_details'] = parse_json_col(row.get('team_b_goal_details'))

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
        
        # UPDATED: Added goal details columns
        sql = """UPDATE football_match_livescore 
                 SET team_a_goals = %s, team_b_goals = %s, 
                     team_a_fouls = %s, team_b_fouls = %s,
                     team_a_freekicks = %s, team_b_freekicks = %s,
                     team_a_penalties = %s, team_b_penalties = %s,
                     team_a_goal_details = %s, team_b_goal_details = %s,
                     match_time = %s, current_half = %s, match_status = %s, last_updated = NOW() 
                 WHERE match_id = %s"""
        
        vals = (
            data['team_a_goals'], data['team_b_goals'], 
            data.get('team_a_fouls', 0), data.get('team_b_fouls', 0),
            data.get('team_a_freekicks', 0), data.get('team_b_freekicks', 0),
            data.get('team_a_penalties', 0), data.get('team_b_penalties', 0),
            json.dumps(data.get('team_a_goal_details', [])), json.dumps(data.get('team_b_goal_details', [])),
            data['match_time'], data['current_half'], data['status'], match_id
        )
        cur.execute(sql, vals)
        
        if 'status' in data:
             cur.execute("UPDATE football_match SET match_status = %s WHERE match_id = %s", (data['status'], match_id))
             
        conn.commit()
        return jsonify({"status": "success", "message": "Football score updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# --- PDF DOWNLOAD ---
@app.route('/api/download_scorecard_pdf/<int:match_id>', methods=['GET'])
def download_scorecard_pdf(match_id):
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    cur = None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM cricket_match WHERE match_id = %s", (match_id,))
        match = cur.fetchone()
        
        cur.execute("SELECT * FROM cricket_match_livescore WHERE match_id = %s", (match_id,))
        score = cur.fetchone()
        
        if not match or not score:
            return jsonify({"status": "error", "message": "Match data not found"}), 404

        team1_batting = parse_json_col(score.get("team1_batting_stats"))
        team1_bowling = parse_json_col(score.get("team1_bowling_stats"))
        team2_batting = parse_json_col(score.get("team2_batting_stats"))
        team2_bowling = parse_json_col(score.get("team2_bowling_stats"))

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        elements = []
        styles = getSampleStyleSheet()

        title = f"{match['team_a_name']} vs {match['team_b_name']}"
        elements.append(Paragraph(title, styles['Title']))
        elements.append(Paragraph(f"Venue: {match['venue']} | Status: {score['current_status']}", styles['Normal']))
        elements.append(Spacer(1, 12))
        
        elements.append(Paragraph(f"Summary: {score['summary_text']}", styles['Heading2']))
        elements.append(Spacer(1, 12))

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

        elements.append(Paragraph(f"{match['team_a_name']} Innings", styles['Heading3']))
        t1_bat_data = build_batting_table(team1_batting)
        if len(t1_bat_data) > 1:
            t1_table = Table(t1_bat_data)
            t1_table.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 1, colors.black)]))
            elements.append(t1_table)
        
        elements.append(Spacer(1, 12))
        
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
    app.run(host='0.0.0.0', port=5000, debug=True)