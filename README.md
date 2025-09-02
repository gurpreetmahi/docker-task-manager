# Summary of Steps for Docker Task Manager Project

This document summarizes the steps taken to develop and enhance a containerized task management application, demonstrating Docker skills for a GitHub portfolio. The app consists of a frontend (Nginx), backend (Flask), and PostgreSQL database, with a CI/CD pipeline for multi-architecture support.

## Step 1: Initial Project Setup
- **Objective**: Set up a basic task management app with a frontend and backend.
- **Actions**:
  - Created project directory: `docker-task-manager`.
  - Set up frontend (`frontend/`):
    - HTML/JavaScript UI for task management.
    - Served via Nginx (`frontend/Dockerfile`).
  - Set up backend (`backend/`):
    - Flask API with in-memory task storage (`app.py`).
    - Dependencies: `flask`, `flask-cors` (`requirements.txt`).
    - `backend/Dockerfile` using `python:3.10-slim`.
  - Created `README.md` with basic setup instructions.
- **Outcome**: Functional app with in-memory tasks, accessible locally.

## Step 2: Containerize with Docker Compose
- **Objective**: Containerize frontend and backend using Docker Compose.
- **Actions**:
  - Created `docker-compose.yml` with:
    - `frontend` service (Nginx, port `80:80`).
    - `backend` service (Flask, port `5000:5000`).
    - Shared `app-network` (bridge network).
  - Configured frontend to use `http://backend:5000/tasks` for API calls.
  - Added CORS in `backend/app.py` (`CORS(app, resources={r"/tasks*": {"origins": "*"}})`).
- **Issue**: Frontend couldn’t connect to `http://backend:5000`.
- **Workaround**: Changed `frontend/index.html` to use `http://localhost:5000/tasks`, leveraging host port mapping.
- **Outcome**: App runs with `docker-compose up --build`, accessible at `http://localhost`.

## Step 3: Fix Networking Issues
- **Objective**: Troubleshoot why `http://backend:5000` fails from frontend container.
- **Actions**:
  - Verified `app-network` in `docker-compose.yml`.
  - Added health checks:
    - Backend: `test: ["CMD", "curl", "-f", "http://localhost:5000/tasks"]`.
    - Ensured `curl` in `backend/Dockerfile`.
  - Tested connectivity from frontend container:
    ```
    docker exec -it <frontend-container> sh
    apk add curl
    curl http://backend:5000/tasks
    ```
  - Kept `http://localhost:5000/tasks` workaround due to persistent networking issues.
- **Outcome**: Confirmed `http://localhost:5000` works; deferred `http://backend:5000` fix.

## Step 4: Add PostgreSQL Database
- **Objective**: Replace in-memory storage with PostgreSQL for persistent tasks.
- **Actions**:
  - Updated `docker-compose.yml`:
    - Added `db` service (`postgres:15-alpine`).
    - Added `db-data` volume for persistence.
    - Set `DATABASE_URL=postgresql://user:password@db:5432/taskdb`.
    - Added health check: `test: ["CMD-SHELL", "pg_isready -U user -d taskdb"]`.
  - Updated `backend/requirements.txt`: Added `psycopg2-binary`.
  - Updated `backend/app.py`:
    - Added database connection using `psycopg2`.
    - Created `tasks` table with `id`, `title`, `done` columns.
    - Modified API endpoints to use PostgreSQL.
  - Updated `backend/Dockerfile`: Added `postgresql-client` for `psql`.
  - Fixed `psql` error (`role "root" does not exist`):
    - Used `psql "postgresql://user:password@db:5432/taskdb" -c "SELECT * FROM tasks;"`.
- **Outcome**: Tasks persist across container restarts, accessible at `http://localhost`.

## Step 5: Resolve Architecture Issues
- **Objective**: Fix `no matching manifest for linux/arm64/v8` error on ARM64 system (macOS M1/M2).
- **Actions**:
  - Identified issue with `postgres:15` lacking ARM64 support.
  - Switched to `postgres:15-alpine` in `docker-compose.yml`.
  - Fixed `platform` error (`Additional property platform is not allowed`):
    - Moved `platform: linux/arm64` to service level in `docker-compose.yml`.
  - Removed `platform` fields locally to use host’s native architecture (`arm64`).
- **Outcome**: Local builds work on ARM64 system.

## Step 6: Set Up CI/CD Pipeline
- **Objective**: Automate building and pushing multi-arch Docker images.
- **Actions**:
  - Created `.github/workflows/docker.yml`:
    - Triggers on push to `main`.
    - Uses `docker/setup-qemu-action` and `docker/setup-buildx-action`.
    - Builds/pushes `backend` and `frontend` images for `linux/amd64,linux/arm64`.
    - Tags: `yourusername/task-manager-backend:latest`, `yourusername/task-manager-frontend:latest`.
  - Added Docker Hub secrets (`DOCKER_USERNAME`, `DOCKER_PASSWORD`) in GitHub.
  - Tested workflow and verified images on Docker Hub.
- **Outcome**: Multi-arch images pushed to Docker Hub on each `main` push.

## Step 7: Support Both ARM64 and AMD64
- **Objective**: Ensure app supports `arm64` and `amd64` architectures.
- **Actions**:
  - Confirmed base images support both architectures:
    - `python:3.10-slim`, `nginx:alpine`, `postgres:15-alpine`.
  - Updated CI/CD workflow to build multi-arch images (`linux/amd64,linux/arm64`).
  - Tested locally on ARM64:
    - Pulled multi-arch images from Docker Hub.
    - Ran `docker-compose up` with `image` instead of `build`.
  - Noted `http://localhost:5000/tasks` workaround for frontend.
- **Outcome**: App runs on ARM64 locally; CI/CD produces images for both architectures.

## Step 8: Update Documentation
- **Objective**: Keep `README.md` current with setup and troubleshooting.
- **Actions**:
  - Updated `README.md` with:
    - Architecture, setup instructions, CI/CD details.
    - Troubleshooting for frontend, database, and architecture issues.
    - Multi-arch support notes (`amd64`, `arm64`).
  - Committed changes after each step:
    ```
    git add .
    git commit -m "Updated project with [step description]"
    git push origin main
    ```
- **Outcome**: Comprehensive documentation for portfolio.

## Current Status
- **Application**: Fully containerized with Nginx frontend, Flask backend, and PostgreSQL database.
- **Frontend**: Uses `http://localhost:5000/tasks` (workaround for `http://backend:5000` issue).
- **Database**: Persistent via `db-data` volume.
- **CI/CD**: Pushes multi-arch images to Docker Hub.
- **Architectures**: Supports `linux/arm64` (local) and `linux/amd64` (via CI/CD).

## Next Steps
- **Fix Networking**: Resolve `http://backend:5000` for fully containerized frontend.
- **Enhance Features**: Add Redis caching, tests, or improved UI.
- **Deploy**: Deploy to a cloud provider (e.g., AWS, Heroku).
- **Polish**: Add demo video or unit tests for portfolio.
