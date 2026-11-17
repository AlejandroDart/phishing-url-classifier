from psycopg2.extras import RealDictCursor
from database.db import database_cursor


def get_total_analysis():
    with database_cursor() as cursor:
        cursor.execute("SELECT COUNT(*) FROM predictions")
        return cursor.fetchone()[0]


def get_phishing_ratio():
    query = """
        SELECT
            SUM(CASE WHEN label = 'phishing' THEN 1 ELSE 0 END) AS phishing,
            COUNT(*) AS total
        FROM predictions
    """

    with database_cursor() as cursor:
        cursor.execute(query)
        phishing, total = cursor.fetchone()

    if total == 0:
        return 0

    return phishing / total


def get_recent_predictions(limit=5):
    query = """
        SELECT url, label, probability, explanation, model_id,
               sensitivity_profile, base_threshold, effective_threshold,
               created_at
        FROM predictions
        ORDER BY created_at DESC
        LIMIT %s
    """

    with database_cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(query, (limit,))
        return cursor.fetchall()


def get_daily_activity():
    query = """
        SELECT
            DATE(created_at) AS date,
            COUNT(*) AS total
        FROM predictions
        GROUP BY DATE(created_at)
        ORDER BY date DESC
        LIMIT 7
    """

    with database_cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(query)
        return cursor.fetchall()
