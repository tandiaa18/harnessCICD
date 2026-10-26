from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.get("/")
def index():
    return jsonify(
        service="harness-gcp-demo",
        status="ok",
        message="Hello from Python on GKE",
        revision=os.getenv("APP_REVISION", "local"),
    )

@app.get("/healthz")
def healthz():
    return jsonify(status="healthy"), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
