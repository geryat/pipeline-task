# v1.0.0 - major release

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        status="success",
        version="1.0.0",
        data={"message": "Hello from Flask in Docker!"}
    )


@app.route("/health")
def health():
    return jsonify(status="ok"), 200


@app.route("/version")
def version():
    return jsonify(version="1.0.0"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
