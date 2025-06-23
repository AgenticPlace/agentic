# AGENTIC: AI Agent Creation and Interaction Platform (with mindXalpha Integration)

## Overview

AGENTIC is a platform designed for the dynamic creation, management, and interaction with AI agents. It provides a backend API and a frontend UI to facilitate these processes. A key feature of AGENTIC is its integration with the mindXalpha project, an experimental AI system focused on autonomous self-improvement. This integration allows users to not only create standard AI agents but also to interact with the mindX system to trigger complex evolutionary and strategic tasks.

The AGENTIC system, through its `agentic.sh` deployment script, sets up a complete environment including a FastAPI backend, a Node.js/Express frontend, and prepares for interaction with a separately managed mindXalpha instance.

## Core Components

*   **AGENTIC Backend (FastAPI & Google ADK):**
    *   Built with Python and FastAPI.
    *   Utilizes the Google Agent Development Kit (ADK) for LLM agent functionalities.
    *   Provides API endpoints for:
        *   Creating new agent configurations (`/create_agent`).
        *   Interacting with a default question-answering agent (`/ask/`).
        *   Interacting with the mindX MastermindAgent (`/mindx/evolve/`).
    *   Manages agent-specific environments and configurations.

*   **AGENTIC Frontend (Node.js & Express):**
    *   A simple web interface built with HTML, CSS, and JavaScript.
    *   Served by a Node.js/Express backend.
    *   Allows users to:
        *   Request the creation of new agents.
        *   Ask questions to the default AI agent.
        *   Submit directives to the integrated mindX system.

*   **mindXalpha Integration:**
    *   AGENTIC is designed to work alongside a mindXalpha deployment.
    *   The backend's `main.py` includes logic to import and initialize components from a `mindX` directory (assumed to be a sibling to the `agentic` directory within the project root).
    *   Enables AGENTIC to act as a control/interaction point for mindX's `MastermindAgent`, allowing users to submit high-level directives for mindX to process.
    *   mindXalpha itself is a sophisticated system aiming for self-improvement, featuring agents like:
        *   `MastermindAgent`: Manages high-level campaigns and evolution.
        *   `CoordinatorAgent`: Orchestrates system operations and improvement tasks.
        *   `SelfImprovementAgent`: Performs tactical code modifications.

## Features

*   **Dynamic Agent Creation:** Generate configuration files and directory structures for new AI agents via a simple API call or UI interaction.
*   **Default QA Agent:** Interact with a pre-configured Google ADK-based LlmAgent for general question answering.
*   **mindXalpha Interaction:** Submit directives to the powerful mindXalpha `MastermindAgent` to trigger its evolutionary and self-improvement capabilities.
*   **Modular Architecture:** Clearly separated backend, frontend, and the external mindXalpha system.
*   **Automated Setup:** The `agentic.sh` script automates the creation of necessary files, installation of dependencies for both backend and frontend, and setup for mindXalpha Python environment.
*   **Environment Configuration:** Uses `.env` files for managing API keys and other sensitive configurations for the backend and individual agents, with `mindx_config.json` available for mindXalpha specific settings.

## Technology Stack

*   **Backend:** Python, FastAPI, Google Agent Development Kit (ADK), Uvicorn
*   **Frontend:** Node.js, Express, HTML, CSS, JavaScript
*   **mindXalpha (External):** Python, asyncio, various LLM SDKs (Ollama, Gemini)
*   **Deployment Script:** Bash Shell
*   **LLM Support:** Primarily Google Gemini (via ADK and direct use in mindXalpha), Ollama (for local models in mindXalpha)

## Setup and Installation

1.  **Prerequisites:**
    *   Python 3.9+ and pip
    *   Node.js and npm
    *   Git (to clone the repository if not already present)
    *   Access to LLMs:
        *   For the default AGENTIC QA agent: Google Cloud Project ID and potentially `GOOGLE_APPLICATION_CREDENTIALS` configured for Google ADK.
        *   For mindXalpha:
            *   Ollama installed and models pulled (e.g., `ollama pull deepseek-coder:6.7b-instruct`, `ollama pull nous-hermes2:latest`).
            *   OR Google Gemini API Key.

2.  **Clone the Repository (if applicable):**
    ```bash
    git clone https://github.com/AgenticPlace/agentic
    cd agentic
    ```

3.  **Place mindXalpha Project:**
    *   Ensure the `mindX` project directory (containing the mindXalpha codebase) is present in the root of the AGENTIC project directory, alongside the `agentic.sh` script. The backend expects to find `mindX` at `../mindX` relative to its own `main.py` or via PYTHONPATH adjustments made by `agentic.sh`.

4.  **Make `agentic.sh` Executable:**
    ```bash
    chmod +x agentic.sh
    ```

5.  **Run the Setup Script:**
    ```bash
    ./agentic.sh
    ```
    This script will:
    *   Create necessary directories (`agentic/backend/utils`, `agentic/backend/logs`, `frontend/`, `agentic/agentic_venv/`, `mindX/mindx_venv/`).
    *   Generate initial configuration files for the backend (e.g., `.env`, `main.py`, `utils/config.py`, `utils/logger.py`, `requirements.txt`).
    *   Generate initial files for the frontend (e.g., `index.html`, `dapp.js`, `styled.css`, `server.js`, `package.json`).
    *   Install Python dependencies for the backend into a virtual environment (`agentic/backend/adk/`).
    *   Install Node.js dependencies for the frontend (`cd frontend && npm install`).
    *   Install Python dependencies for mindXalpha into its virtual environment (`mindX/mindx_venv/`).

