import mysql.connector
from mysql.connector.pooling import MySQLConnectionPool

db_config = {
    "host": "localhost",
    "user": "root",
    "password": "",
    "database": "phishing_detector"
}

pool = MySQLConnectionPool(
    pool_name="phishing_pool",
    pool_size=5,
    **db_config
)


def get_connection():
    return pool.get_connection()