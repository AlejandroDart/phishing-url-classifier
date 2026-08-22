from psycopg2.extras import Json
from database.db import get_connection, release_connection


def save_prediction(
    url,
    label,
    probability,
    explanation=None,
    model_id="random_forest",
    sensitivity_profile="balanced",
    base_threshold=0.5,
    effective_threshold=0.5,
):
    connection = get_connection()
    cursor = connection.cursor()

    query = """
        INSERT INTO predictions (
            url, label, probability, explanation, model_id,
            sensitivity_profile, base_threshold, effective_threshold
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """

    cursor.execute(query, (url, label, probability, Json(
        explanation) if explanation else None, model_id,
        sensitivity_profile, base_threshold, effective_threshold))
    connection.commit()

    cursor.close()
    release_connection(connection)
