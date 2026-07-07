import os
import platform
from datetime import datetime, timezone
from flask import Flask, jsonify

app = Flask(__name__)

# Read version from environment — injected at Docker build time via ARG/ENV.
# Falls back to "dev" when running without Docker.
APP_VERSION = os.environ.get("APP_VERSION", "dev")


@app.route("/")
def index():
    return jsonify(
        message="Hello from Flask in Docker!",
        version=APP_VERSION,
    )


@app.route("/health")
def health():
    return jsonify(status="ok", version=APP_VERSION), 200


@app.route("/version")
def version():
    return jsonify(version=APP_VERSION)


@app.route("/info")
def info():
    return jsonify(
        version=APP_VERSION,
        python=platform.python_version(),
        server=os.uname().nodename if hasattr(os, "uname") else "unknown",
        uptime_utc=datetime.now(timezone.utc).isoformat(),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

#just test changes in this file
