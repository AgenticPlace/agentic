#!/bin/bash

# install AGENTIC v1.0.0 as AUGMENTIC

# --- Configuration ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT="$SCRIPT_DIR"

# --- Helper Functions ---
function log_info { echo "[INFO] $1"; }
function log_error { echo "[ERROR] $1" >&2; }

# --- Continue Configuration ---
log_info "Project Root detected as: $PROJECT_ROOT"
AGENTIC_DIR="agentic"
BACKEND_DIR="$AGENTIC_DIR/backend"
UTILS_DIR="$BACKEND_DIR/utils"
FRONTEND_DIR="frontend"
BACKEND_VENV_NAME="adk"
FRONTEND_PORT=3000
BACKEND_PORT=8000
ABS_BACKEND_DIR="$PROJECT_ROOT/$BACKEND_DIR"
ABS_FRONTEND_DIR="$PROJECT_ROOT/$FRONTEND_DIR"
log_info "Absolute Backend Dir: $ABS_BACKEND_DIR"
log_info "Absolute Frontend Dir: $ABS_FRONTEND_DIR"

# --- Helper Functions (Continued) ---
function check_command {
  if ! command -v "$1" &> /dev/null; then
    log_error "$1 is not installed."
    exit 1
  fi
}

function create_or_overwrite_file_heredoc {
    local file_path="$1"
    local content="$2"
    local dir_path=$(dirname "$file_path")
    local abs_dir_path
    if [[ "$dir_path" == /* ]]; then abs_dir_path="$dir_path"; else abs_dir_path="$PROJECT_ROOT/$dir_path"; fi
    mkdir -p "$abs_dir_path" || { log_error "Failed to create directory: $abs_dir_path"; exit 1; }
    local abs_file_path
    if [[ "$file_path" == /* ]]; then abs_file_path="$file_path"; else abs_file_path="$PROJECT_ROOT/$file_path"; fi
    printf '%s\n' "$content" > "$abs_file_path" || { log_error "Failed to write to file: $abs_file_path"; exit 1; }
    log_info "Creating/Overwriting file: $abs_file_path"
}

function setup_environment_config {
  log_info "Checking for existing configuration..."
  local env_file="$ABS_BACKEND_DIR/.env"
  if [ -f "$env_file" ]; then
    log_info "Existing .env file found at $env_file. Skipping interactive setup."
  else
    log_info "Backend .env file not found. Starting interactive setup..."
    echo "------------------------------------------------------------"
    read -p "Enter your Google Gemini API Key: " gemini_api_key
    read -p "Enter your Google Cloud Project ID: " gcloud_project_id
    read -r -d '' env_content << EOF
# .env file for AGENTIC backend
GOOGLE_API_KEY=${gemini_api_key}
GOOGLE_CLOUD_PROJECT_ID=${gcloud_project_id:-your-project-id}
GOOGLE_CLOUD_LOCATION=us-central1
DEFAULT_LLM_MODEL=gemini-1.5-flash-latest
EOF
    create_or_overwrite_file_heredoc "$env_file" "$env_content"
    log_info ".env file created successfully."
    echo "------------------------------------------------------------"
  fi
  log_info "Configuration setup complete."
}

function install_backend_dependencies {
  log_info "Setting up AGENTIC backend environment (files)..."
  mkdir -p "$PROJECT_ROOT/$BACKEND_DIR/logs"

  create_or_overwrite_file_heredoc "$BACKEND_DIR/__init__.py" ""
  create_or_overwrite_file_heredoc "$UTILS_DIR/__init__.py" ""

  read -r -d '' config_py_content << 'EOF_CONFIG_PY'
import os
from dotenv import load_dotenv
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(dotenv_path=dotenv_path)
LOG_DIR = os.path.join(os.path.dirname(dotenv_path), "logs")
os.makedirs(LOG_DIR, exist_ok=True)
EOF_CONFIG_PY
  create_or_overwrite_file_heredoc "$UTILS_DIR/config.py" "$config_py_content"

  read -r -d '' logger_py_content << 'EOF_LOGGER_PY'
import logging, sys, os
from .config import LOG_DIR
DEFAULT_LOG_FILE = os.path.join(LOG_DIR, "app.log")
def setup_logger(name="app", log_level_str="INFO"):
    logger = logging.getLogger(name)
    if not logger.handlers:
        logger.setLevel(logging.getLevelName(log_level_str.upper()))
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        sh = logging.StreamHandler(sys.stdout)
        sh.setFormatter(formatter)
        logger.addHandler(sh)
        fh = logging.FileHandler(DEFAULT_LOG_FILE, mode='a', encoding='utf-8')
        fh.setFormatter(formatter)
        logger.addHandler(fh)
        logger.info(f"Logger '{name}' setup complete.")
    return logger
EOF_LOGGER_PY
  create_or_overwrite_file_heredoc "$UTILS_DIR/logger.py" "$logger_py_content"

  # --- main.py updated for new agent creation request ---
  read -r -d '' main_py_content << 'EOF_MAIN_PY'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import logging, os, sys
from contextlib import asynccontextmanager

# Load environment variables first
dotenv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
load_dotenv(dotenv_path=dotenv_path)

ADK_AVAILABLE = False
try:
    from google.adk.agents import LlmAgent
    from google.adk.tools import google_search
    ADK_AVAILABLE = True
except ImportError as e:
    print(f"[ERROR] Failed to import google.adk components: {e}", file=sys.stderr)

try:
    from utils.logger import setup_logger
except ImportError:
    logging.basicConfig(level="INFO")
    def setup_logger(name, **kwargs): return logging.getLogger(name)

logger = setup_logger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application startup...")
    yield
    logger.info("Application shutdown.")

app = FastAPI(title="AGENTIC Backend", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

question_answer_agent = None
if ADK_AVAILABLE:
    try:
        model = os.getenv("DEFAULT_LLM_MODEL", "gemini-1.5-flash-latest")
        question_answer_agent = LlmAgent(model=model, name="backend_agent", tools=[google_search])
        logger.info("LlmAgent initialized successfully.")
    except Exception as e:
        logger.error(f"FATAL: Failed to initialize LlmAgent. Check API Key. Error: {e}", exc_info=True)
        ADK_AVAILABLE = False
else:
    logger.warning("ADK not available. Core features will be disabled.")

# Pydantic Models
class Query(BaseModel): text: str
class Response(BaseModel): answer: str
class CreateAgentRequest(BaseModel):
    agent_name: str
    llm_api: str
    model_name: str
class CreateAgentResponse(BaseModel): message: str

# Helper for Agent Creation
def create_agent_environment(agent_name: str, llm_api: str, model_name: str):
    safe_name = "".join(c for c in agent_name if c.isalnum() or c in ('_', '-')).rstrip()
    if not safe_name: raise ValueError("Invalid agent name.")
    agent_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), safe_name)
    os.makedirs(agent_dir, exist_ok=True)
    with open(os.path.join(agent_dir, "agent.py"), "w") as f:
        f.write(f'# Agent created via AGENTIC Platform for {llm_api}\n')
        f.write(f'from google.adk.agents import LlmAgent\n')
        f.write(f'# This agent will use the model "{model_name}"\n')
        f.write(f'agent = LlmAgent(model="{model_name}", name="{safe_name}")\n')
    logger.info(f"Agent '{safe_name}' files created in '{agent_dir}'")
    return f"Agent '{safe_name}' created successfully for {llm_api}."

# API Endpoints
@app.get("/")
def read_root():
    return {"message": "Welcome to the AGENTIC Backend. The API is running. See /docs for details."}

@app.post("/ask/", response_model=Response)
async def ask_agent_endpoint(query: Query):
    if not ADK_AVAILABLE: raise HTTPException(status_code=503, detail="AI Agent is not available.")
    try:
        response = await question_answer_agent.run(query=query.text)
        return Response(answer=str(response.content))
    except Exception as e:
        logger.error(f"Error processing query: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error processing your request.")

@app.post("/create_agent", response_model=CreateAgentResponse)
async def create_new_agent_endpoint(request: CreateAgentRequest):
    try:
        message = create_agent_environment(request.agent_name, request.llm_api, request.model_name)
        return CreateAgentResponse(message=message)
    except Exception as e:
        logger.error(f"Error creating agent: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "ok", "adk_status": "available" if ADK_AVAILABLE else "unavailable"}
EOF_MAIN_PY
  create_or_overwrite_file_heredoc "$BACKEND_DIR/main.py" "$main_py_content"

  read -r -d '' requirements_content << 'EOF_REQS'
python-dotenv>=1.0.0,<2.0.0
watchfiles>=0.18.0,<1.0.0
google-adk==0.1.0
deprecated
EOF_REQS
  create_or_overwrite_file_heredoc "$BACKEND_DIR/requirements.txt" "$requirements_content"

  log_info "AGENTIC backend files created."
  log_info "Installing AGENTIC backend dependencies..."
  local current_dir; current_dir=$(pwd)
  cd "$ABS_BACKEND_DIR" || return 1
  if [ ! -d "$BACKEND_VENV_NAME" ]; then
    python3 -m venv "$BACKEND_VENV_NAME" || { log_error "Failed to create venv"; cd "$current_dir"; return 1; }
  fi
  source "$BACKEND_VENV_NAME/bin/activate"
  python -m pip install --upgrade pip -q
  pip install -r "requirements.txt" -q || { log_error "Failed to install backend dependencies."; deactivate; cd "$current_dir"; return 1; }
  deactivate
  cd "$current_dir" || return 1
  return 0
}

function install_frontend_dependencies {
  log_info "Setting up frontend environment..."
  mkdir -p "$ABS_FRONTEND_DIR"

  # --- index.html with LLM Provider dropdown ---
  read -r -d '' index_html_content << 'EOF_HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>AGENTIC AI Platform</title><link rel="stylesheet" href="styled.css"></head><body>
<div class="container"><h1>AGENTIC AI Platform</h1><div class="section-box"><h2>Create New Agent</h2><div class="input-group"><label for="newAgentName">Agent Name:</label><input type="text" id="newAgentName" placeholder="e.g., my_research_agent"></div><div class="input-group"><label for="llmProvider">LLM Provider:</label><select id="llmProvider"><option value="gemini" selected>Gemini (Google AI)</option><option value="vertexai">VertexAI (Google Cloud)</option></select></div><div class="input-group"><label for="modelName">Model Name:</label><input type="text" id="modelName" value="gemini-1.5-flash-latest"></div><button id="createAgentButton">Create Agent</button><p id="creationStatus" class="status-message"></p></div><div class="section-box"><h2>Ask the Default AI Agent</h2><div class="input-group"><label for="queryInput">Your Question:</label><input type="text" id="queryInput" placeholder="Ask anything..."></div><button id="askButton">Ask</button><div class="output-area"><h3>Answer:</h3><p id="answerOutput" class="output-content">...</p></div></div></div><script src="dapp.js"></script></body></html>
EOF_HTML
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/index.html" "$index_html_content"

  # --- dapp.js with logic to toggle model name ---
  read -r -d '' dapp_js_content << 'EOF_JS'
document.addEventListener('DOMContentLoaded',()=>{
    const queryInput = document.getElementById('queryInput');
    const askButton = document.getElementById('askButton');
    const answerOutput = document.getElementById('answerOutput');
    
    const createAgentButton = document.getElementById('createAgentButton');
    const newAgentNameInput = document.getElementById('newAgentName');
    const llmProviderSelect = document.getElementById('llmProvider');
    const modelNameInput = document.getElementById('modelName');
    const creationStatus = document.getElementById('creationStatus');

    const backendBaseUrl = "http://localhost:8000";

    // Event listener to toggle model name based on provider
    llmProviderSelect.addEventListener('change', () => {
        if (llmProviderSelect.value === 'gemini') {
            modelNameInput.value = 'gemini-1.5-flash-latest';
            modelNameInput.placeholder = 'gemini-1.5-flash-latest';
        } else { // vertexai
            modelNameInput.value = 'gemini-1.5-flash-001';
            modelNameInput.placeholder = 'gemini-1.5-flash-001';
        }
    });

    async function handleApiCall(button, statusElement, url, body) {
        button.disabled = true;
        statusElement.textContent = 'Processing...';
        statusElement.className = statusElement.className.replace(/ success| error/g, '') + ' loading';

        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: JSON.stringify(body),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.detail || `HTTP error! Status: ${response.status}`);
            return data;
        } catch (error) {
            console.error('API Error:', error);
            statusElement.textContent = `Error: ${error.message}`;
            statusElement.className = statusElement.className.replace(' loading', ' error');
            return null;
        } finally {
            button.disabled = false;
        }
    }

    askButton.addEventListener("click", async () => {
        const query = queryInput.value.trim();
        if (!query) return;
        const data = await handleApiCall(askButton, answerOutput, `${backendBaseUrl}/ask/`, { text: query });
        if(data) {
            answerOutput.textContent = data.answer || "(Received empty answer)";
            answerOutput.className = 'output-content';
        }
    });

    createAgentButton.addEventListener("click", async () => {
        const agentName = newAgentNameInput.value.trim();
        const llmApi = llmProviderSelect.value;
        const modelName = modelNameInput.value.trim();

        if (!agentName || !modelName) {
            creationStatus.textContent = 'Agent Name and Model Name are required.';
            creationStatus.className = 'status-message error';
            return;
        }

        const data = await handleApiCall(createAgentButton, creationStatus, `${backendBaseUrl}/create_agent`, { agent_name: agentName, llm_api: llmApi, model_name: modelName });
        if(data) {
            creationStatus.textContent = data.message;
            creationStatus.className = 'status-message success';
        }
    });
});
EOF_JS
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/dapp.js" "$dapp_js_content"

  read -r -d '' styled_css_content << 'EOF_CSS'
body{font-family:sans-serif;margin:20px;background-color:#f0f2f5;color:#333}.container{max-width:800px;margin:auto;background:#fff;padding:20px;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,.1)}h1,h2{color:#0056b3}.section-box{margin-bottom:20px;padding:20px;border:1px solid #ddd;border-radius:5px}.input-group{margin-bottom:15px}.input-group label{display:block;margin-bottom:5px;font-weight:700}input[type=text],select{width:calc(100% - 22px);padding:10px;border:1px solid #ccc;border-radius:4px;font-size:1rem;background-color:#fff;}button{padding:10px 15px;cursor:pointer;background-color:#007bff;color:#fff;border:none;border-radius:4px;font-size:1rem;margin-top:10px}button:hover{background-color:#0056b3}button:disabled{background-color:#aaa}.output-area{margin-top:15px}.output-content{padding:15px;border-radius:4px;background-color:#e9ecef;min-height:40px;white-space:pre-wrap;word-wrap:break-word}.status-message{margin-top:15px;padding:10px;border-radius:4px;font-weight:700;min-height:1.2em;display:none;}.status-message.loading,.status-message.success,.status-message.error{display:block;}.status-message.loading{color:#0056b3;background-color:#e7f3ff}.status-message.success{color:#155724;background-color:#d4edda}.status-message.error{color:#721c24;background-color:#f8d7da}
EOF_CSS
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/styled.css" "$styled_css_content"

  read -r -d '' server_js_content << 'EOF_NODE'
const express=require("express"),path=require("path"),app=express(),port=process.env.FRONTEND_PORT||3000;app.use(express.static(__dirname)),app.get("*",(e,s)=>s.sendFile(path.resolve(__dirname,"index.html"))),app.listen(port,()=>console.log(`Frontend server listening at http://localhost:${port}`));
EOF_NODE
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/server.js" "$server_js_content"

  read -r -d '' package_json_content << 'EOF_JSON'
{"name":"agentic-frontend","version":"1.0.0","main":"server.js","scripts":{"start":"node server.js"},"dependencies":{"express":"^4.17.1"}}
EOF_JSON
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/package.json" "$package_json_content"

  local current_dir; current_dir=$(pwd)
  cd "$ABS_FRONTEND_DIR" || return 1
  npm install --silent || { log_error "npm install failed."; cd "$current_dir"; return 1; }
  cd "$current_dir" || return 1
  return 0
}

function run_backend {
  cd "$ABS_BACKEND_DIR" || return 1
  source "$BACKEND_VENV_NAME/bin/activate"
  export FRONTEND_PORT
  local log_file="logs/backend_run.log"
  log_info "Starting backend server... Logs at $ABS_BACKEND_DIR/$log_file"
  uvicorn main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload --log-level info > "$log_file" 2>&1 &
  BACKEND_PID=$!
  sleep 3
  if ! ps -p $BACKEND_PID > /dev/null; then
    log_error "Backend failed to start. Check logs in $ABS_BACKEND_DIR/$log_file"
    deactivate && cd "$PROJECT_ROOT" && return 1
  fi
  deactivate && cd "$PROJECT_ROOT" || return 1
  return 0
}

function run_frontend {
  cd "$ABS_FRONTEND_DIR" || return 1
  export FRONTEND_PORT && export BACKEND_PORT
  local log_file="$PROJECT_ROOT/frontend_run.log"
  log_info "Starting frontend server... Logs at $log_file"
  node "server.js" > "$log_file" 2>&1 &
  FRONTEND_PID=$!
  sleep 2
  if ! ps -p $FRONTEND_PID > /dev/null; then
    log_error "Frontend failed to start. Check logs in $log_file"
    cd "$PROJECT_ROOT" && return 1
  fi
  cd "$PROJECT_ROOT" || return 1
  return 0
}

# --- Cleanup Function ---
BACKEND_PID=""
FRONTEND_PID=""
function stop_processes {
  log_info "Initiating shutdown..."
  if [ -n "$BACKEND_PID" ] && ps -p "$BACKEND_PID" > /dev/null; then
    kill "$BACKEND_PID" 2>/dev/null; sleep 1; kill -9 "$BACKEND_PID" 2>/dev/null
  fi
  if [ -n "$FRONTEND_PID" ] && ps -p "$FRONTEND_PID" > /dev/null; then
    kill "$FRONTEND_PID" 2>/dev/null
  fi
  log_info "Shutdown complete."
  exit 0
}

# --- Main Script ---
trap stop_processes SIGINT SIGTERM EXIT
log_info "Starting AGENTIC v1.0.0 deployment..."
check_command python3 && check_command node
setup_environment_config
install_backend_dependencies || { log_error "Backend setup failed."; exit 1; }
install_frontend_dependencies || { log_error "Frontend setup failed."; exit 1; }
run_backend || { log_error "Failed to start backend server."; exit 1; }
run_frontend || { log_error "Failed to start frontend server."; exit 1; }

log_info "--- AGENTIC v1.0.0 Deployed Successfully ---"
log_info "Backend running on: http://localhost:$BACKEND_PORT (PID: $BACKEND_PID)"
log_info "Frontend running on: http://localhost:3000 (PID: $FRONTEND_PID)"
log_info "Press Ctrl+C to stop both servers."
wait
