from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from db import get_connection

social_bp = Blueprint("social", __name__, url_prefix="/routes")


def _ensure_user_route_completions_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS user_route_completions (
                completion_id SERIAL PRIMARY KEY,
                user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
                route_id INT NOT NULL REFERENCES routes(route_id) ON DELETE CASCADE,
                completion_count INT NOT NULL DEFAULT 1,
                first_completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                last_completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (user_id, route_id)
            )
            """
        )


def _fitness_to_rank(fitness: str) -> int:
    value = (fitness or "").strip().lower()
    if value in {"alta", "alto", "high"}:
        return 2
    if value in {"mitjana", "mitja", "medio", "medium"}:
        return 1
    return 0


def _rank_to_fitness(rank: int) -> str:
    if rank >= 2:
        return "alta"
    if rank <= 0:
        return "baixa"
    return "mitjana"


def _rank_to_max_difficulty(rank: int) -> str:
    if rank >= 2:
        return "Difícil"
    if rank <= 0:
        return "Fàcil"
    return "Mitjana"


def _compute_adaptive_signals(base_fitness: str, base_distance: float, learning: dict):
    total_completions = int(learning.get("total_completions") or 0)
    if total_completions <= 0:
        base_rank = _fitness_to_rank(base_fitness)
        return {
            "effective_fitness_level": _rank_to_fitness(base_rank),
            "effective_max_difficulty": _rank_to_max_difficulty(base_rank),
            "effective_preferred_distance": float(base_distance),
        }

    learned_weight = min(0.4, (total_completions / 10.0) * 0.4)
    base_weight = 1.0 - learned_weight

    base_rank = float(_fitness_to_rank(base_fitness))
    learned_rank = float(learning.get("avg_difficulty_rank") or 0.0)
    effective_rank = (base_rank * base_weight) + (learned_rank * learned_weight)
    effective_rank_int = int(round(max(0.0, min(2.0, effective_rank))))

    learned_distance = float(learning.get("avg_distance_km") or base_distance)
    effective_distance = (float(base_distance) * base_weight) + (learned_distance * learned_weight)

    return {
        "effective_fitness_level": _rank_to_fitness(effective_rank_int),
        "effective_max_difficulty": _rank_to_max_difficulty(effective_rank_int),
        "effective_preferred_distance": round(max(1.0, effective_distance), 2),
    }


def _load_adaptive_snapshot(conn, user_id: int):
    base_fitness = "mitjana"
    base_distance = 10.0

    with conn.cursor() as cur:
        try:
            cur.execute(
                """
                SELECT fitness_level, preferred_distance
                FROM user_preferences
                WHERE user_id = %s
                """,
                (user_id,),
            )
            pref = cur.fetchone()
            if pref is not None:
                base_fitness = pref[0] or "mitjana"
                if pref[1] is not None:
                    base_distance = float(pref[1])
        except Exception:
            pass

        learning_row = (0, 0, 0)
        try:
            cur.execute(
                """
                SELECT
                    COALESCE(SUM(urc.completion_count), 0) AS total_completions,
                    COALESCE(
                        SUM(urc.completion_count * COALESCE(r.distance_km, 0))
                        / NULLIF(SUM(urc.completion_count), 0),
                        0
                    ) AS avg_distance_km,
                    COALESCE(
                        SUM(
                            urc.completion_count *
                            CASE
                                WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%molt%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%muy%%' THEN 3
                                WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%dif%%' THEN 2
                                WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%mitj%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%moder%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%media%%' THEN 1
                                ELSE 0
                            END
                        )
                        / NULLIF(SUM(urc.completion_count), 0),
                        0
                    ) AS avg_difficulty_rank
                FROM user_route_completions urc
                JOIN routes r ON r.route_id = urc.route_id
                WHERE urc.user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()
            if row is not None:
                learning_row = row
        except Exception:
            pass

    learning = {
        "total_completions": int(learning_row[0] or 0),
        "avg_distance_km": float(learning_row[1] or 0),
        "avg_difficulty_rank": float(learning_row[2] or 0),
    }
    adaptive = _compute_adaptive_signals(base_fitness, base_distance, learning)
    adaptive["total_completed_routes"] = learning["total_completions"]
    return adaptive


