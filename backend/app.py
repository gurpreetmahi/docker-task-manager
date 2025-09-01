from flask import Flask , jsonify, request 
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

tasks  = [
    { "id":1, "title": "Sample task", "done":False}
]

@app.route('/tasks', methods=['GET'])
def get_tasks():
    return jsonify(tasks)

@app.route('/tasks',methods=['POST'])
def add_task():
    new_task = request.json
    new_task['id'] = len(tasks) + 1
    new_task['done'] = False
    tasks.append(new_task)
    return jsonify(new_task), 201

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    global tasks
    tasks = [t for t in tasks if t['id'] != task_id]
    return '', 204

if __name__ == '__main__':
    app.run(debug=True, port=5000)