from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection
import math
from utils.geo import haversine_m
from services.difficulty_calculator import calculate_difficulty
from routes.route_cultural_routes import _sync_route_cultural_booleans

routes_bp = Blueprint("routes", __name__, url_prefix="/routes")

cultural_bp = Blueprint("cultural", __name__)

def normalize_difficulty(difficulty: str) -> str:
    """
    Normalize difficulty to standard format.
    Handles both Spanish and Catalan names.
    Returns: "Fácil", "Moderada", "Difícil", "Muy Difícil" (Spanish)
             or "Fàcil", "Mitjana", "Difícil", "Molt Difícil" (Catalan)
    """
    if not difficulty:
        return ""
    
    norm = difficulty.lower().strip()
    
    # Catalan spellings with proper capitalization
    if 'fàcil' in norm or 'facil' in norm or norm == 'easy':
        return 'Fàcil'
    elif 'mitt' in norm or 'media' in norm or 'moderate' in norm:
        return 'Mitjana'
    elif 'difícil' in norm or 'dificil' in norm or norm == 'difficult':
        # Check if it's "very difficult"
        if 'molt' in norm or 'muy' in norm or 'very' in norm:
            return 'Molt Difícil'
        return 'Difícil'
    elif 'molt' in norm or 'muy' in norm:
        return 'Molt Difícil'
    
    # Return original if can't determine
    return difficulty if difficulty else ""

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
        distance_km = float(r[3] or 0)
        elevation_gain = int(r[5] or 0)
        estimated_time = r[7] or ""
        difficulty_stored = r[4] or ""
        
        # Always calculate difficulty with the latest formula to avoid stale DB values
        computed_difficulty = calculate_difficulty(distance_km, elevation_gain, estimated_time, lang='ca')
        stored_normalized = normalize_difficulty(difficulty_stored)

        # Prefer computed difficulty to reclassify legacy "fàcil" entries
        difficulty = computed_difficulty or stored_normalized
        
        routes.append({
            "route_id": r[0],
            "name": r[1],
            "description": r[2] or "",
            "distance_km": distance_km,
            "difficulty": difficulty,
            "elevation_gain": elevation_gain,
            "location": r[6] or "",
            "estimated_time": estimated_time,
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
    difficulty_input = data.get("difficulty") or ""
    elevation_gain = data.get("elevation_gain")
    location = data.get("location") or ""
    estimated_time = data.get("estimated_time") or ""

    # Calculate difficulty if not provided or invalid
    # We compute difficulty with the unified formula regardless of input, to keep consistency
    difficulty = calculate_difficulty(distance_km, elevation_gain, estimated_time, lang='ca')

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
    
    # Recalculate difficulty for the response in case database stored empty
    response_distance = float(r[3] or 0)
    response_elevation = int(r[5] or 0)
    response_time = r[7] or ""
    response_difficulty_stored = r[4] or ""
    
    # Always return the fresh computed difficulty to ensure consistency for new routes
    response_difficulty = calculate_difficulty(response_distance, response_elevation, response_time, lang='ca')

    return jsonify({
        "route_id": r[0],
        "name": r[1],
        "description": r[2] or "",
        "distance_km": response_distance,
        "difficulty": response_difficulty,
        "elevation_gain": response_elevation,
        "location": r[6] or "",
        "estimated_time": response_time,
        "creator_id": int(r[8]),
        "cultural_summary": r[9] or "",
        "has_historical_value": bool(r[10]),
        "has_archaeology": bool(r[11]),
        "has_architecture": bool(r[12]),
        "has_natural_interest": bool(r[13]),
        "created_at": r[14].isoformat() if r[14] else None,
    }), 201

@routes_bp.route("/<int:route_id>/cultural-items", methods=["GET"])
def get_cultural_items(route_id):
    conn = get_connection()
    try:
        _sync_route_cultural_booleans(conn, route_id)
        conn.commit()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    ci.item_id, ci.title, ci.description,
                    ci.latitude, ci.longitude, ci.period, ci.item_type, ci.source_url,
                    rci.distance_m
                FROM route_cultural_items rci
                JOIN cultural_items ci ON ci.item_id = rci.item_id
                WHERE rci.route_id = %s
                ORDER BY rci.distance_m ASC NULLS LAST, ci.title ASC
                LIMIT 50
            """, (route_id,))
            rows = cur.fetchall()

        items = []
        for r in rows:
            items.append({
                "item_id": r[0],
                "title": r[1],
                "description": r[2],
                "latitude": float(r[3]),
                "longitude": float(r[4]),
                "period": r[5],
                "item_type": r[6],
                "source_url": r[7],
                "distance_m": r[8],
            })

        return jsonify(items), 200
    finally:
        conn.close()


@cultural_bp.route("/cultural-items/near", methods=["GET"])
def cultural_items_near():
    lat = request.args.get("lat", type=float)
    lon = request.args.get("lon", type=float)
    radius = request.args.get("radius", default=2000, type=int)  # metros
    item_type = request.args.get("type", default=None, type=str)

    if lat is None or lon is None:
        return jsonify({"error": "lat i lon són obligatoris"}), 400

    # Bounding box aproximada
    # 1 grado lat ~ 111.32km; lon depende de lat
    lat_deg = radius / 111_320.0
    lon_deg = radius / (111_320.0 * max(0.2, abs(math.cos(math.radians(lat)))))

    min_lat = lat - lat_deg
    max_lat = lat + lat_deg
    min_lon = lon - lon_deg
    max_lon = lon + lon_deg

    conn = get_connection()
    cur = conn.cursor()

    if item_type:
        cur.execute("""
            SELECT item_id, title, description, latitude, longitude, period, item_type, source_url
            FROM cultural_items
            WHERE latitude BETWEEN %s AND %s
              AND longitude BETWEEN %s AND %s
              AND LOWER(item_type) = LOWER(%s)
        """, (min_lat, max_lat, min_lon, max_lon, item_type))
    else:
        cur.execute("""
            SELECT item_id, title, description, latitude, longitude, period, item_type, source_url
            FROM cultural_items
            WHERE latitude BETWEEN %s AND %s
              AND longitude BETWEEN %s AND %s
        """, (min_lat, max_lat, min_lon, max_lon))

    rows = cur.fetchall()
    cur.close()
    conn.close()

    out = []
    for r in rows:
        item_id, title, desc, ilat, ilon, period, itype, source_url = r
        d = haversine_m(lat, lon, float(ilat), float(ilon))
        if d <= radius:
            out.append({
                "item_id": item_id,
                "title": title,
                "description": desc,
                "latitude": float(ilat),
                "longitude": float(ilon),
                "period": period,
                "item_type": itype,
                "source_url": source_url,
                "distance_m": round(d, 1),
            })

    # Ordena por cercanía
    out.sort(key=lambda x: x["distance_m"])
    return jsonify(out)