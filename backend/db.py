import psycopg2

def get_connection():
    return psycopg2.connect(
        host="localhost",
        database="tfg_senderisme",
        user="postgres",
        password="1234"
    )
