import os
from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager

from routes.auth_routes import auth_bp

from routes.routes_routes import routes_bp, cultural_bp

from routes.route_files_routes import route_files_bp

from routes.routing_routes import routing_bp

from routes.route_cultural_routes import route_cultural_bp
from routes.user_preferences_routes import user_preferences_bp
from routes.social_routes import social_bp


load_dotenv()

app = Flask(__name__)


def _is_production() -> bool:
    env = (os.getenv("APP_ENV") or os.getenv("FLASK_ENV") or "development").strip().lower()
    return env in {"prod", "production"}


def _allowed_origins(is_prod: bool):
    raw = (os.getenv("ALLOWED_ORIGINS") or "").strip()
    if raw:
        origins = [origin.strip() for origin in raw.split(",") if origin.strip()]
        if origins:
            return origins

    if is_prod:
        raise RuntimeError(
            "En producción debes definir ALLOWED_ORIGINS (lista separada por comas)."
        )

    return "*"


IS_PRODUCTION = _is_production()
JWT_SECRET_KEY = (os.getenv("JWT_SECRET_KEY") or "").strip()

if IS_PRODUCTION:
    if not JWT_SECRET_KEY or len(JWT_SECRET_KEY) < 32:
        raise RuntimeError(
            "JWT_SECRET_KEY es obligatorio en producción y debe tener al menos 32 caracteres."
        )
else:
    if not JWT_SECRET_KEY:
        JWT_SECRET_KEY = "dev_only_change_me_for_local_usage"


CORS(
    app,
    resources={r"/*": {"origins": _allowed_origins(IS_PRODUCTION)}},
    supports_credentials=False,
)

app.config["JWT_SECRET_KEY"] = JWT_SECRET_KEY
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRES", "3600"))
app.config["PROPAGATE_EXCEPTIONS"] = not IS_PRODUCTION
app.config["JSON_SORT_KEYS"] = False

app.register_blueprint(route_files_bp)


jwt = JWTManager(app)


@jwt.invalid_token_loader
def invalid_token_callback(_err):
    return {"error": "Token invàlid"}, 401


@jwt.unauthorized_loader
def missing_token_callback(_err):
    return {"error": "Falta token d'autenticació"}, 401


@jwt.expired_token_loader
def expired_token_callback(_jwt_header, _jwt_payload):
    return {"error": "Token expirat"}, 401


@app.after_request
def add_security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"

    csp = (
        "default-src 'none'; "
        "frame-ancestors 'none'; "
        "base-uri 'none'; "
        "form-action 'none'"
    )
    response.headers["Content-Security-Policy"] = csp

    if IS_PRODUCTION:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    return response


@app.errorhandler(Exception)
def handle_unexpected_error(_error):
    if IS_PRODUCTION:
        return {"error": "Error intern del servidor"}, 500
    raise _error

@app.route("/")
def home():
    return {"message": "Backend funcionando!"}

app.register_blueprint(auth_bp)
app.register_blueprint(routes_bp)
app.register_blueprint(cultural_bp)
app.register_blueprint(routing_bp)
app.register_blueprint(route_cultural_bp)
app.register_blueprint(user_preferences_bp)
app.register_blueprint(social_bp)


if __name__ == "__main__":
    app.run(debug=not IS_PRODUCTION)
