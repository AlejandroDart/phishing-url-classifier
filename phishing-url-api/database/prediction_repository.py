from database.db import get_connection


def save_prediction(url, label, probability):

    connection = get_connection()
    cursor = connection.cursor()

    query = """
        INSERT INTO predictions (url, label, probability)
        VALUES (%s, %s, %s)
    """

    cursor.execute(query, (url, label, probability))

    connection.commit()

    cursor.close()
    connection.close()