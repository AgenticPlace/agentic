# agentic

AGENTIC creation kit.
Deploys coordinator.agent.
Delivers agency.

---

# AGENTIC AI Assistant (v1.0.0)

**A web-based AI coordinator.agent leveraging the Google Agent Development Kit (ADK) for dynamic agent configuration as the answer to your question**

This project provides a decoupled frontend/backend application allowing users to interact with a pre-configured Google ADK agent and generate configurations for new agents via a strategically simple web UI agentic point of departure. Setup is automated as a single `./agentic.sh` command for streamlined deployment.

---

## Table of Contents

1.  [Introduction](#1-introduction)
2.  [Technical Explanation](#2-technical-explanation)
    *   [Architecture Overview](#architecture-overview)
    *   [System Diagram](#system-diagram)
    *   [Core Components](#core-components)
    *   [Technology Stack](#technology-stack)
3.  [Usage Guide](#3-usage-guide)
    *   [Prerequisites](#prerequisites)
    *   [Installation & Setup](#installation--setup)
    *   [Running the Application](#running-the-application)
    *   [Accessing the Application](#accessing-the-application)
    *   [Interacting with the UI](#interacting-with-the-ui)
    *   [API Endpoints](#api-endpoints)
4.  [Configuration](#4-configuration)
    *   [Backend Environment (`.env`)](#backend-environment-env)
5.  [Development & Troubleshooting](#5-development--troubleshooting)
    *   [Manual Execution](#manual-execution)
    *   [Logging](#logging)
    *   [Stopping the Application](#stopping-the-application)
    *   [Dependency Notes](#dependency-notes)
6.  [Contributing](#6-contributing)
7.  [License](#7-license)

---

## Introduction

Welcome to the AGENTIC AI augmented agency project (v1.0.0). AGENTIC serves a FastAPI backend with a Node.js frontend for building web interfaces that interact with AI agents developed using the Google Agent Development Kit (ADK).

**Key Goals:**

*   Provide a user-friendly web UI for `coordinator.agent` to answer your questions or the questions of an AI agent.
*   Utilize a backend API built with FastAPI to handle agent interactions.
*   Leverage the `google-adk` library for core agent capabilities, including tool usage (Google Search).
*   Demonstrate dynamic agent configuration file generation based on user input.
*   Offer a fully automated setup process via a Bash script (`run.sh` / `run3.sh`).

This project is ideal for developers looking to understand how to integrate Google ADK agents into a web application context or for those needing a powerfully simple, extensible AI assistant platform.

---

## Technical Explanation

This section details the system's architecture, components, and the technologies employed.

### Architecture Overview

The application follows a standard decoupled frontend-backend architecture:

*   **Frontend:** A static single-page application (SPA) built with HTML, CSS, and vanilla JavaScript. It is served by a lightweight Node.js/Express server primarily acting as a static file server. The frontend makes asynchronous API calls to the backend.
*   **Backend:** A Python-based API server built using the FastAPI framework and served via Uvicorn, housing the core business logic, including the instantiation and execution of the Google ADK `LlmAgent` and exposing RESTful endpoints for the frontend to consume.
*   **Setup Script:** A Bash script (`agentic.sh`) automates the entire process of directory creation, file generation from templates, dependency installation (Python/Node.js), and launching both servers.
*   **Agent Configuration:** Agent definitions (like the default one and dynamically created ones) rely on Python files (`agent.py`) and environment variables (`.env`) for their specific settings (model, API keys, instructions).

### System Diagram

```mermaid
graph LR
    subgraph User Interaction
        A[User Browser]
    end

    subgraph Frontend Tier (Port 3000)
        B(Node.js / Express Server) -- Serves Static Files --> A;
        A -- API Calls (Fetch) --> C;
    end

    subgraph Backend Tier (Port 8000)
        C(FastAPI / Uvicorn Server) -- Manages --> D;
        C -- Creates --> G;
        D(Default LlmAgent Instance);
        D -- Uses --> E[Google Search Tool];
        D -- Calls --> F["Google LLM API (Gemini/Vertex)"];
        G[(Agent Config Files)];
    end

    subgraph Infrastructure / Setup
        H(run.sh Script) -- Installs/Runs --> B;
        H -- Installs/Runs --> C;
        H -- Creates --> G;
    end

    A -- HTTP Request --> B;

    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#ccf,stroke:#333,stroke-width:2px
    style D fill:#9cf,stroke:#333,stroke-width:2px
    style G fill:#ff9,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5
    style H fill:#ddd,stroke:#333,stroke-width:1px
```

### Core Components

*   **`run.sh` (or variant): Orchestrator**
    *   Checks prerequisites (python3, pip, node, npm).
    *   Derives absolute paths dynamically based on its own location.
    *   Creates directory structure (`agentic/backend/utils`, `frontend`, `logs`).
    *   Generates all source files (`.py`, `.js`, `.html`, `.css`, `.json`, `.env`, `requirements.txt`) using heredocs and `printf`.
    *   Manages Python virtual environment (`adk`) creation and activation.
    *   Installs Python dependencies via `pip install -r requirements.txt`.
    *   Installs Node.js dependencies via `npm install` (or `npm ci`).
    *   Launches backend (`uvicorn`) and frontend (`node`) servers as background processes.
    *   Captures PIDs and manages graceful shutdown using `trap`.
*   **`agentic/backend/`:**
    *   `main.py`: FastAPI application definition. Defines API endpoints (`/ask`, `/create_agent`, `/health`), middleware (CORS), instantiates the default `LlmAgent`, and includes logic for creating new agent environments.
    *   `utils/config.py`: Loads environment variables from `.env` and defines configuration constants (like log directories).
    *   `utils/logger.py`: Sets up application logging (console and file output).
    *   `requirements.txt`: Lists Python dependencies. Crucially depends on `google-adk==0.1.0` and compatible versions of `fastapi`, `pydantic`, `uvicorn`.
    *   `.env`: Stores environment-specific configuration (API keys, project IDs, model names). Must be configured manually after generation.
    *   `adk/`: Python virtual environment directory created by the script.
    *   `logs/`: Directory for backend runtime logs.
    *   `predictions/`: (Defined in `config.py`, potentially for image output if used).
*   **`frontend/`:**
    *   `index.html`: The main HTML structure of the web application.
    *   `dapp.js`: Contains the client-side JavaScript logic for handling user input, making API calls to the backend (`/ask`, `/create_agent`), and updating the UI.
    *   `styled.css`: Defines the visual styling for the web application.
    *   `server.js`: A minimal Express.js server responsible for serving the static frontend files (`index.html`, `dapp.js`, `styled.css`).
    *   `package.json`: Defines frontend project metadata and dependencies (primarily `express`).
    *   `node_modules/`: Directory containing installed Node.js dependencies.

### Technology Stack

*   **Backend:**
    *   Language: Python 3
    *   Framework: FastAPI (0.104.1)
    *   ASGI Server: Uvicorn (0.24.0.post1)
    *   AI/Agent Framework: Google Agent Development Kit (`google-adk==0.1.0`)
    *   Data Validation: Pydantic (1.10.13)
    *   Environment Config: `python-dotenv`
    *   Package Management: `pip`, `venv`
*   **Frontend:**
    *   Languages: HTML5, CSS3, JavaScript (ES6+)
    *   Server: Node.js, Express.js (`^4.17.1`)
    *   Package Management: `npm`
*   **Deployment/Orchestration:**
    *   Scripting: Bash

---

## Usage Guide

This section explains how to get the application running and how to use it.

### Prerequisites

Ensure the following software is installed on your system and accessible in your `PATH`:

*   Git: For cloning the repository.
*   Python 3: Version 3.8 or higher recommended. Must include `pip`.
*   `python3-venv`: Required for creating Python virtual environments. (Installation varies by OS, e.g., `sudo apt install python3-venv` on Debian/Ubuntu).
*   Node.js: Includes `npm`. The current Long-Term Support (LTS) version is recommended.

### Installation & Setup

The setup is fully automated by the provided Bash script.

  **Clone the Repository:**
    ```bash
    git clone <your-repository-url>
    cd <repository-directory-name> # e.g., cd ag
    ```

  **Make Script Executable (If Necessary):**
    On Linux/macOS, you might need to grant execute permissions:
    ```bash
    chmod +x run3.sh # Or the final name of your script
    ```

  **Run the Setup Script:**
    Execute the script from the project's root directory:
    ```bash
    ./run3.sh # Or the final name of your script
    ```
    The script will perform all necessary steps, including:
    *   Verifying prerequisites.
    *   Creating directories (`agentic/backend`, `frontend`, `logs`).
    *   Generating source code files.
    *   Setting up the Python virtual environment (`./agentic/backend/adk`).
    *   Installing Python dependencies.
    *   Installing Node.js dependencies.

### Running the Application

The setup script automatically starts both the backend and frontend servers after installation. You should see output similar to this upon successful completion:

```
[INFO] --- AGENTIC v1.0.0 Deployed Successfully ---
[INFO] Backend running on: http://localhost:8000 (PID: <backend_pid>)
[INFO] Frontend running on: http://localhost:3000 (PID: <frontend_pid>)
[INFO] Backend logs: /path/to/your/project/agentic/backend/logs/backend_run.log
[INFO] Frontend logs: /path/to/your/project/frontend_run.log
[INFO] Press Ctrl+C to stop both servers.
[INFO] Script running in foreground, waiting for termination signal (Ctrl+C)...
```
The script will remain running in the foreground, keeping the servers alive until you stop it.

### Accessing the Application

*   **Web Interface:** Open your browser and navigate to `http://localhost:3000` (or the configured `FRONTEND_PORT`).
*   **Backend API Docs (Swagger UI):** `http://localhost:8000/docs`
*   **Backend Health Check:** `http://localhost:8000/health`

### Interacting with the UI

The web interface at `http://localhost:3000` provides two main functions:

*   **Ask the Default AI Agent:**
    1.  Locate the "Ask the Default AI Agent" section.
    2.  Type your question into the "Your Question:" input field.
    3.  Click the "Ask" button or press the Enter key.
    4.  The UI will display "Thinking..." while waiting for the backend.
    5.  The agent's response will appear in the "Answer:" paragraph below the button.
    6.  Error messages from the backend will also be displayed here.

*   **Create New Agent Configuration:**
    1.  Locate the "Create New Agent" section.
    2.  **Agent Name:** Enter a name for your new agent. Only alphanumeric characters, underscores (`_`), and hyphens (`-`) are allowed.
    3.  **LLM API:** Select the target API (e.g., `gemini`).
    4.  **Model Name:** Enter the specific model identifier (e.g., `gemini-1.5-flash-latest`).
    5.  Click the "Create Agent" button.
    6.  A status message below the button will indicate success ("Agent '...' created...") or failure ("Error: ...").
    7.  **Result:** If successful, this creates a new subdirectory within `./agentic/` on the server's filesystem containing `agent.py`, `.env`, and `__init__.py` templates for the specified agent.
        *Note: This UI action only creates the files. It does not load or run the new agent.*

### API Endpoints

While the primary interaction is through the UI, the backend exposes RESTful endpoints (documented at `/docs`):

*   `POST /ask/`: Sends a query (`{"text": "..."}`) to the default agent.
*   `POST /create_agent`: Creates a new agent's configuration files (`{"agent_name": "...", "llm_api": "...", "model_name": "..."}`).
*   `GET /health`: Returns backend status.

---

##  Configuration

### Backend Environment (`.env`)

The core backend configuration resides in `./agentic/backend/.env`. This file is generated by the setup script, but **requires manual editing** for sensitive information and GCP details.

| Variable                       | Description                                                                                                | Example                                  | Required?         |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ----------------- |
| `DEFAULT_LLM_MODEL`            | Default Google LLM model for the main agent.                                                               | `gemini-1.5-flash-latest`                | Yes (has default) |
| `GOOGLE_CLOUD_PROJECT_ID`      | Your Google Cloud Project ID.                                                                              | `your-gcp-project-id-12345`              | Yes (for GCP LLMs)|
| `GOOGLE_CLOUD_LOCATION`        | Google Cloud region for resources (e.g., Vertex AI).                                                       | `us-central1`                            | Yes (for GCP LLMs)|
| `GOOGLE_APPLICATION_CREDENTIALS` | (Set in Shell) Path to your GCP service account key file (JSON). **Do not add this line to `.env`**. Export it in your terminal: `export GOOGLE_APPLICATION_CREDENTIALS="/path/to/keyfile.json"` | `/path/to/your/keyfile.json` (Set in shell) | Yes (for GCP Auth)|
| `LOG_LEVEL`                    | (Optional) Backend logging level (DEBUG, INFO, WARNING, ERROR).                                            | `DEBUG`                                  | No (defaults to INFO) |

⚠️ **Security Warning:** Never commit service account keys or other secrets directly into your `.env` file or Git repository. Use environment variables (like `GOOGLE_APPLICATION_CREDENTIALS`) set in your shell or a dedicated secret management system for production.

---

##  Development & Troubleshooting

### Manual Execution

To run the frontend and backend servers independently for development:

*   **Backend (FastAPI/Uvicorn):**
    ```bash
    # Navigate to the backend directory
    cd agentic/backend

    # Activate the virtual environment
    source adk/bin/activate

    # Set credentials if needed (do this in your shell session)
    # export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/keyfile.json"

    # Run Uvicorn (with auto-reload)
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    ```

*   **Frontend (Node/Express):**
    ```bash
    # Navigate to the frontend directory
    cd frontend

    # Start the server
    npm start
    # OR
    # node server.js
    ```

### Logging

Runtime logs are crucial for debugging:

*   **Backend Logs:** Check the file specified during script execution (default: `./agentic/backend/logs/backend_run.log`). Uvicorn/FastAPI logs, including agent activity and errors, will appear here.
*   **Frontend Logs:** Check the file specified during script execution (default: `./frontend_run.log` in the project root). Basic Node/Express server logs (requests, startup messages, errors) will appear here. Client-side errors will appear in the browser's developer console.

Use `tail -f <log_file_path>` to monitor logs in real-time.

### Stopping the Application

*   **If started via `run.sh` / `run3.sh`:** Press `Ctrl+C` in the terminal where the script is running. The script's `trap` will attempt to stop both servers.
*   **If started manually:** Press `Ctrl+C` in each terminal where `uvicorn` and `node server.js` are running.

### Dependency Notes

*   This project currently requires `google-adk==0.1.0`. This version has strict dependencies on older versions of FastAPI (~0.104), Pydantic (v1, 1.10), and Uvicorn (0.24).
*   The `requirements.txt` generated by the script reflects these compatible versions. Attempting to upgrade FastAPI, Pydantic, or Uvicorn independently will likely break the installation due to conflicts with `google-adk`.
*   The Python code in `main.py` uses Pydantic V1 syntax (`BaseModel` without `Field`) to remain compatible.

---

## Contributing

Contributions, issues, and feature requests are welcome!

1.  Check for existing issues before creating a new one.
2.  Fork the repository.
3.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
4.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
5.  Push to the branch (`git push origin feature/AmazingFeature`).
6.  Open a Pull Request.

(Optional: Link to a more detailed `CONTRIBUTING.md` file if available)

---

## License

Distributed under the MIT License. See `LICENSE` file for more information.

(Ensure you have a `LICENSE` file in your repository if you specify one here)
