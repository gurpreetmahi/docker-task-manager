from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import os
import redis
import json

app = Flask(__name__)
CORS(app, resources={r"/tasks*": {"origins": ["http://frontend", "http://localhost", "http://taskmanager.local"]}})
# Database connection
def get_db_connection():
    conn = psycopg2.connect(os.environ['DATABASE_URL'])
    return conn

# Redis connection
redis_client = redis.Redis.from_url(os.environ['REDIS_URL'])

# Initialize database
def init_db():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    done BOOLEAN DEFAULT FALSE
                );
            """)
            conn.commit()

init_db()

@app.route('/tasks', methods=['GET'])
def get_tasks():
    # Check Redis cache
    cached_tasks = redis_client.get('tasks')
    if cached_tasks:
        return jsonify(json.loads(cached_tasks))

    # Fetch from database if not cached
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM tasks")
            tasks = cur.fetchall()
    # Cache for 60 seconds
    redis_client.setex('tasks', 60, json.dumps(tasks))
    return jsonify(tasks)

@app.route('/tasks', methods=['POST'])
def add_task():
    new_task = request.json
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO tasks (title, done) VALUES (%s, %s) RETURNING *",
                (new_task['title'], False)
            )
            task = cur.fetchone()
            conn.commit()
    # Invalidate cache
    redis_client.delete('tasks')
    return jsonify(task), 201

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
            conn.commit()
    # Invalidate cache
    redis_client.delete('tasks')
    return '', 204

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)