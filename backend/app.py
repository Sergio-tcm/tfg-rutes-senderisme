from flask import Flask, jsonify
from flask_cors import CORS
from db import get_connection

app = Flask(__name__)
CORS(app)

@app.route('/')
def home():
    return {'message': 'Backend funcionando!'}

@app.route('/routes', methods=['GET'])
def get_routes():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT route_id, name, distance_km, difficulty
        FROM routes
    """)

    rows = cur.fetchall()

    routes = []
    for row in rows:
        routes.append({
            'route_id': row[0],
            'name': row[1],
            'distance_km': row[2],
            'difficulty': row[3],
        })

    cur.close()
    conn.close()

    return jsonify(routes)

if __name__ == '__main__':
    app.run(debug=True)
