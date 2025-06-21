```txt
 chmod +x agentic.sh
(base) codephreak@codephreak-EX58-UD3R:~/AGENTIC$ ./agentic.sh
[INFO] Project Root detected as: /home/codephreak/AGENTIC
[INFO] Absolute Backend Dir: /home/codephreak/AGENTIC/./agentic/backend
[INFO] Absolute Frontend Dir: /home/codephreak/AGENTIC/./frontend
[INFO] Starting AGENTIC v1.0.0 deployment as AUGMENTIC...
[INFO] Setting up AGENTIC backend environment (files)...
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/.env
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/__init__.py
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/utils/__init__.py
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/utils/config.py
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/utils/logger.py
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/main.py
[INFO] Creating/Overwriting file: /home/codephreak/AGENTIC/./agentic/backend/requirements.txt
[INFO] AGENTIC backend files created.
[INFO] Installing AGENTIC backend dependencies...
[INFO] Creating virtual environment 'adk'...
[INFO] Virtual environment created.
[INFO] Upgrading pip...
[INFO] Virtual environment 'adk' activated.
[INFO] Installing dependencies from requirements.txt...
[INFO] AGENTIC backend dependencies installed successfully.
[INFO] Virtual environment deactivated.
[INFO] Setting up frontend environment (files and dependencies)...
[INFO] Creating file: /home/codephreak/AGENTIC/./frontend/index.html
[INFO] Creating file: /home/codephreak/AGENTIC/./frontend/dapp.js
[INFO] Creating file: /home/codephreak/AGENTIC/./frontend/styled.css
[INFO] Creating file: /home/codephreak/AGENTIC/./frontend/server.js
[INFO] Creating file: /home/codephreak/AGENTIC/./frontend/package.json
[INFO] Frontend files created in /home/codephreak/AGENTIC/./frontend.
[INFO] Installing frontend dependencies (npm)...
[INFO] Running 'npm install' in /home/codephreak/AGENTIC/frontend...
[INFO] Frontend dependencies installed successfully.
[INFO] Starting AGENTIC backend (FastAPI) on http://localhost:8000...
[INFO] Activating backend virtual environment 'adk'...
[INFO] Starting uvicorn server in the background...
[INFO] Redirecting backend stdout/stderr to logs/backend_run.log
[INFO] Backend process started with PID: 56851
[INFO] Virtual environment deactivated (backend process continues).
[INFO] Starting AGENTIC frontend (Node.js) server on http://localhost:3000...
[INFO] Starting Node.js server (server.js) in the background...
[INFO] Redirecting frontend stdout/stderr to /home/codephreak/AGENTIC/frontend_run.log
[INFO] Frontend process started with PID: 56857
[INFO] --- AGENTIC v1.0.0 Deployed Successfully ---
[INFO] Backend running on: http://localhost:8000 (PID: 56851)
[INFO] Frontend running on: http://localhost:3000 (PID: 56857)
[INFO] Backend logs: /home/codephreak/AGENTIC/./agentic/backend/logs/backend_run.log
[INFO] Frontend logs: /home/codephreak/AGENTIC/frontend_run.log
[INFO] Press Ctrl+C to stop both servers.
[INFO] Script running in foreground, waiting for termination signal (Ctrl+C)...
```
