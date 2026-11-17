from flask import Blueprint, current_app, jsonify
from psycopg2 import Error
from psycopg2.pool import PoolError

from database.stats_repository import (
    get_total_analysis,
    get_phishing_ratio,
    get_recent_predictions,
    get_daily_activity
)

stats_bp = Blueprint("stats", __name__)


@stats_bp.errorhandler(Error)
@stats_bp.errorhandler(PoolError)
def stats_unavailable(error):
    current_app.logger.warning("Statistics unavailable: %s", type(error).__name__)
    return jsonify({"error": "Estadísticas globales temporalmente no disponibles"}), 503


@stats_bp.route("/stats/count", methods=["GET"])
def stats_count():

    total = get_total_analysis()

    return jsonify({
        "total_analysis": total
    })


@stats_bp.route("/stats/phishing-ratio", methods=["GET"])
def stats_ratio():

    ratio = get_phishing_ratio()

    return jsonify({
        "phishing_ratio": round(ratio, 4)
    })


@stats_bp.route("/stats/recent", methods=["GET"])
def stats_recent():

    results = get_recent_predictions()

    return jsonify(results)


@stats_bp.route("/stats/daily", methods=["GET"])
def stats_daily():

    results = get_daily_activity()

    return jsonify(results)
