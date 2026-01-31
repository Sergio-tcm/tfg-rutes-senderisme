import requests
from flask import Blueprint, jsonify, request
from utils.geo import haversine_m

routing_bp = Blueprint("routing", __name__, url_prefix="/routing")

OSRM_BASE_URL = "https://router.project-osrm.org"  # público, sin API key

def _straight_line_response(start_lat, start_lon, end_lat, end_lon):
    distance_m = haversine_m(start_lat, start_lon, end_lat, end_lon)
    distance_km = distance_m / 1000.0
    duration_min = int(round((distance_km / 4.5) * 60))  # 4.5 km/h
    polyline = [[float(start_lat), float(start_lon)], [float(end_lat), float(end_lon)]]
    return {
        "distance_km": round(distance_km, 2),
        "duration_min": duration_min,
        "polyline": polyline,
        "steps": ["Camí"],
        "fallback": True,
    }

@routing_bp.get("/walking")
def walking_route():
    """
    GET /routing/walking?start_lat=..&start_lon=..&end_lat=..&end_lon=..
    Devuelve distancia, duración y polyline (lista de [lat, lon]).
    """

    # 1) Leer params
    start_lat = request.args.get("start_lat", type=float)
    start_lon = request.args.get("start_lon", type=float)
    end_lat = request.args.get("end_lat", type=float)
    end_lon = request.args.get("end_lon", type=float)

    # 2) Validar
    missing = [k for k, v in {
        "start_lat": start_lat,
        "start_lon": start_lon,
        "end_lat": end_lat,
        "end_lon": end_lon,
    }.items() if v is None]

    if missing:
        return jsonify({"error": f"Falten paràmetres: {', '.join(missing)}"}), 400

    # 3) OSRM pide coords en orden lon,lat
    coords = f"{start_lon},{start_lat};{end_lon},{end_lat}"

    # 4) Endpoint OSRM: /route/v1/foot/{coords}
    # overview=full -> geometría completa
    # geometries=geojson -> coordenadas como GeoJSON [lon, lat]
    url_foot = f"{OSRM_BASE_URL}/route/v1/foot/{coords}"
    url_walk = f"{OSRM_BASE_URL}/route/v1/walking/{coords}"

    try:
        params = {
            "overview": "full",
            "geometries": "geojson",
            "steps": "true",
        }

        r = requests.get(url_foot, params=params, timeout=12)
        if r.status_code != 200:
            r = requests.get(url_walk, params=params, timeout=12)
        r.raise_for_status()
        data = r.json()

        if data.get("code") != "Ok" or not data.get("routes"):
            fallback = _straight_line_response(start_lat, start_lon, end_lat, end_lon)
            return jsonify(fallback), 200

        route = data["routes"][0]
        distance_m = float(route.get("distance", 0.0))
        duration_s = float(route.get("duration", 0.0))

        # Fallback if OSRM makes a very large detour
        straight_m = haversine_m(start_lat, start_lon, end_lat, end_lon)
        if straight_m > 0 and distance_m > (straight_m * 1.8):
            fallback = _straight_line_response(start_lat, start_lon, end_lat, end_lon)
            return jsonify(fallback), 200

        # GeoJSON coordinates: [[lon,lat], [lon,lat], ...]
        coords_geo = route["geometry"]["coordinates"]
        polyline = [[float(lat), float(lon)] for lon, lat in coords_geo]  # a [lat,lon]

        # Steps: extract unique road types
        def classify_road(name):
            name = name.lower()
            if any(word in name for word in ['camino', 'sendero', 'camí', 'send', 'track', 'path', 'vereda', 'pista', 'senda', 'trail', 'footpath', 'sender']):
                return 'Camí'
            if any(word in name for word in ['carretera', 'autovia', 'autopista', 'highway', 'road', 'vía', 'calzada', 'ruta', 'autovía']):
                return 'Carretera'
            if any(word in name for word in ['carrer', 'avinguda', 'plaça', 'street', 'avenue', 'square', 'calle', 'plaza', 'paseo', 'rambla', 'travessera', 'passatge', 'ronda', 'glorieta', 'rotonda', 'passeig', 'plaça']):
                return 'Carrer'
            if any(word in name for word in ['pont', 'bridge', 'puente']):
                return 'Pont'
            if any(word in name for word in ['parc', 'jardí', 'park', 'garden', 'bosque', 'forest']):
                return 'Parc'
            return 'Altres' if name else None

        steps = []
        seen = set()
        if "legs" in route and route["legs"]:
            for step in route["legs"][0].get("steps", []):
                name = step.get("name", "").strip()
                road_type = classify_road(name)
                if road_type and road_type not in seen:
                    steps.append(road_type)
                    seen.add(road_type)

        return jsonify({
            "distance_km": round(distance_m / 1000.0, 2),
            "duration_min": int(round(duration_s / 60.0)),
            "polyline": polyline,
            "steps": steps,
        }), 200

    except requests.Timeout:
        return jsonify({"error": "Temps d'espera esgotat amb el servei de rutes"}), 504
    except requests.RequestException:
        return jsonify({"error": "Error comunicant amb el servei de rutes"}), 502
    except Exception:
        return jsonify({"error": "Error intern calculant la ruta"}), 500