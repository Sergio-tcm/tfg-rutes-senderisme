from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

routes_bp = Blueprint("routes", __name__, url_prefix="/routes")

@routes_bp.route("", methods=["GET"])
def get_routes():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT r.route_id, r.name, r.description, r.distance_km,
               r.difficulty, r.location, u.name
        FROM routes r
        JOIN users u ON r.creator_id = u.user_id
        ORDER BY r.created_at DESC
    """)
    rows = cur.fetchall()

    cur.close()
    conn.close()

    routes = []
    for r in rows:
        routes.append({
            "route_id": r[0],
            "name": r[1],
            "description": r[2],
            "distance_km": r[3],
            "difficulty": r[4],
            "location": r[5],
            "creator_name": r[6],
        })

    return jsonify(routes), 200


@routes_bp.route("", methods=["POST"])
@jwt_required()
def create_route():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    name = data.get("name", "").strip()
    description = data.get("description", "")
    distance_km = data.get("distance_km")
    difficulty = data.get("difficulty", "")
    location = data.get("location", "")

    if not name:
        return jsonify({"error": "El nom de la ruta és obligatori"}), 400

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO routes (name, description, distance_km, difficulty, location, creator_id)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING route_id
    """, (
        name, description, distance_km, difficulty, location, user_id
    ))

    route_id = cur.fetchone()[0]
    conn.commit()

    cur.close()
    conn.close()

    return jsonify({
        "route_id": route_id,
        "message": "Ruta creada correctament"
    }), 201
