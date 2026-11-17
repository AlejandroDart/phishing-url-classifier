import os
import threading
from contextlib import contextmanager

from dotenv import load_dotenv
from psycopg2 import pool

load_dotenv()

_db_pool = None
_pool_lock = threading.Lock()


def _get_pool():
    global _db_pool

    with _pool_lock:
        if _db_pool is None:
            _db_pool = pool.ThreadedConnectionPool(
                minconn=1,
                maxconn=5,
                host=os.getenv("DB_HOST", "localhost"),
                port=os.getenv("DB_PORT", "5432"),
                user=os.getenv("DB_USER", "postgres"),
                password=os.getenv("DB_PASSWORD"),
                database=os.getenv("DB_NAME", "phishing_detector"),
                connect_timeout=5,
            )
        return _db_pool


def get_connection():
    return _get_pool().getconn()


def release_connection(connection):
    _get_pool().putconn(connection)


@contextmanager
def database_cursor(**kwargs):
    connection = get_connection()
    try:
        with connection, connection.cursor(**kwargs) as cursor:
            yield cursor
    finally:
        release_connection(connection)
