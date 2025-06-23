#!/bin/bash

# install AGENTIC v1.0.0 as AUGMENTIC

# --- Configuration ---
# Get the directory where the script itself is located
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT="$SCRIPT_DIR"

# --- Helper Functions ---
function log_info {
  echo "[INFO] $1"
}

function log_error {
  echo "[ERROR] $1" >&2
}

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
    log_error "$1 is not installed. Please install it before running this script."
    exit 1
  fi
}

function create_or_overwrite_file_heredoc {
    local file_path="$1"
    local content="$2"
    local dir_path
    dir_path=$(dirname "$file_path")

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
    echo "Please provide your credentials for the backend."
    echo "You can get a Gemini API Key from Google AI Studio."
    echo "------------------------------------------------------------"
    read -p "Enter your Google Gemini API Key: " gemini_api_key
    read -p "Enter your Google Cloud Project ID (e.g., my-gemini-project-12345): " gcloud_project_id

    read -r -d '' env_content << EOF
# .env file for AGENTIC backend
GOOGLE_API_KEY=${gemini_api_key}
GOOGLE_CLOUD_PROJECT_ID=${gcloud_project_id:-your-project-id}
GOOGLE_CLOUD_LOCATION=us-central1
DEFAULT_LLM_MODEL=gemini-1.5-flash-latest
# LOG_LEVEL=DEBUG
EOF
    create_or_overwrite_file_heredoc "$env_file" "$env_content"
    log_info ".env file created successfully with your credentials."
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
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT_ID")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION")
try:
    UTILS_DIR_PATH = os.path.dirname(os.path.abspath(__file__))
    BACKEND_ROOT_DIR = os.path.dirname(UTILS_DIR_PATH)
except NameError:
    BACKEND_ROOT_DIR = os.path.join(os.getcwd(), "agentic", "backend")
LOG_DIR = os.path.join(BACKEND_ROOT_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)
EOF_CONFIG_PY
  create_or_overwrite_file_heredoc "$UTILS_DIR/config.py" "$config_py_content"

  read -r -d '' logger_py_content << 'EOF_LOGGER_PY'
import logging, sys, os
try:
    from .config import LOG_DIR
except ImportError:
    LOG_DIR = os.path.join(os.getcwd(), "logs")
os.makedirs(LOG_DIR, exist_ok=True)
DEFAULT_LOG_FILE = os.path.join(LOG_DIR, "app.log")
_logger_configured_handlers = set()
def setup_logger(name="app", log_level_str="INFO", log_to_file=True, log_file=DEFAULT_LOG_FILE):
    logger = logging.getLogger(name)
    level = logging.getLevelName(log_level_str.upper())
    logger.setLevel(level)
    if name not in _logger_configured_handlers:
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        stdout_handler = logging.StreamHandler(sys.stdout)
        stdout_handler.setFormatter(formatter)
        logger.addHandler(stdout_handler)
        if log_to_file:
            file_handler = logging.FileHandler(log_file, mode='a', encoding='utf-8')
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
        logger.propagate = False
        _logger_configured_handlers.add(name)
        logger.info(f"Logger '{name}' setup complete.")
    return logger
def get_logger(name="app"): return logging.getLogger(name)
EOF_LOGGER_PY
  create_or_overwrite_file_heredoc "$UTILS_DIR/logger.py" "$logger_py_content"

  # --- main.py with Agent Creation Logic ---
  read -r -d '' main_py_content << 'EOF_MAIN_PY'
from fastapi import FastAPI, HTTPException, Request
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
    utils_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "utils")
    if utils_path not in sys.path: sys.path.insert(0, utils_path)
    from logger import setup_logger
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
        logger.info(f"Initializing LlmAgent with model: {model}")
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
    llm_api: str = "gemini"
    model_name: str = "gemini-1.5-flash-latest"
class CreateAgentResponse(BaseModel): message: str

# Helper for Agent Creation
def create_agent_environment(agent_name: str, llm_api: str, model_name: str):
    safe_agent_name = "".join(c for c in agent_name if c.isalnum() or c in ('_', '-')).rstrip()
    if not safe_agent_name:
        raise ValueError("Invalid agent name provided.")

    backend_root = os.path.dirname(os.path.abspath(__file__))
    agentic_root = os.path.dirname(backend_root)
    agent_dir = os.path.join(agentic_root, safe_agent_name)
    logger.info(f"Creating agent environment in: {agent_dir}")
    os.makedirs(agent_dir, exist_ok=True)

    with open(os.path.join(agent_dir, "__init__.py"), "w") as f:
        f.write("# Agent init file\n")

    with open(os.path.join(agent_dir, ".env"), "w") as f:
        f.write(f"LLM_API={llm_api}\nMODEL_NAME={model_name}\n")

    agent_template = f"""
# Agent definition for {safe_agent_name}
import os
from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.adk.tools import google_search

load_dotenv()
MODEL_NAME = os.getenv("MODEL_NAME", "{model_name}")

agent = LlmAgent(model=MODEL_NAME, name="{safe_agent_name}", tools=[google_search])

async def run_agent_query(query: str):
    response = await agent.run(query=query)
    return response.content
"""
    with open(os.path.join(agent_dir, "agent.py"), "w") as f:
        f.write(agent_template)

    return f"Agent '{safe_agent_name}' created in '{agent_dir}'"

# API Endpoints
@app.post("/ask/", response_model=Response)
async def ask_agent_endpoint(query: Query):
    if not ADK_AVAILABLE or question_answer_agent is None:
        raise HTTPException(status_code=503, detail="AI Agent is not available.")
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

  # --- index.html with Agent Creation UI ---
  read -r -d '' index_html_content << 'EOF_HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>AGENTIC AI Platform</title><link rel="stylesheet" href="styled.css"></head><body>
