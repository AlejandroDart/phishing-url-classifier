import os
from psycopg2 import pool
from dotenv import load_dotenv

load_dotenv()

db_pool = pool.ThreadedConnectionPool(
    minconn=1,
    maxconn=5,
    host=os.getenv("DB_HOST", "localhost"),
    port=os.getenv("DB_PORT", "5432"),
    user=os.getenv("DB_USER", "postgres"),
    password=os.getenv("DB_PASSWORD"),
    database=os.getenv("DB_NAME", "phishing_detector")
)


def get_connection():
    return db_pool.getconn()


def release_connection(connection):
    db_pool.putconn(connection)