6.  **Configure Environment Variables:**
    *   **AGENTIC Backend:** Edit `agentic/backend/.env` to set:
        *   `DEFAULT_LLM_MODEL` (e.g., `gemini-1.5-flash-latest`)
        *   `GOOGLE_CLOUD_PROJECT_ID`
        *   `GOOGLE_CLOUD_LOCATION`
        *   Optionally, `GOOGLE_APPLICATION_CREDENTIALS` (path to your service account key file).
        *   `LOG_LEVEL` (e.g., `INFO` or `DEBUG`)
    *   **mindXalpha:** Configure mindXalpha according to its own `README.md` and `.env` (typically within the `mindX` directory), especially for LLM API keys (`MINDX_LLM__GEMINI__API_KEY`, Ollama settings, etc.). The `agentic.sh` script *does not* create the `mindX/.env` file; this should be part of the mindXalpha project itself.

## Running the Application

The `agentic.sh` script, after setup, also starts the backend and frontend servers.

*   **Backend Server:**
    *   Started by `uvicorn main:app --host 0.0.0.0 --port 8000 --reload`.
    *   Accessible at `http://localhost:8000`.
    *   API documentation (Swagger UI) available at `http://localhost:8000/docs`.
    *   Logs are typically found in `agentic/backend/logs/backend_run.log`.

*   **Frontend Server:**
    *   Started by `node server.js` from the `frontend` directory.
    *   Accessible at `http://localhost:3000` (by default, configurable via `FRONTEND_PORT` in `agentic.sh`).
    *   Logs are typically found in `frontend_run.log` in the project root.

If you stop the `agentic.sh` script (e.g., with Ctrl+C), it will attempt to stop both servers. You can also run them manually if needed by activating their respective environments and running the server commands.

## Usage

1.  **Access the Frontend:** Open your web browser and navigate to `http://localhost:3000`.

2.  **Create New Agent:**
    *   In the "Create New Agent" section:
        *   Enter an **Agent Name** (alphanumeric, underscores, hyphens).
        *   Select the **LLM API** (e.g., "gemini").
        *   Enter the **Model Name** (e.g., "gemini-1.5-flash-latest").
    *   Click "Create Agent".
    *   This will create a new directory under `agentic/<agent_name>/` with `agent.py`, `.env`, and `__init__.py` files on the backend server. *Note: This only creates configuration files; it does not automatically run or make the new agent API-accessible.*

3.  **Ask the Default AI Agent:**
    *   In the "Ask the Default AI Agent" section:
        *   Type your question in the input field.
    *   Click "Ask".
    *   The answer from the backend's default ADK-based LlmAgent will be displayed.

4.  **Interact with mindX (via Mastermind):**
    *   Ensure your mindXalpha instance is configured and its components are accessible to the AGENTIC backend (Python environment and paths).
    *   In the "Interact with mindX" section:
        *   Enter a high-level **Directive for mindX** in the textarea.
    *   Click "Evolve mindX".
    *   The AGENTIC backend will forward this directive to the `MastermindAgent` instance of mindXalpha.
    *   The response from mindX (indicating the status and details of its evolution campaign) will be displayed.

## Project Structure (Simplified - Post `agentic.sh` execution)

```
.
├── agentic.sh                 # Main deployment and run script
├── agentic/                   # AGENTIC application core
│   ├── backend/               # FastAPI backend
│   │   ├── adk/               # Python virtual environment for backend
│   │   ├── .env               # Backend environment configuration
│   │   ├── main.py            # FastAPI application
│   │   ├── requirements.txt   # Backend Python dependencies
│   │   ├── utils/             # Utility modules (config, logger)
│   │   └── logs/              # Backend logs
│   ├── frontend/              # Node.js/Express frontend (copied here by script, actually runs from ./frontend)
│   └── <agent_name>/          # Directory for a dynamically created agent
│       ├── .env
│       ├── agent.py
│       └── __init__.py
├── frontend/                  # Source and runtime directory for the frontend UI
│   ├── node_modules/          # Node.js dependencies
│   ├── dapp.js                # Frontend JavaScript logic
│   ├── index.html             # Main HTML page
│   ├── package.json           # Frontend npm package definition
│   ├── server.js              # Express server for frontend
│   └── styled.css             # CSS styles
├── mindX/                     # mindXalpha project directory (expected to be co-located)
│   ├── mindx_venv/            # Python virtual environment for mindX
│   ├── ... (mindXalpha's own structure: core, orchestration, learning, etc.)
│   └── requirements.txt       # mindX Python dependencies
├── backend_run.log            # Log file for backend server (if started by script and not logging to agentic/backend/logs)
├── frontend_run.log           # Log file for frontend server
└── README.md                  # This file
```

## mindXalpha Details

mindXalpha is an ambitious project aiming to create an AI system that can autonomously improve its own codebase and capabilities. It is inspired by concepts like the Darwin-Gödel Machine.

*   **Goal:** Self-improving autonomous and adaptive AI.
*   **Key Agents:**
    *   `MastermindAgent`: Oversees long-term strategic goals and evolution campaigns.
    *   `CoordinatorAgent`: Manages system-wide operations, analyzes the system for improvement opportunities, and delegates tasks.
    *   `SelfImprovementAgent (SIA)`: A specialized agent that performs tactical code modifications on specific files, including safety checks and self-testing.
*   **Process:** mindXalpha analyzes its codebase, identifies areas for enhancement, uses LLMs to generate solutions, and applies these improvements, aiming for safe and verifiable evolution.

For more details on mindXalpha, please refer to its own documentation within the `mindX/` directory.

## Contributing

Contributions are welcome! Please follow standard coding practices, and consider discussing significant changes via issues before submitting pull requests. (Further details to be added).

## License

This project is licensed under the Apache License 2.0. See the LICENSE file for details (to be created - assuming Apache 2.0 based on mindXalpha).
```