<div class="container">
    <h1>AGENTIC AI Platform</h1>
    
    <!-- Agent Creation Section -->
    <div class="section-box">
        <h2>Create New Agent</h2>
        <div class="input-group">
            <label for="newAgentName">Agent Name:</label>
            <input type="text" id="newAgentName" placeholder="e.g., my_research_agent">
        </div>
        <div class="input-group">
            <label for="llmApi">LLM Provider:</label>
            <select id="llmApi"><option value="gemini" selected>Gemini (Google)</option></select>
        </div>
        <div class="input-group">
            <label for="modelName">Model Name:</label>
            <input type="text" id="modelName" value="gemini-1.5-flash-latest">
        </div>
        <button id="createAgentButton">Create Agent</button>
        <p id="creationStatus" class="status-message"></p>
    </div>

    <!-- Query Section -->
    <div class="section-box">
        <h2>Ask the Default AI Agent</h2>
        <div class="input-group">
            <label for="queryInput">Your Question:</label>
            <input type="text" id="queryInput" placeholder="Ask anything...">
        </div>
        <button id="askButton">Ask</button>
        <div class="output-area">
            <h3>Answer:</h3>
            <p id="answerOutput" class="output-content">...</p>
        </div>
    </div>
</div>
<script src="dapp.js"></script>
</body></html>
EOF_HTML
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/index.html" "$index_html_content"

  # --- dapp.js with Agent Creation Logic ---
  read -r -d '' dapp_js_content << 'EOF_JS'
document.addEventListener('DOMContentLoaded',()=>{
    // Element References
    const queryInput = document.getElementById('queryInput');
    const askButton = document.getElementById('askButton');
    const answerOutput = document.getElementById('answerOutput');
    
    const createAgentButton = document.getElementById('createAgentButton');
    const newAgentNameInput = document.getElementById('newAgentName');
    const llmApiSelect = document.getElementById('llmApi');
    const modelNameInput = document.getElementById('modelName');
    const creationStatus = document.getElementById('creationStatus');

    const backendBaseUrl = "http://localhost:8000";

    // Reusable fetch handler
    async function handleApiCall(button, statusElement, url, body) {
        button.disabled = true;
        statusElement.textContent = 'Processing...';
        statusElement.className = 'status-message loading';
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: JSON.stringify(body),
            });
            const data = await response.json();
            if (!response.ok) {
                throw new Error(data.detail || `HTTP error! Status: ${response.status}`);
            }
            return data;
        } catch (error) {
            console.error('API Error:', error);
            statusElement.textContent = `Error: ${error.message}`;
            statusElement.className = 'status-message error';
            return null;
        } finally {
            button.disabled = false;
        }
    }

    // Event listener for Ask button
    askButton.addEventListener('click', async () => {
        const query = queryInput.value.trim();
        if (!query) return;
        
        answerOutput.textContent = 'Thinking...';
        answerOutput.className = 'output-content loading';
        
        const data = await handleApiCall(askButton, answerOutput, `${backendBaseUrl}/ask/`, { text: query });
        if(data) {
            answerOutput.textContent = data.answer || "(Received empty answer)";
            answerOutput.className = 'output-content';
        } else {
            // Error message is already set by handleApiCall
        }
    });

    // Event listener for Create Agent button
    createAgentButton.addEventListener('click', async () => {
        const agentName = newAgentNameInput.value.trim();
        const llmApi = llmApiSelect.value;
        const modelName = modelNameInput.value.trim();

        if (!agentName || !modelName) {
            creationStatus.textContent = 'Agent Name and Model Name are required.';
            creationStatus.className = 'status-message error';
            return;
        }
        
        const body = { agent_name: agentName, llm_api: llmApi, model_name: modelName };
        const data = await handleApiCall(createAgentButton, creationStatus, `${backendBaseUrl}/create_agent`, body);

        if(data) {
            creationStatus.textContent = data.message;
            creationStatus.className = 'status-message success';
        }
    });
});
EOF_JS
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/dapp.js" "$dapp_js_content"

  read -r -d '' styled_css_content << 'EOF_CSS'
body{font-family:sans-serif;margin:20px;background-color:#f0f2f5;color:#333}.container{max-width:800px;margin:auto;background:#fff;padding:20px;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,.1)}h1,h2{color:#0056b3}.section-box{margin-bottom:20px;padding:20px;border:1px solid #ddd;border-radius:5px}.input-group{margin-bottom:15px}.input-group label{display:block;margin-bottom:5px;font-weight:700}input[type=text],select{width:calc(100% - 22px);padding:10px;border:1px solid #ccc;border-radius:4px;font-size:1rem;}button{padding:10px 15px;cursor:pointer;background-color:#007bff;color:#fff;border:none;border-radius:4px;font-size:1rem;margin-top:10px;}button:hover{background-color:#0056b3}button:disabled{background-color:#aaa}.output-area{margin-top:15px}.output-content{padding:15px;border-radius:4px;background-color:#e9ecef;min-height:40px;white-space:pre-wrap;word-wrap:break-word}.status-message{margin-top:15px;padding:10px;border-radius:4px;font-weight:700;min-height:1.2em;}.status-message.loading{color:#0056b3;background-color:#e7f3ff;}.status-message.success{color:#155724;background-color:#d4edda;}.status-message.error{color:#721c24;background-color:#f8d7da;}
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
log_info "Frontend running on: http://localhost:$FRONTEND_PORT (PID: $FRONTEND_PID)"
log_info "Press Ctrl+C to stop both servers."
wait
