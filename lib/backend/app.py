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

# -------------------- API ENDPOINTS --------------------

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

# --- [KEEP OTHER ADD MATCH ROUTES HERE IF NEEDED] ---
# (Football, Kabaddi, etc. code remains same as your original, omitted here for brevity but ensure they are present in your file)

@app.route('/api/get_matches/<sport_name>', methods=['GET'])
def get_matches(sport_name):
    # (Your original get_matches code logic here - mostly fine)
    # ... Ensure you close connections in finally block ...
    status_param = request.args.get('status', 'upcoming')
    matches = []
    conn = get_db_connection()
    if not conn: return jsonify([])
    cur = None
    try:
        cur = conn.cursor()
        sport = sport_name.lower()
        db_status = 'finished' if status_param == 'recent' else status_param
        
        if sport == 'cricket':
            sql = """SELECT cm.match_id, cm.team_a_name, cm.team_b_name, cm.venue, cm.start_time, cm.match_status,
                       ls.team1_runs, ls.team1_wickets, ls.team2_runs, ls.team2_wickets
                FROM cricket_match cm LEFT JOIN cricket_match_livescore ls ON cm.match_id = ls.match_id
                WHERE cm.match_status = %s ORDER BY cm.start_time ASC"""
            cur.execute(sql, (db_status,))
            rows = cur.fetchall()
            for row in rows:
                matches.append({
                    "id": row[0], "teamA": row[1], "teamB": row[2], "venue": row[3], 
                    "date": row[4].strftime('%b %d') if row[4] else '', "time": row[4].strftime('%I:%M %p') if row[4] else '', 
                    "status": row[5], 
                    "scoreA": f"{row[6] or 0}/{row[7] or 0}", "scoreB": f"{row[8] or 0}/{row[9] or 0}"
                })
        # ... (Include other sports logic) ...
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
    try:
        cur = conn.cursor()
        # ... (Your original logic to fetch details) ...
        # Simplified for brevity in this fix:
        cur.execute("SELECT match_id, team_a_name, team_b_name, team_a_players, team_b_players, overs_per_innings, start_time, venue, umpires, match_status FROM cricket_match WHERE match_id = %s", (match_id,))
        match = cur.fetchone()
        if match:
             return jsonify({ 
                 "id": match[0], "team_a_name": match[1], "team_b_name": match[2], 
                 "team_a_players": parse_json_col(match[3]), "team_b_players": parse_json_col(match[4]), 
                 "overs_per_innings": match[5], "start_time": match[6].isoformat(), 
                 "venue": match[7], "umpires": parse_json_col(match[8]), 
                 "match_status": match[9], "sport": "Cricket" 
             })
        return jsonify({"status": "error", "message": "Match not found"}), 404
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

# --- FIXED UPDATE ROUTE ---
@app.route('/api/update_live_score/<int:match_id>', methods=['POST'])
def update_live_score(match_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn: return jsonify({"status": "error", "message": "DB Connection Failed"}), 500
    
    cur = None # Safe initialization
    try:
        cur = conn.cursor()
        
        update_fields = []
        params = []
        
        # Keys to exclude from automatic mapping (handled manually or ignored)
        excluded_keys = ['match_id', 'team1_timeline', 'team2_timeline', 'team1_batting', 'team2_bowling', 'team2_batting', 'team1_bowling']

        for key, value in data.items():
            if key not in excluded_keys:
                # Add to query
                update_fields.append(f"{key} = %s")
                params.append(value)
        
        # --- Handle Complex JSON fields Manually ---
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
            
        # --- FIX: Handle Timelines (was missing in original) ---
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
            
            # Also update main table status if needed
            if 'current_status' in data:
                status = data['current_status']
                if status in ['live', 'finished', 'upcoming']:
                    cur.execute("UPDATE cricket_match SET match_status = %s WHERE match_id = %s", (status, match_id))

            conn.commit()
            
        return jsonify({"status": "success", "message": "Live score updated"}), 200
    except Exception as e:
        if conn: conn.rollback()
        print("Update Error:")
        traceback.print_exc() # Print full error to console for debugging
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

# --- NEW: PDF DOWNLOAD ROUTE ---
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
        elements.append(Paragraph(f"Venue: {match['venue']} | Status: {score['current_status']}", styles['Normal']))
        elements.append(Spacer(1, 12))
        
        # Summary
        elements.append(Paragraph(f"Summary: {score['summary_text']}", styles['Heading2']))
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
    app.run(host='0.0.0.0', port=5000, debug=True)