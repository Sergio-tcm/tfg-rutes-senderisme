import os
from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager

from routes.auth_routes import auth_bp

from routes.routes_routes import routes_bp, cultural_bp

from routes.route_files_routes import route_files_bp


load_dotenv()

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

app.config["JWT_SECRET_KEY"] = os.getenv("JWT_SECRET_KEY", "dev_secret_change_me")
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = 60 * 60  # 1 hora (en segundos)

app.register_blueprint(route_files_bp)


jwt = JWTManager(app)

@app.route("/")
def home():
    return {"message": "Backend funcionando!"}

app.register_blueprint(auth_bp)
app.register_blueprint(routes_bp)
app.register_blueprint(cultural_bp)


if __name__ == "__main__":
    app.run(debug=True)
