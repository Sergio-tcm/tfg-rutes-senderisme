from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from db import get_connection

user_preferences_bp = Blueprint("user_preferences", __name__, url_prefix="/user-preferences")


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
            "effective_preferred_elevation_gain": None,
            "adaptive_learning_weight": 0.0,
            "total_completed_routes": 0,
        }

    learned_weight = min(0.4, (total_completions / 10.0) * 0.4)
    base_weight = 1.0 - learned_weight

    base_rank = float(_fitness_to_rank(base_fitness))
    learned_rank = float(learning.get("avg_difficulty_rank") or 0.0)
    effective_rank = (base_rank * base_weight) + (learned_rank * learned_weight)
    effective_rank_int = int(round(max(0.0, min(2.0, effective_rank))))

    learned_distance = float(learning.get("avg_distance_km") or base_distance)
    effective_distance = (float(base_distance) * base_weight) + (learned_distance * learned_weight)

    learned_elevation = learning.get("avg_elevation_gain")
    effective_elevation = float(learned_elevation) if learned_elevation is not None else None

    return {
        "effective_fitness_level": _rank_to_fitness(effective_rank_int),
        "effective_max_difficulty": _rank_to_max_difficulty(effective_rank_int),
        "effective_preferred_distance": round(max(1.0, effective_distance), 2),
        "effective_preferred_elevation_gain": round(effective_elevation, 1) if effective_elevation is not None else None,
        "adaptive_learning_weight": round(learned_weight, 3),
        "total_completed_routes": total_completions,
    }


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
        _ensure_user_route_completions_table(conn)
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
                        SUM(urc.completion_count * COALESCE(r.elevation_gain, 0))
                        / NULLIF(SUM(urc.completion_count), 0),
                        0
                    ) AS avg_elevation_gain,
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
            learning_row = cur.fetchone()

        if row is None:
            return jsonify({}), 200

        base_fitness = row[2] or "baixa"
        base_distance = float(row[3]) if row[3] is not None else 10.0
        learning = {
            "total_completions": int(learning_row[0] or 0),
            "avg_distance_km": float(learning_row[1] or 0),
            "avg_elevation_gain": float(learning_row[2] or 0),
            "avg_difficulty_rank": float(learning_row[3] or 0),
        }
        adaptive = _compute_adaptive_signals(base_fitness, base_distance, learning)

        return jsonify({
            "pref_id": row[0],
            "user_id": row[1],
            "fitness_level": row[2],
            "preferred_distance": float(row[3]) if row[3] is not None else None,
            "environment_type": row[4],
            "cultural_interest": row[5],
            "updated_at": row[6].isoformat() if row[6] else None,
            "effective_fitness_level": adaptive["effective_fitness_level"],
            "effective_max_difficulty": adaptive["effective_max_difficulty"],
            "effective_preferred_distance": adaptive["effective_preferred_distance"],
            "effective_preferred_elevation_gain": adaptive["effective_preferred_elevation_gain"],
            "adaptive_learning_weight": adaptive["adaptive_learning_weight"],
            "total_completed_routes": adaptive["total_completed_routes"],
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
