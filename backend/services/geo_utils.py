import math

def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)

    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def bbox_for_radius(lat, lon, radius_m):
    # 1 grado lat ~ 111_320 m
    dlat = radius_m / 111320.0
    # lon depende de latitud
    dlon = radius_m / (111320.0 * max(math.cos(math.radians(lat)), 1e-6))
    return (lat - dlat, lat + dlat, lon - dlon, lon + dlon)
