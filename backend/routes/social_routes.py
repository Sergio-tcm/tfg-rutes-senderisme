from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from db import get_connection

social_bp = Blueprint("social", __name__, url_prefix="/routes")


@social_bp.post("/<int:route_id>/like")
@jwt_required()
def like_route(route_id: int):
    user_id = int(get_jwt_identity())
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT like_id
                FROM likes
                WHERE user_id = %s AND route_id = %s
                """,
                (user_id, route_id),
            )
            row = cur.fetchone()

            if row:
                return jsonify({"liked": True, "like_id": row[0]}), 200

            cur.execute(
                """
                INSERT INTO likes (user_id, route_id, created_at)
                VALUES (%s, %s, NOW())
                RETURNING like_id
                """,
                (user_id, route_id),
            )
            like_id = cur.fetchone()[0]

        conn.commit()
        return jsonify({"liked": True, "like_id": like_id}), 201
    finally:
        conn.close()


@social_bp.delete("/<int:route_id>/like")
@jwt_required()
def unlike_route(route_id: int):
    user_id = int(get_jwt_identity())
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM likes
                WHERE user_id = %s AND route_id = %s
                """,
                (user_id, route_id),
            )

        conn.commit()
        return jsonify({"liked": False}), 200
    finally:
        conn.close()


@social_bp.get("/<int:route_id>/likes/count")
def likes_count(route_id: int):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(*)
                FROM likes
                WHERE route_id = %s
                """,
                (route_id,),
            )
            count = int(cur.fetchone()[0])

        return jsonify({"route_id": route_id, "likes": count}), 200
    finally:
        conn.close()


@social_bp.get("/<int:route_id>/like/status")
@jwt_required()
def like_status(route_id: int):
    user_id = int(get_jwt_identity())
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM likes
                WHERE user_id = %s AND route_id = %s
                """,
                (user_id, route_id),
            )
            row = cur.fetchone()

        return jsonify({"route_id": route_id, "liked": bool(row)}), 200
    finally:
        conn.close()


@social_bp.get("/<int:route_id>/ratings")
def list_ratings(route_id: int):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT r.rating_id, r.user_id, r.route_id, r.score, r.comment, r.created_at,
                       u.name as user_name
                FROM ratings r
                LEFT JOIN users u ON u.user_id = r.user_id
                WHERE r.route_id = %s
                ORDER BY r.created_at DESC
                """,
                (route_id,),
            )
            rows = cur.fetchall()

        out = []
        for r in rows:
            out.append({
                "rating_id": r[0],
                "user_id": int(r[1]),
                "route_id": int(r[2]),
                "score": int(r[3]),
                "comment": r[4] or "",
                "created_at": r[5].isoformat() if r[5] else None,
                "user_name": r[6],
            })

        return jsonify(out), 200
    finally:
        conn.close()


@social_bp.post("/<int:route_id>/rating")
@jwt_required()
def rate_route(route_id: int):
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    score = data.get("score")
    comment = (data.get("comment") or "").strip()

    if score is None:
        return jsonify({"error": "score és obligatori"}), 400

    try:
        score_int = int(score)
    except Exception:
        return jsonify({"error": "score ha de ser un número"}), 400

    if score_int < 1 or score_int > 5:
        return jsonify({"error": "score ha d'estar entre 1 i 5"}), 400

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT rating_id
                FROM ratings
                WHERE user_id = %s AND route_id = %s
                """,
                (user_id, route_id),
            )
            row = cur.fetchone()

            if row:
                cur.execute(
                    """
                    UPDATE ratings
                    SET score = %s,
                        comment = %s,
                        created_at = NOW()
                    WHERE rating_id = %s
                    RETURNING rating_id
                    """,
                    (score_int, comment, row[0]),
                )
                rating_id = cur.fetchone()[0]
                conn.commit()
                return jsonify({
                    "rating_id": rating_id,
                    "route_id": route_id,
                    "user_id": user_id,
                    "score": score_int,
                    "comment": comment,
                }), 200

            cur.execute(
                """
                INSERT INTO ratings (user_id, route_id, score, comment, created_at)
                VALUES (%s, %s, %s, %s, NOW())
                RETURNING rating_id
                """,
                (user_id, route_id, score_int, comment),
            )
            rating_id = cur.fetchone()[0]

        conn.commit()
        return jsonify({
            "rating_id": rating_id,
            "route_id": route_id,
            "user_id": user_id,
            "score": score_int,
            "comment": comment,
        }), 201
    finally:
        conn.close()
