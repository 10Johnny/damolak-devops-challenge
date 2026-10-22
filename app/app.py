
import os

from flask import Flask, jsonify


def create_app():
    app = Flask(__name__)

    app.config["APP_MODE"] = os.getenv("APP_MODE", "development")

    @app.get("/")
    def home():
        return jsonify(
            message="Damolak DevOps Challenge API",
            status="running",
            mode=app.config["APP_MODE"],
        ), 200

    @app.get("/health")
    def health():
        return jsonify(status="healthy"), 200

    return app


app = create_app()
