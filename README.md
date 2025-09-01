# Docker Task Manager

A containerized task management app demonstrating Docker skills.

## Architecture
- Frontend: Simple web interface
- Backend: Python Flask API
- Database: PostgreSQL (to be added)

## Setup
### Prerequisites
- Docker installed
- Git

### Running the Backend
1. Navigate to `backend/`.
2. Build the Docker image:
   ```bash
   docker build -t task-manager-backend:latest .
   docker run -p 5000:5000 task-manager-backend:latest