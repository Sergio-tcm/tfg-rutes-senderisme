from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from db import get_connection

user_preferences_bp = Blueprint("user_preferences", __name__, url_prefix="/user-preferences")


def _normalize_payload(data: dict):
    return {
        "fitness_level": (data.get("fitness_level") or "").strip(),
        "preferred_distance": data.get("preferred_distance"),
        "environment_type": (data.get("environment_type") or "").strip(),
        "cultural_interest": (data.get("cultural_interest") or "").strip(),
    }


@user_preferences_bp.route("", methods=["GET"])
@jwt_required()
def get_preferences():
    user_id = int(get_jwt_identity())

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT pref_id, user_id, fitness_level, preferred_distance,
                       environment_type, cultural_interest, updated_at
                FROM user_preferences
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()

        if row is None:
            return jsonify({}), 200

        return jsonify({
            "pref_id": row[0],
            "user_id": row[1],
            "fitness_level": row[2],
            "preferred_distance": float(row[3]) if row[3] is not None else None,
            "environment_type": row[4],
            "cultural_interest": row[5],
            "updated_at": row[6].isoformat() if row[6] else None,
        }), 200
    finally:
        conn.close()


@user_preferences_bp.route("", methods=["POST", "PUT"])
@jwt_required()
def upsert_preferences():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    payload = _normalize_payload(data)

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT pref_id FROM user_preferences WHERE user_id = %s
                """,
                (user_id,),
            )
            existing = cur.fetchone()

            if existing:
                cur.execute(
                    """
                    UPDATE user_preferences
                    SET fitness_level = %s,
                        preferred_distance = %s,
                        environment_type = %s,
                        cultural_interest = %s,
                        updated_at = NOW()
                    WHERE user_id = %s
                    RETURNING pref_id, user_id, fitness_level, preferred_distance,
                              environment_type, cultural_interest, updated_at
                    """,
                    (
                        payload["fitness_level"],
                        payload["preferred_distance"],
                        payload["environment_type"],
                        payload["cultural_interest"],
                        user_id,
                    ),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO user_preferences (
                        user_id, fitness_level, preferred_distance,
                        environment_type, cultural_interest, updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, NOW())
                    RETURNING pref_id, user_id, fitness_level, preferred_distance,
                              environment_type, cultural_interest, updated_at
                    """,
                    (
                        user_id,
                        payload["fitness_level"],
                        payload["preferred_distance"],
                        payload["environment_type"],
                        payload["cultural_interest"],
                    ),
                )

            row = cur.fetchone()
        conn.commit()

        return jsonify({
            "pref_id": row[0],
            "user_id": row[1],
            "fitness_level": row[2],
            "preferred_distance": float(row[3]) if row[3] is not None else None,
            "environment_type": row[4],
            "cultural_interest": row[5],
            "updated_at": row[6].isoformat() if row[6] else None,
        }), 200
    except Exception:
        conn.rollback()
        return jsonify({"error": "Error guardant preferències"}), 400
    finally:
        conn.close()
