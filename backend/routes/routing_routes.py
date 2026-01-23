import requests
from flask import Blueprint, jsonify, request

routing_bp = Blueprint("routing", __name__, url_prefix="/routing")

OSRM_BASE_URL = "https://router.project-osrm.org"  # público, sin API key

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
    url = f"{OSRM_BASE_URL}/route/v1/foot/{coords}"

    try:
        r = requests.get(
            url,
            params={
                "overview": "full",
                "geometries": "geojson",
                "steps": "false",
            },
            timeout=12,
        )
        r.raise_for_status()
        data = r.json()

        if data.get("code") != "Ok" or not data.get("routes"):
            return jsonify({"error": "No s'ha pogut calcular la ruta"}), 502

        route = data["routes"][0]
        distance_m = float(route.get("distance", 0.0))
        duration_s = float(route.get("duration", 0.0))

        # GeoJSON coordinates: [[lon,lat], [lon,lat], ...]
        coords_geo = route["geometry"]["coordinates"]
        polyline = [[float(lat), float(lon)] for lon, lat in coords_geo]  # a [lat,lon]

        return jsonify({
            "distance_km": round(distance_m / 1000.0, 2),
            "duration_min": int(round(duration_s / 60.0)),
            "polyline": polyline,
        }), 200

    except requests.Timeout:
        return jsonify({"error": "Temps d'espera esgotat amb el servei de rutes"}), 504
    except requests.RequestException:
        return jsonify({"error": "Error comunicant amb el servei de rutes"}), 502
    except Exception:
        return jsonify({"error": "Error intern calculant la ruta"}), 500