def _build_preferences_update_payload(before, after):
    if before is None or after is None:
        return {
            "preferences_updated": False,
            "preference_update_message": "Ruta completada. Preferències sense canvis.",
        }

    changed_max_diff = before.get("effective_max_difficulty") != after.get("effective_max_difficulty")
    changed_fitness = before.get("effective_fitness_level") != after.get("effective_fitness_level")
    before_dist = float(before.get("effective_preferred_distance") or 0)
    after_dist = float(after.get("effective_preferred_distance") or 0)
    changed_distance = abs(after_dist - before_dist) >= 0.2

    updated = changed_max_diff or changed_fitness or changed_distance

    if updated:
        changes = []
        if changed_max_diff:
            changes.append(
                f"dificultat recomanada: {before.get('effective_max_difficulty')} → {after.get('effective_max_difficulty')}"
            )
        if changed_fitness:
            changes.append(
                f"perfil físic: {before.get('effective_fitness_level')} → {after.get('effective_fitness_level')}"
            )
        if changed_distance:
            changes.append(
                f"distància recomanada: {before_dist:.1f} km → {after_dist:.1f} km"
            )
        return {
            "preferences_updated": True,
            "preference_update_message": "Preferències actualitzades: " + "; ".join(changes),
        }

    return {
        "preferences_updated": False,
        "preference_update_message": "Ruta completada. Preferències iguals de moment.",
    }


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


@social_bp.get("/liked")
@jwt_required()
def liked_routes():
    user_id = int(get_jwt_identity())
    conn = get_connection()
    try:
        _ensure_user_route_completions_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    r.route_id, r.name, r.description, r.distance_km, r.difficulty,
                    r.elevation_gain, r.location, r.estimated_time, r.creator_id,
                    r.cultural_summary, r.has_historical_value, r.has_archaeology,
                    r.has_architecture, r.has_natural_interest, r.created_at,
                    u.name AS creator_name,
                    EXISTS (
                        SELECT 1
                        FROM user_route_completions urc
                        WHERE urc.user_id = %s AND urc.route_id = r.route_id
                    ) AS completed_by_user
                FROM likes l
                JOIN routes r ON r.route_id = l.route_id
                LEFT JOIN users u ON u.user_id = r.creator_id
                WHERE l.user_id = %s
                ORDER BY l.created_at DESC
                """,
                (user_id, user_id),
            )
            rows = cur.fetchall()

        out = []
        for r in rows:
            out.append({
                "route_id": int(r[0]),
                "name": r[1] or "",
                "description": r[2] or "",
                "distance_km": float(r[3] or 0),
                "difficulty": r[4] or "",
                "elevation_gain": int(r[5] or 0),
                "location": r[6] or "",
                "estimated_time": r[7] or "",
                "creator_id": int(r[8]),
                "cultural_summary": r[9] or "",
                "has_historical_value": bool(r[10]),
                "has_archaeology": bool(r[11]),
                "has_architecture": bool(r[12]),
                "has_natural_interest": bool(r[13]),
                "created_at": r[14].isoformat() if r[14] else None,
                "creator_name": r[15],
                "completed_by_user": bool(r[16]),
            })

        return jsonify(out), 200
    finally:
        conn.close()


@social_bp.post("/<int:route_id>/complete")
@jwt_required()
def complete_route(route_id: int):
    user_id = int(get_jwt_identity())

    conn = get_connection()
    try:
        _ensure_user_route_completions_table(conn)
        before_snapshot = _load_adaptive_snapshot(conn, user_id)
        after_snapshot = None
        update_payload = {
            "preferences_updated": False,
            "preference_update_message": "Ruta completada. Preferències iguals de moment.",
        }

        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM routes
                WHERE route_id = %s
                """,
                (route_id,),
            )
            route_exists = cur.fetchone()
            if not route_exists:
                return jsonify({"error": "Ruta no trobada"}), 404

            cur.execute(
                """
                INSERT INTO user_route_completions (
                    user_id, route_id, completion_count, first_completed_at, last_completed_at
                )
                VALUES (%s, %s, 1, NOW(), NOW())
                ON CONFLICT (user_id, route_id)
                DO UPDATE SET
                    completion_count = user_route_completions.completion_count + 1,
                    last_completed_at = NOW()
                RETURNING completion_count, last_completed_at
                """,
                (user_id, route_id),
            )
            row = cur.fetchone()

        after_snapshot = _load_adaptive_snapshot(conn, user_id)
        update_payload = _build_preferences_update_payload(before_snapshot, after_snapshot)

        conn.commit()
        return jsonify({
            "route_id": route_id,
            "user_id": user_id,
            "completed": True,
            "completion_count": int(row[0]),
            "last_completed_at": row[1].isoformat() if row[1] else None,
            "preferences_updated": update_payload["preferences_updated"],
            "preference_update_message": update_payload["preference_update_message"],
            "effective_max_difficulty": (after_snapshot or {}).get("effective_max_difficulty"),
            "effective_preferred_distance": (after_snapshot or {}).get("effective_preferred_distance"),
        }), 200
    except Exception as e:
        conn.rollback()
        return jsonify({
            "error": f"Error intern completant ruta: {str(e)}",
        }), 500
    finally:
        conn.close()


