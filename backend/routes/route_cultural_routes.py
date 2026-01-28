import requests
from flask import Blueprint, jsonify, request

from db import get_connection
from services.gpx_parser import parse_gpx_points
from services.geo_utils import haversine_m, bbox_for_radius

route_cultural_bp = Blueprint("route_cultural", __name__, url_prefix="/routes")

_ARCH_TYPES = {
    "conjunt arquitectònic",
    "edifici",
    "element arquitectònic",
    "element urbà",
    "obra civil",
}

_ARCHAEO_TYPES = {
    "jaciment arqueològic",
    "jaciment paleontològic",
}

_NATURAL_TYPES = {
    "espècimen botànic",
    "zona d'interès",
}

_HIST_TYPES = {
    "costumari",
    "manifestació festiva",
    "música i dansa",
    "tradició oral",
    "tècnica artesanal",
    "fons bibliogràfic",
    "fons d'imatges",
    "fons documental",
    "col·lecció",
    "objecte",
}


def _normalize_type(t: str) -> str:
    return (t or "").strip().lower()


def _derive_route_booleans(types: list[str]):
    has_arch = any(t in _ARCH_TYPES for t in types)
    has_archaeo = any(t in _ARCHAEO_TYPES for t in types)
    has_natural = any(t in _NATURAL_TYPES for t in types)

    # Històric: si hi ha items culturals/documentals o qualsevol tipus no mapejat
    has_hist = any(t in _HIST_TYPES for t in types) or any(
        t and t not in _ARCH_TYPES and t not in _ARCHAEO_TYPES and t not in _NATURAL_TYPES
        for t in types
    )

    return has_hist, has_archaeo, has_arch, has_natural


def _sync_route_cultural_booleans(conn, route_id: int):
    with conn.cursor() as cur:
        cur.execute(
            """
            select ci.item_type
            from route_cultural_items rci
            join cultural_items ci on ci.item_id = rci.item_id
            where rci.route_id = %s
            """,
            (route_id,),
        )
        rows = cur.fetchall()

    types = [_normalize_type(r[0]) for r in rows if r and r[0] is not None]
    has_hist, has_archaeo, has_arch, has_natural = _derive_route_booleans(types)

    with conn.cursor() as cur:
        cur.execute(
            """
            update routes
            set has_historical_value = %s,
                has_archaeology = %s,
                has_architecture = %s,
                has_natural_interest = %s
            where route_id = %s
            """,
            (has_hist, has_archaeo, has_arch, has_natural, route_id),
        )


@route_cultural_bp.post("/<int:route_id>/cultural-items/sync-booleans")
def sync_route_cultural_booleans(route_id: int):
    conn = get_connection()
    try:
        _sync_route_cultural_booleans(conn, route_id)
        conn.commit()
        return jsonify({"route_id": route_id, "status": "ok"}), 200
    finally:
        conn.close()

def _get_gpx_url_for_route(conn, route_id: int):
    with conn.cursor() as cur:
        # Probamos primero file_path (tu esquema original)
        try:
            cur.execute("""
                select file_path, file_type
                from route_files
                where route_id = %s
                order by file_id asc
            """, (route_id,))
            files = cur.fetchall()
            col_is_path = True
        except Exception:
            # fallback si en tu proyecto se llama file_url
            conn.rollback()
            cur.execute("""
                select file_url, file_type
                from route_files
                where route_id = %s
                order by file_id asc
            """, (route_id,))
            files = cur.fetchall()
            col_is_path = False

    if not files:
        return None

    for file_val, file_type in files:
        if str(file_type).upper() == "GPX":
            return file_val

    return files[0][0]


@route_cultural_bp.post("/<int:route_id>/cultural-items/recompute")
def recompute_route_cultural_items(route_id: int):
    """
    Calcula items culturales cercanos al track GPX y los guarda en route_cultural_items.
    Body opcional:
      { "radius_m": 150, "step": 20 }
    """
    body = request.get_json(silent=True) or {}
    radius_m = int(body.get("radius_m", 150))
    step = int(body.get("step", 20))  # 1 de cada 20 puntos

    conn = get_connection()
    try:
        gpx_url = _get_gpx_url_for_route(conn, route_id)
        if not gpx_url:
            return jsonify({"error": "Aquesta ruta no té cap GPX associat"}), 400

        # descargar gpx
        r = requests.get(gpx_url, timeout=15)
        if r.status_code != 200:
            return jsonify({"error": "No s'ha pogut descarregar el GPX"}), 502

        points = parse_gpx_points(r.text)
        if len(points) < 2:
            return jsonify({"error": "GPX sense punts suficients"}), 400

        sampled = points[::max(step, 1)]

        # limpiar asociaciones previas (recompute real)
        with conn.cursor() as cur:
            cur.execute("delete from route_cultural_items where route_id = %s", (route_id,))

        found = {}  # item_id -> min_distance_m

        with conn.cursor() as cur:
            for (lat, lon) in sampled:
                lat_min, lat_max, lon_min, lon_max = bbox_for_radius(lat, lon, radius_m)
                cur.execute("""
                    select item_id, latitude, longitude
                    from cultural_items
                    where latitude between %s and %s
                      and longitude between %s and %s
                """, (lat_min, lat_max, lon_min, lon_max))

                for item_id, ilat, ilon in cur.fetchall():
                    d = haversine_m(lat, lon, float(ilat), float(ilon))
                    if d <= radius_m:
                        prev = found.get(item_id)
                        if prev is None or d < prev:
                            found[item_id] = d

        # insertar
        with conn.cursor() as cur:
            for item_id, dist in found.items():
                cur.execute("""
                    insert into route_cultural_items(route_id, item_id, distance_m)
                    values (%s, %s, %s)
                    on conflict (route_id, item_id) do nothing
                """, (route_id, item_id, int(round(dist))))

        conn.commit()

        return jsonify({
            "route_id": route_id,
            "radius_m": radius_m,
            "step": step,
            "items_found": len(found),
        }), 200

    finally:
        conn.close()

@route_cultural_bp.get("/<int:route_id>/cultural-items")
def list_route_cultural_items(route_id: int):
    conn = get_connection()
    try:
        _sync_route_cultural_booleans(conn, route_id)
        conn.commit()
        with conn.cursor() as cur:
            cur.execute("""
                select
                  ci.item_id, ci.title, ci.description,
                  ci.latitude, ci.longitude, ci.period, ci.item_type, ci.source_url,
                  rci.distance_m
                from route_cultural_items rci
                join cultural_items ci on ci.item_id = rci.item_id
                where rci.route_id = %s
                order by rci.distance_m asc nulls last, ci.title asc
                limit 50
            """, (route_id,))
            rows = cur.fetchall()

        out = []
        for (item_id, title, desc, lat, lon, period, item_type, source_url, dist_m) in rows:
            out.append({
                "item_id": item_id,
                "title": title,
                "description": desc,
                "latitude": float(lat),
                "longitude": float(lon),
                "period": period,
                "item_type": item_type,
                "source_url": source_url,
                "distance_m": dist_m,
            })

        return jsonify(out), 200
    finally:
        conn.close()
