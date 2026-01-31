from flask import Blueprint, request, jsonify
import requests
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection
import math
from utils.geo import haversine_m
from services.difficulty_calculator import calculate_difficulty
from services.gpx_parser import parse_gpx_points
from routes.route_cultural_routes import _sync_route_cultural_booleans, _get_gpx_url_for_route

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
                    r.route_id, r.name, r.description, r.distance_km, r.difficulty,
                    r.elevation_gain, r.location, r.estimated_time, r.creator_id,
                    r.cultural_summary, r.has_historical_value, r.has_archaeology,
                    r.has_architecture, r.has_natural_interest, r.created_at,
                    u.name as creator_name
                FROM routes r
                LEFT JOIN users u ON u.user_id = r.creator_id
                ORDER BY r.created_at DESC
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
            "creator_name": r[15],
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

    creator_name = None
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT name FROM users WHERE user_id=%s", (user_id,))
        row_name = cur.fetchone()
        creator_name = row_name[0] if row_name else None
    finally:
        cur.close()
        conn.close()

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
        "creator_name": creator_name,
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


@cultural_bp.route("/cultural-items/<int:item_id>/routes", methods=["GET"])
def routes_for_cultural_item(item_id: int):
    limit = request.args.get("limit", default=5, type=int)
    radius_m = request.args.get("radius_m", default=1000, type=int)
    step = request.args.get("step", default=30, type=int)
    max_routes = request.args.get("max_routes", default=60, type=int)
    max_cache_rows = request.args.get("max_cache_rows", default=2000, type=int)

    limit = max(1, min(limit, 50))
    radius_m = max(50, min(radius_m, 20000))
    step = max(1, min(step, 200))
    max_routes = max(10, min(max_routes, 200))
    max_cache_rows = max(200, min(max_cache_rows, 10000))

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS cultural_item_routes_cache (
            item_id INT NOT NULL,
            radius_m INT NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            PRIMARY KEY (item_id, radius_m)
        )
        """
    )

    cur.execute(
        """
        SELECT latitude, longitude
        FROM cultural_items
        WHERE item_id = %s
        """,
        (item_id,),
    )
    row = cur.fetchone()
    if not row:
        cur.close()
        conn.close()
        return jsonify({"error": "Punt cultural no trobat"}), 404

    item_lat = float(row[0])
    item_lon = float(row[1])

    cur.execute(
        """
        SELECT updated_at
        FROM cultural_item_routes_cache
        WHERE item_id = %s AND radius_m = %s
          AND updated_at > NOW() - INTERVAL '6 hours'
        """,
        (item_id, radius_m),
    )
    cache_row = cur.fetchone()

    if cache_row is None:
        cur.execute(
            """
            SELECT route_id
            FROM route_cultural_items
            WHERE item_id = %s
            """,
            (item_id,),
        )
        existing_route_ids = {int(r[0]) for r in cur.fetchall()}

        cur.execute(
            """
            SELECT r.route_id
            FROM routes r
            ORDER BY r.created_at DESC
            LIMIT %s
            """,
            (max_routes,),
        )
        route_ids = [int(r[0]) for r in cur.fetchall()]

        for route_id in route_ids:
            if route_id in existing_route_ids:
                continue

            gpx_url = _get_gpx_url_for_route(conn, route_id)
            if not gpx_url:
                continue

            try:
                r = requests.get(gpx_url, timeout=12)
                if r.status_code != 200:
                    continue

                points = parse_gpx_points(r.text)
                if len(points) < 2:
                    continue

                sampled = points[::step]
                min_dist = None
                for (lat, lon) in sampled:
                    d = haversine_m(item_lat, item_lon, float(lat), float(lon))
                    if min_dist is None or d < min_dist:
                        min_dist = d
                    if min_dist <= 1:
                        break

                if min_dist is not None and min_dist <= radius_m:
                    cur.execute(
                        """
                        INSERT INTO route_cultural_items(route_id, item_id, distance_m)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (route_id, item_id) DO NOTHING
                        """,
                        (route_id, item_id, int(round(min_dist))),
                    )
            except Exception:
                continue

        cur.execute(
            """
            INSERT INTO cultural_item_routes_cache(item_id, radius_m, updated_at)
            VALUES (%s, %s, NOW())
            ON CONFLICT (item_id, radius_m)
            DO UPDATE SET updated_at = NOW()
            """,
            (item_id, radius_m),
        )

        cur.execute("SELECT COUNT(*) FROM cultural_item_routes_cache")
        total_cache_rows = int(cur.fetchone()[0])
        if total_cache_rows > max_cache_rows:
            cur.execute(
                """
                DELETE FROM cultural_item_routes_cache
                WHERE (item_id, radius_m) IN (
                    SELECT item_id, radius_m
                    FROM cultural_item_routes_cache
                    ORDER BY updated_at ASC
                    LIMIT %s
                )
                """,
                (total_cache_rows - max_cache_rows,),
            )

        conn.commit()

    cur.execute(
        """
                SELECT
                    r.route_id, r.name, r.description, r.distance_km, r.difficulty,
                    r.elevation_gain, r.location, r.estimated_time, r.creator_id,
                    r.cultural_summary, r.has_historical_value, r.has_archaeology,
                    r.has_architecture, r.has_natural_interest, r.created_at,
                    rci.distance_m,
                    u.name as creator_name
                FROM route_cultural_items rci
                JOIN routes r ON r.route_id = rci.route_id
                LEFT JOIN users u ON u.user_id = r.creator_id
                WHERE rci.item_id = %s
                    AND rci.distance_m <= %s
        ORDER BY rci.distance_m ASC NULLS LAST, r.created_at DESC
        LIMIT %s
        """,
                (item_id, radius_m, limit),
    )

    rows = cur.fetchall()
    cur.close()
    conn.close()

    routes = []
    for r in rows:
        distance_km = float(r[3] or 0)
        elevation_gain = int(r[5] or 0)
        estimated_time = r[7] or ""
        difficulty_stored = r[4] or ""

        computed_difficulty = calculate_difficulty(distance_km, elevation_gain, estimated_time, lang='ca')
        stored_normalized = normalize_difficulty(difficulty_stored)
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
            "distance_m": float(r[15]) if r[15] is not None else None,
            "creator_name": r[16],
        })

    return jsonify(routes), 200