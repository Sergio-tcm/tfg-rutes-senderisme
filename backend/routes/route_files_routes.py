import os
import uuid
import requests
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

route_files_bp = Blueprint("route_files", __name__, url_prefix="/routes")

BUCKET = "route-files"

def _public_url(object_path: str) -> str:
    supabase_url = os.getenv("SUPABASE_URL")
    return f"{supabase_url}/storage/v1/object/public/{BUCKET}/{object_path}"

def _upload_to_supabase_storage(file_bytes: bytes, object_path: str, content_type: str) -> str:
    supabase_url = os.getenv("SUPABASE_URL")
    service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not service_key:
        raise Exception("Falten variables SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY")

    upload_url = f"{supabase_url}/storage/v1/object/{BUCKET}/{object_path}"

    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": content_type,
    }

    res = requests.post(upload_url, headers=headers, data=file_bytes)
    if res.status_code not in (200, 201):
        raise Exception(f"Error pujant a Supabase Storage: {res.status_code} - {res.text}")

    return _public_url(object_path)


@route_files_bp.route("/<int:route_id>/files", methods=["POST"])
@jwt_required()
def upload_route_file(route_id: int):
    user_id = int(get_jwt_identity())

    # 1) Validar que existe ruta y que el usuario es el creador (seguridad básica)
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT creator_id FROM routes WHERE route_id = %s", (route_id,))
    row = cur.fetchone()
    if not row:
        cur.close()
        conn.close()
        return jsonify({"error": "Ruta no trobada"}), 404

    creator_id = int(row[0])
    if creator_id != user_id:
        cur.close()
        conn.close()
        return jsonify({"error": "No tens permís per pujar fitxers a aquesta ruta"}), 403

    # 2) Leer archivo
    if "file" not in request.files:
        cur.close()
        conn.close()
        return jsonify({"error": "Falta el fitxer (field 'file')"}), 400

    f = request.files["file"]
    filename = (f.filename or "").lower()

    if not filename.endswith(".gpx"):
        cur.close()
        conn.close()
        return jsonify({"error": "Només s'accepten fitxers .gpx"}), 400

    file_bytes = f.read()
    if not file_bytes:
        cur.close()
        conn.close()
        return jsonify({"error": "Fitxer buit"}), 400

    # 3) Subir a Storage
    object_path = f"{route_id}/{uuid.uuid4().hex}.gpx"
    try:
        file_url = _upload_to_supabase_storage(
            file_bytes=file_bytes,
            object_path=object_path,
            content_type="application/gpx+xml",
        )
    except Exception as e:
        cur.close()
        conn.close()
        return jsonify({"error": str(e)}), 500

    # 4) Guardar en route_files
    cur.execute("""
        INSERT INTO route_files (route_id, file_path, file_type)
        VALUES (%s, %s, %s)
        RETURNING file_id
    """, (route_id, file_url, "GPX"))

    file_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()

    return jsonify({
        "file_id": file_id,
        "route_id": route_id,
        "file_type": "GPX",
        "file_url": file_url
    }), 201


@route_files_bp.route("/<int:route_id>/files", methods=["GET"])
def list_route_files(route_id: int):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT file_id, file_path, file_type
        FROM route_files
        WHERE route_id = %s
        ORDER BY file_id DESC
    """, (route_id,))
    rows = cur.fetchall()
    cur.close()
    conn.close()

    files = []
    for r in rows:
        files.append({
            "file_id": r[0],
            "file_url": r[1],
            "file_type": r[2],
        })

    return jsonify(files), 200