@social_bp.get("/completed/ids")
@jwt_required()
def completed_route_ids():
    user_id = int(get_jwt_identity())

    conn = get_connection()
    try:
        _ensure_user_route_completions_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT route_id
                FROM user_route_completions
                WHERE user_id = %s
                ORDER BY last_completed_at DESC
                """,
                (user_id,),
            )
            rows = cur.fetchall()

        return jsonify([int(r[0]) for r in rows]), 200
    finally:
        conn.close()


@social_bp.get("/stats/me")
@jwt_required()
def personal_stats():
    user_id = int(get_jwt_identity())

    conn = get_connection()
    try:
        def _at(values, index, default=None):
            if values is None:
                return default
            if index < 0 or index >= len(values):
                return default
            value = values[index]
            return default if value is None else value

        _ensure_user_route_completions_table(conn)

        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COALESCE(COUNT(*), 0) AS completed_routes_unique,
                    COALESCE(SUM(urc.completion_count), 0) AS completed_routes_total,
                    COALESCE(SUM(urc.completion_count * COALESCE(r.distance_km, 0)), 0) AS total_distance_km,
                    COALESCE(SUM(urc.completion_count * COALESCE(r.elevation_gain, 0)), 0) AS total_elevation_gain_m,
                    COALESCE(
                        SUM(urc.completion_count * COALESCE(r.distance_km, 0))
                        / NULLIF(SUM(urc.completion_count), 0),
                        0
                    ) AS avg_distance_km,
                    COALESCE(
                        SUM(urc.completion_count * COALESCE(r.elevation_gain, 0))
                        / NULLIF(SUM(urc.completion_count), 0),
                        0
                    ) AS avg_elevation_gain_m,
                    MIN(urc.first_completed_at) AS first_completed_at,
                    MAX(urc.last_completed_at) AS last_completed_at,
                    COALESCE(SUM(CASE WHEN urc.last_completed_at >= NOW() - INTERVAL '30 days' THEN 1 ELSE 0 END), 0) AS active_routes_last_30d,
                    COALESCE(SUM(CASE WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%fàcil%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%facil%%' THEN urc.completion_count ELSE 0 END), 0) AS easy_count,
                    COALESCE(SUM(CASE WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%mitj%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%moder%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%media%%' THEN urc.completion_count ELSE 0 END), 0) AS medium_count,
                    COALESCE(SUM(CASE WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%molt%%' OR LOWER(COALESCE(r.difficulty, '')) LIKE '%%muy%%' THEN urc.completion_count ELSE 0 END), 0) AS very_hard_count,
                    COALESCE(SUM(CASE WHEN LOWER(COALESCE(r.difficulty, '')) LIKE '%%dif%%' AND LOWER(COALESCE(r.difficulty, '')) NOT LIKE '%%molt%%' AND LOWER(COALESCE(r.difficulty, '')) NOT LIKE '%%muy%%' THEN urc.completion_count ELSE 0 END), 0) AS hard_count
                FROM user_route_completions urc
                JOIN routes r ON r.route_id = urc.route_id
                WHERE urc.user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()

            cur.execute(
                """
                SELECT
                    fitness_level,
                    preferred_distance,
                    environment_type,
                    cultural_interest
                FROM user_preferences
                WHERE user_id = %s
                """,
                (user_id,),
            )
            pref = cur.fetchone()

            cur.execute(
                """
                SELECT r.route_id, r.name, urc.completion_count, urc.last_completed_at
                FROM user_route_completions urc
                JOIN routes r ON r.route_id = urc.route_id
                WHERE urc.user_id = %s
                ORDER BY urc.completion_count DESC, urc.last_completed_at DESC
                LIMIT 5
                """,
                (user_id,),
            )
            top_rows = cur.fetchall()

        completed_unique = int(_at(row, 0, 0) or 0)
        completed_total = int(_at(row, 1, 0) or 0)

        difficulty_counts = {
            "Fàcil": int(_at(row, 9, 0) or 0),
            "Mitjana": int(_at(row, 10, 0) or 0),
            "Difícil": int(_at(row, 12, 0) or 0),
            "Molt Difícil": int(_at(row, 11, 0) or 0),
        }

        top_difficulty = "-"
        top_count = -1
        for name, count in difficulty_counts.items():
            if count > top_count:
                top_count = count
                top_difficulty = name

        base_fitness = (_at(pref, 0, None) if pref else None) or "mitjana"
        base_distance = float(_at(pref, 1, 10.0) or 10.0)
        adaptive = _load_adaptive_snapshot(conn, user_id)

        return jsonify({
            "completed_routes_unique": completed_unique,
            "completed_routes_total": completed_total,
            "total_distance_km": round(float(_at(row, 2, 0) or 0), 2),
            "total_elevation_gain_m": int(round(float(_at(row, 3, 0) or 0))),
            "avg_distance_km": round(float(_at(row, 4, 0) or 0), 2),
            "avg_elevation_gain_m": round(float(_at(row, 5, 0) or 0), 1),
            "first_completed_at": (_at(row, 6, None).isoformat() if _at(row, 6, None) else None),
            "last_completed_at": (_at(row, 7, None).isoformat() if _at(row, 7, None) else None),
            "active_routes_last_30d": int(_at(row, 8, 0) or 0),
            "difficulty_counts": difficulty_counts,
            "top_difficulty": top_difficulty,
            "initial_preferences": {
                "fitness_level": base_fitness,
                "preferred_distance": base_distance,
                "environment_type": (_at(pref, 2, None) if pref else None),
                "cultural_interest": (_at(pref, 3, None) if pref else None),
            },
            "effective_preferences": {
                "fitness_level": adaptive.get("effective_fitness_level"),
                "max_difficulty": adaptive.get("effective_max_difficulty"),
                "preferred_distance": adaptive.get("effective_preferred_distance"),
            },
            "preferences_changed": {
                "fitness_level": (adaptive.get("effective_fitness_level") or "").lower() != (base_fitness or "").lower(),
                "preferred_distance": abs(float(adaptive.get("effective_preferred_distance") or base_distance) - float(base_distance)) >= 0.2,
            },
            "top_completed_routes": [
                {
                    "route_id": int(r[0]),
                    "name": r[1] or "",
                    "completion_count": int(r[2] or 0),
                    "last_completed_at": r[3].isoformat() if r[3] else None,
                }
                for r in top_rows
            ],
        }), 200
    except Exception as e:
        return jsonify({"error": f"Error carregant estadístiques: {str(e)}"}), 500
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
