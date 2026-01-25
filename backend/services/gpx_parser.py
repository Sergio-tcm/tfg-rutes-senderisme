import xml.etree.ElementTree as ET

def parse_gpx_points(gpx_text: str):
    """
    Devuelve lista de (lat, lon) del track (trkpt).
    Compatible con GPX estándar aunque tenga namespaces.
    """
    root = ET.fromstring(gpx_text)

    # detectar namespace si existe
    ns = ""
    if root.tag.startswith("{") and "}" in root.tag:
        ns = root.tag.split("}")[0] + "}"

    pts = []
    for trkpt in root.findall(f".//{ns}trkpt"):
        lat = trkpt.attrib.get("lat")
        lon = trkpt.attrib.get("lon")
        if lat is None or lon is None:
            continue
        try:
            pts.append((float(lat), float(lon)))
        except ValueError:
            continue

    return pts
