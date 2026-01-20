from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

routes_bp = Blueprint("routes", __name__, url_prefix="/routes")

@routes_bp.route("", methods=["GET"])
def get_routes():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT
          route_id, name, description, distance_km, difficulty,
          elevation_gain, location, estimated_time, creator_id,
          cultural_summary, has_historical_value, has_archaeology,
          has_architecture, has_natural_interest, created_at
        FROM routes
        ORDER BY created_at DESC
    """)
    rows = cur.fetchall()

    cur.close()
    conn.close()

    routes = []
    for r in rows:
        routes.append({
            "route_id": r[0],
            "name": r[1],
            "description": r[2] or "",
            "distance_km": float(r[3] or 0),
            "difficulty": r[4] or "",
            "elevation_gain": int(r[5] or 0),
            "location": r[6] or "",
            "estimated_time": r[7] or "",
            "creator_id": int(r[8]),
            "cultural_summary": r[9] or "",
            "has_historical_value": bool(r[10]),
            "has_archaeology": bool(r[11]),
            "has_architecture": bool(r[12]),
            "has_natural_interest": bool(r[13]),
            "created_at": r[14].isoformat() if r[14] else None,
        })

    return jsonify(routes), 200


@routes_bp.route("", methods=["POST"])
@jwt_required()
def create_route():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    name = (data.get("name") or "").strip()
    if not name:
        return jsonify({"error": "El nom de la ruta és obligatori"}), 400

    description = data.get("description") or ""
    distance_km = data.get("distance_km")
    difficulty = data.get("difficulty") or ""
    elevation_gain = data.get("elevation_gain")
    location = data.get("location") or ""
    estimated_time = data.get("estimated_time") or ""

    cultural_summary = data.get("cultural_summary") or ""
    has_historical_value = bool(data.get("has_historical_value", False))
    has_archaeology = bool(data.get("has_archaeology", False))
    has_architecture = bool(data.get("has_architecture", False))
    has_natural_interest = bool(data.get("has_natural_interest", False))

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO routes (
          name, description, distance_km, difficulty, elevation_gain,
          location, estimated_time, creator_id,
          cultural_summary, has_historical_value, has_archaeology,
          has_architecture, has_natural_interest
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING
          route_id, name, description, distance_km, difficulty,
          elevation_gain, location, estimated_time, creator_id,
          cultural_summary, has_historical_value, has_archaeology,
          has_architecture, has_natural_interest, created_at
    """, (
        name, description, distance_km, difficulty, elevation_gain,
        location, estimated_time, user_id,
        cultural_summary, has_historical_value, has_archaeology,
        has_architecture, has_natural_interest
    ))

    r = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()

    return jsonify({
        "route_id": r[0],
        "name": r[1],
        "description": r[2] or "",
        "distance_km": float(r[3] or 0),
        "difficulty": r[4] or "",
        "elevation_gain": int(r[5] or 0),
        "location": r[6] or "",
        "estimated_time": r[7] or "",
        "creator_id": int(r[8]),
        "cultural_summary": r[9] or "",
        "has_historical_value": bool(r[10]),
        "has_archaeology": bool(r[11]),
        "has_architecture": bool(r[12]),
        "has_natural_interest": bool(r[13]),
        "created_at": r[14].isoformat() if r[14] else None,
    }), 201

