from flask import Flask
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Permite peticiones desde Flutter

@app.route('/')
def home():
    return {'message': 'Backend funcionando!'}

if __name__ == '__main__':
    app.run(debug=True)
