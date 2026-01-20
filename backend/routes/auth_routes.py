from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity

from db import get_connection

auth_bp = Blueprint("auth", __name__, url_prefix="/auth")

@auth_bp.route("/register", methods=["POST"])
def register():
    data = request.get_json() or {}
    name = data.get("name", "").strip()
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not name or not email or not password:
        return jsonify({"error": "Falten camps: name, email, password"}), 400
    
    if "@" not in email or "." not in email:
        return jsonify({"error": "Email no vàlid"}), 400

    if len(password) < 8:
        return jsonify({"error": "Contrasenya massa curta (min 8)"}), 400

    password_hash = generate_password_hash(password)  # PBKDF2 por defecto

    conn = get_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            INSERT INTO users (name, email, password_hash)
            VALUES (%s, %s, %s)
            RETURNING user_id, name, email, created_at
            """,
            (name, email, password_hash),
        )
        user = cur.fetchone()
        conn.commit()
    except Exception:
        conn.rollback()
        return jsonify({"error": "Email ja registrat o error de base de dades"}), 409
    finally:
        cur.close()
        conn.close()

    return jsonify({
        "user_id": user[0],
        "name": user[1],
        "email": user[2],
        "created_at": str(user[3]),
    }), 201

@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json() or {}
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not email or not password:
        return jsonify({"error": "Falten camps: email, password"}), 400

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        "SELECT user_id, email, password_hash FROM users WHERE email=%s",
        (email,),
    )
    row = cur.fetchone()

    cur.close()
    conn.close()

    if row is None:
        return jsonify({"error": "Credencials incorrectes"}), 401

    user_id, user_email, password_hash = row

    if not check_password_hash(password_hash, password):
        return jsonify({"error": "Credencials incorrectes"}), 401

    access_token = create_access_token(identity=str(user_id))

    return jsonify({
        "access_token": access_token,
        "user_id": user_id,
        "email": user_email,
    }), 200

@auth_bp.route("/me", methods=["GET"])
@jwt_required()
def me():
    user_id = get_jwt_identity()

    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT user_id, name, email, created_at FROM users WHERE user_id=%s",
        (user_id,),
    )
    user = cur.fetchone()
    cur.close()
    conn.close()

    if user is None:
        return jsonify({"error": "Usuari no trobat"}), 404

    return jsonify({
        "user_id": user[0],
        "name": user[1],
        "email": user[2],
        "created_at": str(user[3]),
    }), 200
