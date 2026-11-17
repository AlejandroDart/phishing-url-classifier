from psycopg2.extras import Json
from database.db import database_cursor


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
    query = """
        INSERT INTO predictions (
            url, label, probability, explanation, model_id,
            sensitivity_profile, base_threshold, effective_threshold
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """

    with database_cursor() as cursor:
        cursor.execute(
            query,
            (url, label, probability, Json(explanation) if explanation else None,
             model_id, sensitivity_profile, base_threshold, effective_threshold),
        )
