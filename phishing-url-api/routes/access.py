from hmac import compare_digest

from flask import current_app, jsonify, request


def require_api_key():
    if request.method == "OPTIONS":
        return None

    expected = current_app.config["API_KEY"]
    supplied = request.headers.get("X-API-KEY", "")
    if not expected or not compare_digest(
        expected.encode("utf-8"), supplied.encode("utf-8")
    ):
        return jsonify({"error": "Acceso no autorizado"}), 403

    return None
