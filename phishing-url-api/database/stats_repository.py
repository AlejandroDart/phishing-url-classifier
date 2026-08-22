from psycopg2.extras import RealDictCursor
from database.db import get_connection, release_connection


def get_total_analysis():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT COUNT(*) FROM predictions")
    total = cursor.fetchone()[0]

    cursor.close()
    release_connection(connection)

    return total


def get_phishing_ratio():
    connection = get_connection()
    cursor = connection.cursor()

    query = """
        SELECT
            SUM(CASE WHEN label = 'phishing' THEN 1 ELSE 0 END) AS phishing,
            COUNT(*) AS total
        FROM predictions
    """

    cursor.execute(query)
    phishing, total = cursor.fetchone()

    cursor.close()
    release_connection(connection)

    if total == 0:
        return 0

    return phishing / total


def get_recent_predictions(limit=5):
    connection = get_connection()
    cursor = connection.cursor(cursor_factory=RealDictCursor)

    query = """
        SELECT url, label, probability, explanation, model_id,
               sensitivity_profile, base_threshold, effective_threshold,
               created_at
        FROM predictions
        ORDER BY created_at DESC
        LIMIT %s
    """

    cursor.execute(query, (limit,))
    results = cursor.fetchall()

    cursor.close()
    release_connection(connection)

    return results


def get_daily_activity():
    connection = get_connection()
    cursor = connection.cursor(cursor_factory=RealDictCursor)

    query = """
        SELECT
            DATE(created_at) AS date,
            COUNT(*) AS total
        FROM predictions
        GROUP BY DATE(created_at)
        ORDER BY date DESC
        LIMIT 7
    """

    cursor.execute(query)
    results = cursor.fetchall()

    cursor.close()
    release_connection(connection)

    return results
