#!/bin/bash

# install AGENTIC v1.0.0 as AUGMENTIC

# --- Configuration ---
# Get the directory where the script itself is located
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Assume the script is in the project root directory (e.g., 'ag')
PROJECT_ROOT="$SCRIPT_DIR"

# --- Helper Functions ---
# Define log functions early so they can be used by config section
function log_info {
  echo "[INFO] $1"
}

function log_error {
  echo "[ERROR] $1" >&2
}

# --- Continue Configuration ---
log_info "Project Root detected as: $PROJECT_ROOT" # Add log for verification

AGENTIC_DIR="agentic" # Relative to PROJECT_ROOT
BACKEND_DIR="$AGENTIC_DIR/backend" # Relative to PROJECT_ROOT
UTILS_DIR="$BACKEND_DIR/utils" # Relative to PROJECT_ROOT
FRONTEND_DIR="frontend" # Relative to PROJECT_ROOT

BACKEND_VENV_NAME="adk"
FRONTEND_PORT=3000
BACKEND_PORT=8000

# Absolute paths derived dynamically from PROJECT_ROOT and relative paths
ABS_BACKEND_DIR="$PROJECT_ROOT/$BACKEND_DIR"
ABS_FRONTEND_DIR="$PROJECT_ROOT/$FRONTEND_DIR"

# Log derived absolute paths for verification
log_info "Absolute Backend Dir: $ABS_BACKEND_DIR"
log_info "Absolute Frontend Dir: $ABS_FRONTEND_DIR"


# --- Helper Functions (Continued) ---
function check_command {
  if ! command -v "$1" &> /dev/null; then
    log_error "$1 is not installed. Please install it before running this script."
    exit 1
  fi
}

# Function to create/overwrite files using printf (safer for complex content)
function create_or_overwrite_file_heredoc {
    local file="$1"
    # Use the second argument directly as the content
    local content="$2"
    local dir
    dir=$(dirname "$file")

    # Ensure the directory exists before trying to create the file
    # Use absolute path for mkdir based on PROJECT_ROOT if file path is relative
    local abs_dir
    if [[ "$dir" == /* ]]; then # Already absolute
        abs_dir="$dir"
    else # Relative path
        abs_dir="$PROJECT_ROOT/$dir"
    fi
    if ! mkdir -p "$abs_dir"; then
        log_error "Failed to create directory: $abs_dir"
        exit 1
    fi

    # Use absolute path for file creation as well
    local abs_file
     if [[ "$file" == /* ]]; then # Already absolute
        abs_file="$file"
    else # Relative path
        abs_file="$PROJECT_ROOT/$file"
    fi

    log_info "Creating/Overwriting file: $abs_file"
    # Use printf to output the content exactly as stored in the variable
    # This avoids shell interpretation issues within the content itself.
    # Add a newline by default unless content is empty
    if [ -n "$content" ]; then
        if ! printf '%s\n' "$content" > "$abs_file"; then
            log_error "Failed to write to file: $abs_file (using printf)"
            exit 1
        fi
    else
        # Handle empty content - create an empty file
        if ! > "$abs_file"; then
             log_error "Failed to create empty file: $abs_file"
             exit 1
        fi
    fi
}


function install_backend_dependencies {
  log_info "Setting up AGENTIC backend environment (files)..."

  # Ensure base backend directories exist first (using relative paths for definition)
  # create_or_overwrite_file_heredoc will handle absolute path creation
  mkdir -p "$PROJECT_ROOT/$BACKEND_DIR/logs" # Create logs dir needed by logger

  # Create backend files directly (using relative paths for definition)
  # Use read -r -d '' for .env content
  read -r -d '' env_content << 'EOF_DOTENV'
# .env file content
DEFAULT_LLM_MODEL=gemini-1.5-flash-latest
GOOGLE_CLOUD_PROJECT_ID=your-project-4334201-c0
GOOGLE_CLOUD_LOCATION=us-central1
# export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/downloaded-keyfile.json"
# LOG_LEVEL=DEBUG # Optional: Set log level (INFO, DEBUG, WARNING, ERROR)
EOF_DOTENV
  create_or_overwrite_file_heredoc "$BACKEND_DIR/.env" "$env_content"

  # Create __init__.py files (empty content is fine)
  create_or_overwrite_file_heredoc "$BACKEND_DIR/__init__.py" ""
  create_or_overwrite_file_heredoc "$UTILS_DIR/__init__.py" ""

  # --- config.py ---
  # Use read -r -d '' with quoted heredoc for config.py content
  read -r -d '' config_py_content << 'EOF_CONFIG_PY'
import os
from dotenv import load_dotenv

# Load environment variables from .env file located in the parent directory of utils/
# This assumes the standard structure where .env is in the backend root
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(dotenv_path=dotenv_path)
print(f"Config: Attempted to load .env from {dotenv_path}")


# Retrieve Google Cloud configuration (will be None if not set)
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT_ID")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION")

# Define constant directory paths relative to the project root
# Assuming this script runs from the project root (e.g., alchemy-daapp)
try:
    # More robust way to get project root assuming utils/ is inside backend/
    UTILS_DIR_PATH = os.path.dirname(os.path.abspath(__file__))
    BACKEND_ROOT_DIR = os.path.dirname(UTILS_DIR_PATH)
    # AGENTIC_ROOT_DIR assumes backend is inside agentic
    # AGENTIC_ROOT_DIR = os.path.dirname(BACKEND_ROOT_DIR)
    # PROJECT_ROOT_DIR assumes agentic is inside the main project dir
    # PROJECT_ROOT_DIR = os.path.dirname(AGENTIC_ROOT_DIR)
except NameError:
    # Fallback if __file__ is not defined (e.g., interactive session)
    # PROJECT_ROOT_DIR = os.getcwd() # Or a more specific fallback
    BACKEND_ROOT_DIR = os.path.join(os.getcwd(), "agentic", "backend") # Guess

LOG_DIR = os.path.join(BACKEND_ROOT_DIR, "logs")
IMAGE_OUTPUT_DIR = os.path.join(BACKEND_ROOT_DIR, "predictions")

# --- Confirmation Log (runs when config.py is imported) ---
print("--- Config Module Loaded ---")
if PROJECT_ID:
    print(f"  PROJECT_ID found: {PROJECT_ID}")
else:
    print("  PROJECT_ID: Not found in environment/.env")
if LOCATION:
    print(f"  LOCATION found: {LOCATION}")
else:
    print("  LOCATION: Not found in environment/.env")

try:
    # Ensure directories exist when config is loaded (optional, logger also does this)
    os.makedirs(LOG_DIR, exist_ok=True)
    os.makedirs(IMAGE_OUTPUT_DIR, exist_ok=True)
    print(f"  LOG_DIR Path: {LOG_DIR}")
    print(f"  IMAGE_OUTPUT_DIR Path: {IMAGE_OUTPUT_DIR}")
except Exception as e:
    print(f"  Error ensuring config directories exist: {e}")
print("--- Config Module End ---")
# --- NO raise ValueError here for graceful handling in UI ---
EOF_CONFIG_PY
  create_or_overwrite_file_heredoc "$UTILS_DIR/config.py" "$config_py_content"

  # --- logger.py ---
  # Use read -r -d '' with a quoted heredoc delimiter to assign the content literally
  read -r -d '' logger_py_content << 'EOF_LOGGER_PY'
import logging
import sys
import os

# Attempt to import LOG_DIR from config module in the same directory
try:
    from .config import LOG_DIR
    print("Logger: Successfully imported LOG_DIR from .config")
except ImportError:
    # Fallback if relative import fails
    print("Logger: Relative import of config failed. Attempting direct import or fallback.")
    try:
        # Try importing config directly (if utils/ is in PYTHONPATH)
        import config
        LOG_DIR = config.LOG_DIR
        print("Logger: Used direct import for config.")
    except ImportError:
        # Absolute fallback if all else fails
        print("Logger: Could not import config. Using default log path relative to logger.py.")
        _FALLBACK_LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "logs")
        LOG_DIR = os.path.abspath(_FALLBACK_LOG_DIR)
        print(f"Logger: Fallback LOG_DIR set to: {LOG_DIR}")

# Ensure the final LOG_DIR exists
try:
    os.makedirs(LOG_DIR, exist_ok=True)
except OSError as e:
    print(f"Logger: CRITICAL ERROR creating log directory '{LOG_DIR}': {e}. Logging to file might fail.")
    # Optionally fallback to current dir or disable file logging
    LOG_DIR = os.getcwd() # Last resort fallback


DEFAULT_LOG_FILE = os.path.join(LOG_DIR, "app.log")

# Global flag to prevent adding handlers multiple times
_logger_configured_handlers = set()

def setup_logger(
    name="app",
    log_level_str="INFO",
    log_to_file=True,
    log_file=DEFAULT_LOG_FILE
):
    """
    Sets up or reconfigures the logger for the application.
    Should be called early in the main script (e.g., main.py for FastAPI).
    """
    global _logger_configured_handlers

    logger = logging.getLogger(name) # Get logger by name
    level = logging.getLevelName(log_level_str.upper())
    logger.setLevel(level) # Always set the level on the logger

    # Configure handlers only once per logger name to avoid duplicates
    if name not in _logger_configured_handlers:
        print(f"Logger: First time setup for logger '{name}'...")
        # Remove existing handlers for this logger instance, if any (e.g., from previous runs in interactive env)
        # for handler in logger.handlers[:]:
        #     logger.removeHandler(handler)

        # Simplified formatter string
        formatter = logging.Formatter('%(asctime)s - %(name)s:%(lineno)d - %(levelname)s - %(message)s')

        # --- Console Handler ---
        stdout_handler = logging.StreamHandler(sys.stdout)
        stdout_handler.setFormatter(formatter)
        stdout_handler.setLevel(level) # Handler level respects logger level
        logger.addHandler(stdout_handler)
        print(f"Logger: Added StreamHandler for '{name}' with level {log_level_str}.")

        # --- File Handler ---
        if log_to_file:
            try:
                # Ensure log directory exists *before* creating handler
                os.makedirs(LOG_DIR, exist_ok=True) # Re-ensure, might have failed earlier
                # Use 'a' for append mode, ensure UTF-8 encoding
                file_handler = logging.FileHandler(log_file, mode='a', encoding='utf-8')
                file_handler.setFormatter(formatter)
                file_handler.setLevel(level) # Handler level respects logger level
                logger.addHandler(file_handler)
                print(f"Logger: Added FileHandler for '{name}' to {os.path.abspath(log_file)} with level {log_level_str}.")
            except Exception as e:
                 # Use print for errors during initial logger setup
                print(f"Logger: ERROR setting up FileHandler for '{name}' to {log_file}: {e}")

        # Prevent messages from propagating to the root logger if handlers are added
        logger.propagate = False
        _logger_configured_handlers.add(name) # Mark this logger name as configured
        logger.info(f"Logger '{name}' first-time setup complete. Level: {log_level_str}, File logging: {log_to_file}")

    else:
        # If already configured, just update levels on existing handlers if needed
        # This might be useful if the log level changes dynamically
        logger.debug(f"Logger '{name}' already configured. Updating handler levels to {log_level_str}.")
        for handler in logger.handlers:
            handler.setLevel(level)
        # logger.info(f"Logger '{name}' level reconfigured to {log_level_str}.") # Avoid excessive logging

    return logger


def get_logger(name="app"):
    """Gets the logger instance. Assumes setup_logger has been called for 'app'."""
    # Return the logger potentially configured by setup_logger
    # If setup_logger wasn't called for 'name', it gets a default logger instance
    # For consistency in this app, we mostly rely on the 'app' logger.
    return logging.getLogger(name)
EOF_LOGGER_PY
  # Now call the function to write the content stored literally in the variable
  create_or_overwrite_file_heredoc "$UTILS_DIR/logger.py" "$logger_py_content"


  # --- main.py ---
  # Use read -r -d '' with quoted heredoc for main.py content
  # NOTE: This main.py uses Pydantic V1 syntax (BaseModel without Field)
  read -r -d '' main_py_content << 'EOF_MAIN_PY'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel # Use Pydantic V1 BaseModel
import logging # Keep standard logging import
import os
from dotenv import load_dotenv
import sys
from typing import List, Optional # For Pydantic V1

# Attempt to import ADK components
ADK_AVAILABLE = False
try:
    from google.adk.agents import LlmAgent
    from google.adk.tools import google_search
    ADK_AVAILABLE = True
    print("Main: Successfully imported google.adk components.")
except ImportError as e:
    print(f"Main: WARNING - Failed to import google.adk components: {e}")
    print("Main: ADK features will be unavailable.")
    # Define dummy classes/functions if ADK is optional
    class LlmAgent:
        def __init__(self, *args, **kwargs): pass
        async def run(self, *args, **kwargs): return type('obj', (object,), {'content': 'ADK not available'})()
    def google_search(): pass

# Determine backend root and load .env relative to main.py
try:
    BACKEND_ROOT_DIR_MAIN = os.path.dirname(os.path.abspath(__file__))
    # Load .env file from the directory containing main.py
    dotenv_path = os.path.join(BACKEND_ROOT_DIR_MAIN, '.env')
    load_dotenv(dotenv_path=dotenv_path)
    print(f"Main: Attempted to load .env from {dotenv_path}")
except NameError:
    BACKEND_ROOT_DIR_MAIN = os.getcwd()
    print("Main: Warning - Could not determine script directory, loading .env from CWD.")
    load_dotenv() # Load from CWD as fallback

# Import the custom logger setup AFTER loading .env
# Ensure utils is importable (e.g., backend/ is in PYTHONPATH or run with python -m)
try:
    # Add utils directory to path temporarily if needed
    utils_path = os.path.join(BACKEND_ROOT_DIR_MAIN, "utils")
    if utils_path not in sys.path:
        sys.path.insert(0, utils_path)
        print(f"Main: Added {utils_path} to sys.path")

    from logger import setup_logger, get_logger
    # from config import IMAGE_OUTPUT_DIR # Import config vars if needed directly in main
    print("Main: Successfully imported logger and config from utils.")
except ImportError as e:
    print(f"Main: CRITICAL ERROR importing utils: {e}. Check structure and PYTHONPATH. Using basic logger.")
    # Define fallbacks or exit if utils are essential
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO").upper())
    def get_logger(name): return logging.getLogger(name) # Basic fallback
    # exit(1) # Uncomment to make utils mandatory


# Setup the logger early
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
setup_logger(name="app", log_level_str=LOG_LEVEL)
logger = get_logger(__name__) # Gets the 'app' logger instance configured above

logger.info("--- Starting FastAPI Application Setup ---")

app = FastAPI(title="AGENTIC Backend", version="1.0.0")

# CORS middleware
FRONTEND_PORT_NUM = os.getenv('FRONTEND_PORT', '3000')
FRONTEND_ORIGIN = f"http://localhost:{FRONTEND_PORT_NUM}"
ALLOWED_ORIGINS = [FRONTEND_ORIGIN]
# Allow specific other origins if needed
# ALLOWED_ORIGINS.append("http://example.com")
# Or allow all for local dev (use environment variable for safety)
if os.getenv("ALLOW_ALL_ORIGINS") == "true":
    ALLOWED_ORIGINS = ["*"]
    logger.warning("CORS configured to allow all origins!")
else:
     logger.info(f"CORS configured for origins: {ALLOWED_ORIGINS}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"], # Allows all standard methods
    allow_headers=["*"], # Allows all headers
)

# Determine AGENTIC_DIR (parent of backend)
try:
    AGENTIC_DIR = os.path.dirname(BACKEND_ROOT_DIR_MAIN)
    logger.info(f"AGENTIC_DIR determined as: {AGENTIC_DIR}")
except Exception as e:
    AGENTIC_DIR = os.path.join(os.getcwd(), "agentic") # Guess location
    logger.warning(f"Could not determine AGENTIC_DIR dynamically, assuming: {AGENTIC_DIR} ({e})")


DEFAULT_LLM_MODEL = os.getenv("DEFAULT_LLM_MODEL", "gemini-1.5-flash-latest")
CURRENT_DATETIME_STR = "a recent date/time" # Keep simple
CANADA_CONTEXT = "Prioritize Canadian results if relevant to the query."


# --- Agent Definition ---
question_answer_agent = None # Initialize as None
if ADK_AVAILABLE:
    try:
        llm_model_name = os.getenv("LLM_MODEL_NAME", DEFAULT_LLM_MODEL)
        # Check for necessary credentials/config for the chosen model/API
        logger.info(f"Attempting to initialize LlmAgent with model: {llm_model_name}")

        question_answer_agent = LlmAgent(
            model=llm_model_name,
            name="backend_question_answer_agent",
            description="Answers user questions using Google Search (backend).",
            instruction=f"""You are a helpful assistant. Use Google Search to answer questions. Be concise and informative. {CANADA_CONTEXT} Current time is approx {CURRENT_DATETIME_STR}.""",
            tools=[google_search], # Use imported tool
        )
        logger.info(f"LLM Agent initialized successfully with model: {question_answer_agent.model}")

    except Exception as e:
        logger.error(f"Failed to initialize LlmAgent: {e}", exc_info=True)
        # question_answer_agent remains None
else:
    logger.warning("ADK not available, cannot initialize LlmAgent.")


# --- Pydantic Models (V1 Syntax) ---
class Query(BaseModel):
    text: str

class Response(BaseModel):
    answer: str

class CreateAgentRequest(BaseModel):
    agent_name: str
    llm_api: str = "gemini"
    model_name: str = DEFAULT_LLM_MODEL

class CreateAgentResponse(BaseModel):
    message: str


# --- Helper Function for Agent Creation ---
def create_agent_environment(agent_name: str, llm_api: str, model_name: str):
    # Basic sanitization
    safe_agent_name = "".join(c for c in agent_name if c.isalnum() or c in ('_', '-')).rstrip()
    if not safe_agent_name:
        raise ValueError("Invalid agent name provided (must contain alphanumeric characters).")

    # Use the dynamically determined AGENTIC_DIR
    agent_dir = os.path.join(AGENTIC_DIR, safe_agent_name)
    logger.info(f"Creating agent environment in: {agent_dir}")
    try:
        os.makedirs(agent_dir, exist_ok=True)
    except OSError as e:
        logger.error(f"Failed to create agent directory {agent_dir}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create agent directory: {e}")


    # Create __init__.py
    try:
        with open(os.path.join(agent_dir, "__init__.py"), "w") as f:
            f.write("# Init file for agent\n")
    except IOError as e:
        logger.error(f"Failed to write __init__.py in {agent_dir}: {e}")

    # Create .env
    try:
        with open(os.path.join(agent_dir, ".env"), "w") as f:
            f.write(f"LLM_API={llm_api}\n")
            f.write(f"MODEL_NAME={model_name}\n")
            logger.info(f"Created .env file in {agent_dir}")
    except IOError as e:
         logger.error(f"Failed to write .env file in {agent_dir}: {e}")
         raise HTTPException(status_code=500, detail=f"Failed to write agent config: {e}")


    # Create agent.py (using f-string)
    agent_template = f"""# Agent definition for {safe_agent_name}
import os
from dotenv import load_dotenv
import sys

# Attempt to import ADK components
AGENT_ADK_AVAILABLE = False
try:
    from google.adk.agents import LlmAgent
    from google.adk.tools import google_search
    AGENT_ADK_AVAILABLE = True
    print(f"Agent '{safe_agent_name}': ADK imported.")
except ImportError as e:
    print(f"Agent '{safe_agent_name}': WARNING - Failed to import google.adk components: {{e}}")
    class LlmAgent:
        def __init__(self, *args, **kwargs): pass
        async def run(self, *args, **kwargs): return type('obj', (object,), {{'content': 'ADK not available in agent'}})()
    def google_search(): pass

# Load agent-specific environment variables from .env in this directory
load_dotenv()

LLM_API = os.getenv("LLM_API", "{llm_api}")
MODEL_NAME = os.getenv("MODEL_NAME", "{model_name}")

print(f"Agent '{safe_agent_name}': Initializing with model: {{MODEL_NAME}} (API: {{LLM_API}})")

agent = None # Initialize as None
if AGENT_ADK_AVAILABLE:
    try:
        agent = LlmAgent(
            model=MODEL_NAME,
            name="{safe_agent_name}",
            description=f"AGENTIC agent '{safe_agent_name}' using {{LLM_API}}.",
            instruction="Answer the user's question concisely based on available tools.",
            tools=[google_search] # Use imported tool
        )
        print(f"Agent '{safe_agent_name}': LlmAgent initialized.")
    except Exception as e:
        print(f"Agent '{safe_agent_name}': ERROR - Failed to initialize LlmAgent: {{e}}")
else:
    print(f"Agent '{safe_agent_name}': ADK not available, cannot initialize LlmAgent.")


# Example function to run the agent
async def run_agent_query(query: str):
    if agent:
        try:
            print(f"Agent '{safe_agent_name}': Running query: {{query}}")
            response = await agent.run(query=query)
            print(f"Agent '{safe_agent_name}': Response received.")
            return response.content
        except Exception as e:
            print(f"Agent '{safe_agent_name}': Error running query: {{e}}")
            return "Error processing query."
    else:
        print(f"Agent '{safe_agent_name}': Agent not initialized, cannot run query.")
        return "Agent not initialized."

# Example usage (optional, for direct testing of agent.py)
# if __name__ == "__main__":
#    import asyncio
#    async def main():
#        print(f"--- Testing Agent: {safe_agent_name} ---")
#        response_content = await run_agent_query("What is the weather like today?")
#        print(f"Agent Response: {{response_content}}")
#        print(f"--- End Test ---")
#    asyncio.run(main())
"""
    agent_py_path = os.path.join(agent_dir, "agent.py")
    try:
        with open(agent_py_path, "w") as f:
            f.write(agent_template)
        logger.info(f"Created agent.py file at {agent_py_path}")
    except IOError as e:
        logger.error(f"Failed to write agent.py file at {agent_py_path}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to write agent code: {e}")


    logger.info(f"Agent '{safe_agent_name}' environment created successfully.")
    return f"Agent '{safe_agent_name}' environment created in '{agent_dir}' using {llm_api} with model '{model_name}'."


# --- API Endpoints ---
@app.post("/ask/", response_model=Response, tags=["Agent Interaction"])
async def ask_agent_endpoint(query: Query):
    """Endpoint to ask a question to the default backend agent."""
    if question_answer_agent is None:
        logger.error("Main LLM agent is not available for /ask/ endpoint.")
        raise HTTPException(status_code=503, detail="AI Agent is currently unavailable. Check backend logs.")

    logger.info(f"Received query for /ask/: '{query.text}'")
    try:
        # Assuming agent.run is async
        response = await question_answer_agent.run(query=query.text)
        # Ensure response.content is serializable (usually string)
        answer = response.content if isinstance(response.content, str) else str(response.content)
        logger.info(f"Sending answer (truncated): {answer[:100]}...")
        return Response(answer=answer)
    except Exception as e:
        logger.error(f"Error processing query '{query.text}' in /ask/: {e}", exc_info=True)
        # Provide a generic error message to the client
        raise HTTPException(status_code=500, detail="An internal error occurred while processing your request.")


@app.post("/create_agent", response_model=CreateAgentResponse, tags=["Agent Management"])
async def create_new_agent_endpoint(request: CreateAgentRequest):
    """Endpoint to create a new agent environment."""
    agent_name = request.agent_name
    llm_api = request.llm_api
    model_name = request.model_name
    logger.info(f"Request received for /create_agent: name='{agent_name}', api='{llm_api}', model='{model_name}'")
    try:
        # Pydantic V1 performs basic type validation
        # Add manual validation for agent_name pattern if needed here, or rely on helper
        if not all(c.isalnum() or c in ('_', '-') for c in agent_name):
             raise ValueError("Agent name can only contain letters, numbers, underscores, and hyphens.")

        message = create_agent_environment(agent_name, llm_api, model_name)
        logger.info(f"Agent creation successful via /create_agent: {message}")
        return CreateAgentResponse(message=message)
    except ValueError as ve:
        # Catch specific validation errors
        logger.warning(f"Invalid agent name or other value provided via /create_agent: {ve}")
        raise HTTPException(status_code=400, detail=str(ve))
    except HTTPException:
        # Re-raise HTTPExceptions raised by the helper function (e.g., file IO errors)
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating agent '{agent_name}' via /create_agent: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"An internal error occurred while creating agent '{agent_name}'.")


@app.get("/health", tags=["Utility"])
async def health_check():
    """Basic health check endpoint."""
    agent_status = "available" if ADK_AVAILABLE and question_answer_agent else "unavailable"
    logger.debug(f"Health check requested. ADK Available: {ADK_AVAILABLE}, Agent Initialized: {question_answer_agent is not None}")
    return {"status": "ok", "adk_available": ADK_AVAILABLE, "agent_status": agent_status}

@app.get("/", tags=["Utility"], include_in_schema=False) # Hide from default OpenAPI docs
async def read_root():
    """Root endpoint providing basic info."""
    return {"message": "Welcome to the AGENTIC Backend API. See /docs for details."}


logger.info("--- FastAPI Application Setup Complete ---")

# Note: Uvicorn run command should be outside this script, managed by the shell script.
EOF_MAIN_PY
  create_or_overwrite_file_heredoc "$BACKEND_DIR/main.py" "$main_py_content"

  # --- requirements.txt ---
  # Let google-adk handle its core dependencies (fastapi, pydantic, uvicorn, etc.)
  # We only explicitly list google-adk and other direct needs like python-dotenv.
  read -r -d '' requirements_content << 'EOF_REQS'
# Environment & Config
python-dotenv>=1.0.0,<2.0.0

# Web Server & Reloading
watchfiles>=0.18.0,<1.0.0 # For uvicorn --reload

# Google Cloud & AI
google-adk==0.1.0

# NOTE: fastapi, pydantic, uvicorn, typing-extensions etc.
# will be installed as dependencies of google-adk.
# Ensure the versions pulled in are compatible with your code.
# (google-adk==0.1.0 pulls fastapi==0.104.1, pydantic==1.10.13, uvicorn==0.24.0.post1)
EOF_REQS
  create_or_overwrite_file_heredoc "$BACKEND_DIR/requirements.txt" "$requirements_content"

  log_info "AGENTIC backend files created."

  log_info "Installing AGENTIC backend dependencies..."
  # Store current dir to return later
  local current_dir
  current_dir=$(pwd)
  if ! cd "$BACKEND_DIR"; then
      log_error "Failed to cd to backend directory: $BACKEND_DIR"
      return 1 # Use return instead of exit if called from main script
  fi

  # Create virtual environment if it doesn't exist
  if [ ! -d "$BACKEND_VENV_NAME" ]; then
    log_info "Creating virtual environment '$BACKEND_VENV_NAME'..."
    if ! python3 -m venv "$BACKEND_VENV_NAME"; then
        log_error "Failed to create virtual environment in $(pwd)"
        cd "$current_dir" || exit 1 # Return to original dir or exit if failed
        return 1
    fi
    log_info "Virtual environment created."
    # Activate immediately for pip upgrade
    if ! source "$BACKEND_VENV_NAME/bin/activate"; then
        log_error "Failed to activate virtual environment in $(pwd)"
        cd "$current_dir" || exit 1
        return 1
    fi
    log_info "Upgrading pip..."
    if ! python -m pip install --upgrade pip -q; then # Add -q
        log_error "Failed to upgrade pip."
        deactivate # Deactivate before returning
        cd "$current_dir" || exit 1
        return 1
    fi
  else
    log_info "Activating existing virtual environment '$BACKEND_VENV_NAME'..."
    if ! source "$BACKEND_VENV_NAME/bin/activate"; then
        log_error "Failed to activate virtual environment in $(pwd)"
        cd "$current_dir" || exit 1
        return 1
    fi
  fi

  log_info "Virtual environment '$BACKEND_VENV_NAME' activated."

  # Install requirements
  if [ -f "requirements.txt" ]; then
    log_info "Installing dependencies from requirements.txt..."
    # Add -q for quieter install, remove for full verbose output
    if ! pip install -r "requirements.txt" -q; then
        log_error "Failed to install backend dependencies from requirements.txt in $(pwd)."
        log_error "Check the requirements.txt file, network connection, and previous logs."
        deactivate # Deactivate before returning
        cd "$current_dir" || exit 1
        return 1
    fi
    log_info "AGENTIC backend dependencies installed successfully."
  else
    log_info "WARNING: No 'requirements.txt' found in $(pwd). Skipping backend dependency installation."
  fi

  # Deactivate the virtual environment
  deactivate
  log_info "Virtual environment deactivated."

  # Return to the original directory
  if ! cd "$current_dir"; then
      log_error "Failed to cd back to original directory: $current_dir"
      exit 1 # This is problematic, exit the script
  fi
  # Indicate success
  return 0
}


function install_frontend_dependencies {
  log_info "Setting up frontend environment (files and dependencies)..."

  # Ensure frontend directory exists using absolute path
  mkdir -p "$ABS_FRONTEND_DIR"

  # --- index.html ---
  read -r -d '' index_html_content << 'EOF_HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AGENTIC AI Assistant v1.0.0</title>
    <link rel="stylesheet" href="styled.css">
</head>
<body>
    <div class="container">
        <h1>AGENTIC AI Assistant v1.0.0</h1>

        <!-- Agent Creation Section -->
        <div class="agent-creation-area section-box">
            <h2>Create New Agent</h2>
            <div class="input-group">
                <label for="newAgentName">Agent Name:</label>
                <input type="text" id="newAgentName" placeholder="Alphanumeric, _, - (e.g., my_agent)">
            </div>
            <div class="input-group">
                <label for="llmApi">LLM API:</label>
                <select id="llmApi">
                    <option value="gemini" selected>Gemini</option>
                    <option value="vertex-ai">Vertex AI</option>
                    <!-- Add other LLM options here -->
                </select>
            </div>
            <div class="input-group">
                <label for="modelName">Model Name:</label>
                <input type="text" id="modelName" placeholder="e.g., gemini-1.5-flash-latest" value="gemini-1.5-flash-latest">
            </div>
            <button id="createAgentButton">Create Agent</button>
            <p id="creationStatus" class="status-message"></p>
        </div>

        <!-- Query Section -->
        <div class="query-area section-box">
            <h2>Ask the Default AI Agent</h2>
            <div class="input-group">
                 <label for="queryInput">Your Question:</label>
                 <input type="text" id="queryInput" placeholder="Ask me anything...">
            </div>
            <button id="askButton">Ask</button>
            <div class="output-area">
                <h3>Answer:</h3>
                <p id="answerOutput" class="output-content">Waiting for your question...</p>
            </div>
        </div>

    </div>
    <!-- Link JS at the end of body -->
    <script src="dapp.js"></script>
</body>
</html>
EOF_HTML
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/index.html" "$index_html_content"

  # --- dapp.js ---
  read -r -d '' dapp_js_content << 'EOF_JS'
document.addEventListener('DOMContentLoaded', () => {
    // --- Element References ---
    const queryInput = document.getElementById('queryInput');
    const askButton = document.getElementById('askButton');
    const answerOutput = document.getElementById('answerOutput');
    const createAgentButton = document.getElementById('createAgentButton');
    const newAgentNameInput = document.getElementById('newAgentName');
    const llmApiSelect = document.getElementById('llmApi');
    const modelNameInput = document.getElementById('modelName');
    const creationStatus = document.getElementById('creationStatus');

    // Determine backend URL - dynamically set by build script
    const backendBaseUrl = "__BACKEND_BASE_URL__";

    console.log(`Frontend configured to use backend at: ${backendBaseUrl}`);


    // --- Event Listener for Ask Button ---
    askButton.addEventListener('click', handleAsk);
    queryInput.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault(); // Prevent default form submission if inside a form
            handleAsk(); // Trigger ask function on Enter key
        }
    });

    async function handleAsk() {
        const query = queryInput.value.trim();
        if (!query) {
            alert('Please enter a question.');
            return;
        }

        answerOutput.textContent = 'Thinking...';
        answerOutput.className = 'output-content loading'; // Reset classes
        creationStatus.textContent = ''; // Clear other messages

        try {
            const response = await fetch(`${backendBaseUrl}/ask/`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json', // Be explicit about expected response type
                },
                body: JSON.stringify({ text: query }),
            });

            // Always try to parse JSON, even for errors, as FastAPI often returns JSON errors
            const data = await response.json();

            if (!response.ok) {
                // Use detail from JSON if available, otherwise construct error message
                const errorDetail = data.detail || `HTTP error! Status: ${response.status} ${response.statusText}`;
                throw new Error(errorDetail);
            }

            answerOutput.textContent = data.answer || "(Received empty answer)"; // Handle potentially empty answers
            answerOutput.classList.remove('loading');
            // answerOutput.classList.add('success'); // Optional: style success

        } catch (error) {
            console.error('Error fetching answer:', error);
            answerOutput.textContent = `Error: ${error.message}`;
            answerOutput.className = 'output-content error'; // Set error class
        }
    }


    // --- Event Listener for Create Agent Button ---
    createAgentButton.addEventListener('click', handleCreateAgent);

    async function handleCreateAgent() {
        const newAgentName = newAgentNameInput.value.trim();
        const llmApi = llmApiSelect.value;
        const modelName = modelNameInput.value.trim();

        // Basic client-side validation
        const agentNamePattern = /^[a-zA-Z0-9_-]+$/;
        if (!newAgentName) {
            creationStatus.textContent = 'Agent name cannot be empty.';
            creationStatus.className = 'status-message error';
            return;
        }
        if (!agentNamePattern.test(newAgentName)) {
             creationStatus.textContent = 'Agent name can only contain letters, numbers, underscores, and hyphens.';
             creationStatus.className = 'status-message error';
             return;
        }
         if (!modelName) {
            creationStatus.textContent = 'Model name cannot be empty.';
            creationStatus.className = 'status-message error';
            return;
        }

        creationStatus.textContent = 'Creating agent...';
        creationStatus.className = 'status-message loading'; // Use classes
        answerOutput.textContent = '...'; // Clear previous answer
        answerOutput.className = 'output-content'; // Reset answer style

        try {
            const response = await fetch(`${backendBaseUrl}/create_agent`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({
                    agent_name: newAgentName,
                    llm_api: llmApi,
                    model_name: modelName
                }),
            });

            const data = await response.json(); // Try to parse JSON regardless of status code

            if (!response.ok) {
                 // Use detail from JSON if available, otherwise status text
                const errorDetail = data.detail || `HTTP ${response.status}: ${response.statusText}`;
                throw new Error(errorDetail);
            }

            creationStatus.textContent = data.message || 'Agent created successfully!';
            creationStatus.className = 'status-message success'; // Use classes
            // Optionally clear inputs on success
            // newAgentNameInput.value = '';
            // modelNameInput.value = 'gemini-1.5-flash-latest'; // Reset to default

        } catch (error) {
            console.error('Error creating agent:', error);
            creationStatus.textContent = `Error: ${error.message}`;
            creationStatus.className = 'status-message error'; // Use classes
        }
    }

});
EOF_JS
  dapp_js_content="${dapp_js_content//__BACKEND_BASE_URL__/http:\/\/localhost:$BACKEND_PORT}"
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/dapp.js" "$dapp_js_content"

  # --- styled.css ---
  read -r -d '' styled_css_content << 'EOF_CSS'
/* General Styles */
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #f8f9fa;
    color: #212529;
    line-height: 1.6;
}

.container {
    max-width: 800px;
    margin: 20px auto;
    background-color: #ffffff;
    padding: 30px;
    border-radius: 8px;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid #dee2e6;
}

h1, h2, h3 {
    color: #007bff; /* Primary color */
    margin-top: 0;
    margin-bottom: 15px;
    text-align: center;
}

h1 {
    font-size: 2em;
    margin-bottom: 25px;
}

h2 {
    font-size: 1.5em;
    border-bottom: 1px solid #eee;
    padding-bottom: 10px;
    margin-bottom: 20px;
}

h3 {
    font-size: 1.2em;
    color: #17a2b8; /* Info color */
    margin-bottom: 10px;
}

/* Section Styling */
.section-box {
    margin-bottom: 30px;
    padding: 20px;
    border: 1px solid #e9ecef;
    border-radius: 5px;
    background-color: #fdfdff; /* Slightly off-white */
}

/* Input Group Styling */
.input-group {
    margin-bottom: 15px;
    display: flex;
    flex-wrap: wrap; /* Allow wrapping on small screens */
    gap: 10px;
    align-items: center;
}

.input-group label {
    flex-basis: 100px; /* Fixed base width for labels */
    flex-shrink: 0;
    font-weight: bold;
    color: #495057;
}

.input-group input[type="text"],
.input-group select {
    flex-grow: 1; /* Allow input to take remaining space */
    padding: 10px 12px;
    border: 1px solid #ced4da;
    border-radius: 4px;
    font-size: 1rem;
    box-sizing: border-box; /* Include padding in width */
    min-width: 150px; /* Prevent inputs from becoming too small */
}

/* Button Styling */
button {
    padding: 10px 20px;
    cursor: pointer;
    background-color: #007bff;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 1rem;
    font-weight: 500;
    transition: background-color 0.2s ease, transform 0.1s ease;
    display: block; /* Make button block level for centering or full width */
    margin: 10px auto 0; /* Center button */
}

button:hover {
    background-color: #0056b3;
}

button:active {
    transform: scale(0.98); /* Slight press effect */
}

/* Status and Output Styling */
.status-message {
    margin-top: 15px;
    padding: 10px;
    border-radius: 4px;
    font-weight: 500;
    text-align: center;
    min-height: 1.5em; /* Prevent layout shift when empty */
    transition: background-color 0.3s ease, border-color 0.3s ease, color 0.3s ease;
}

.status-message:empty {
    padding: 0; /* Collapse padding when empty */
    border: none;
    background-color: transparent;
}


.status-message.loading {
    color: #0056b3;
    background-color: #e7f3ff;
    border: 1px solid #b3d7ff;
}

.status-message.success {
    color: #155724;
    background-color: #d4edda;
    border: 1px solid #c3e6cb;
}

.status-message.error {
    color: #721c24;
    background-color: #f8d7da;
    border: 1px solid #f5c6cb;
}

.output-area {
    margin-top: 20px;
}

.output-content {
    font-size: 1rem;
    padding: 15px;
    border: 1px solid #eee;
    border-radius: 4px;
    background-color: #fefefe;
    min-height: 50px; /* Ensure it has some height even when empty */
    white-space: pre-wrap; /* Preserve whitespace and line breaks */
    word-wrap: break-word; /* Break long words */
    transition: background-color 0.3s ease, border-color 0.3s ease, color 0.3s ease; /* Smooth transitions */
}

.output-content.loading {
    opacity: 0.7;
    font-style: italic;
    background-color: #f8f9fa;
}

/* No specific success style needed unless different from default */
/* .output-content.success { */
/*      border-color: #c3e6cb; */
/* } */


.output-content.error {
    color: #721c24;
    border-color: #f5c6cb; /* Match error message border */
    background-color: #f8d7da; /* Match error message background */
}

/* Responsive Adjustments */
@media (max-width: 600px) {
    .container {
        padding: 20px;
    }
    .input-group {
        flex-direction: column;
        align-items: stretch;
    }
    .input-group label {
        flex-basis: auto; /* Reset basis */
        margin-bottom: 5px; /* Add space below label */
    }
    button {
        width: 100%; /* Make buttons full width on small screens */
        margin-left: 0;
        margin-right: 0;
    }
}
EOF_CSS
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/styled.css" "$styled_css_content"

  # --- server.js ---
  read -r -d '' server_js_content << 'EOF_NODE'
const express = require('express');
const path = require('path');
const app = express();

// Use environment variable for port or default to 3000
// Use the FRONTEND_PORT environment variable if set by the run script, otherwise default
const port = process.env.FRONTEND_PORT || 3000;

// Serve static files from the directory this script is in ('./frontend')
app.use(express.static(__dirname));

// Log requests for debugging (optional)
app.use((req, res, next) => {
  // Avoid logging requests for static assets if too noisy
  if (!req.path.includes('.')) {
     console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  }
  next();
});


// Proxy endpoint for backend calls (Example - if CORS is an issue or you want to hide backend URL)
// This requires installing 'http-proxy-middleware': npm install http-proxy-middleware
/*
const { createProxyMiddleware } = require('http-proxy-middleware');
// Use BACKEND_PORT env var if set, otherwise default
const backendPort = process.env.BACKEND_PORT || 8000;
const backendUrl = `http://localhost:${backendPort}`;
app.use('/ask', createProxyMiddleware({ target: backendUrl, changeOrigin: true }));
app.use('/create_agent', createProxyMiddleware({ target: backendUrl, changeOrigin: true }));
console.log(`Proxying API requests to: ${backendUrl}`);
*/
// If not using proxy, ensure backend CORS allows frontend origin.


// Fallback for SPA: always serve index.html for any GET request not matching static files
app.get('*', (req, res) => {
  // Check if the request accepts HTML, avoids serving HTML for API-like calls
  if (req.accepts('html')) {
    res.sendFile(path.resolve(__dirname, 'index.html'), (err) => {
      if (err) {
        console.error("Error sending index.html:", err);
        // Avoid sending status if headers already sent
        if (!res.headersSent) {
            res.status(err.status || 500).end();
        }
      }
    });
  } else {
    // Handle non-HTML requests if needed, or just send 404
     if (!res.headersSent) {
        res.status(404).send('Resource not found');
     }
  }
});


app.listen(port, () => {
  console.log(`Frontend server listening at http://localhost:${port}`);
  console.log(`Serving static files from: ${__dirname}`);
});

// Basic error handling for server start
app.on('error', (error) => {
  if (error.syscall !== 'listen') {
    throw error;
  }
  // Handle specific listen errors with friendly messages
  switch (error.code) {
    case 'EACCES':
      console.error(`Port ${port} requires elevated privileges`);
      process.exit(1);
      break;
    case 'EADDRINUSE':
      console.error(`Port ${port} is already in use. Check if another process is running.`);
      process.exit(1);
      break;
    default:
      console.error(`Server error: ${error}`);
      throw error; // Re-throw other errors
  }
});
EOF_NODE
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/server.js" "$server_js_content"

  # --- package.json ---
  read -r -d '' package_json_content << 'EOF_JSON'
{
  "name": "agentic-frontend",
  "version": "1.0.0",
  "description": "Frontend for AGENTIC AI Assistant",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.17.1"
  },
  "devDependencies": {},
  "author": "CodePhreak",
  "license": "ISC"
}
EOF_JSON
  create_or_overwrite_file_heredoc "$FRONTEND_DIR/package.json" "$package_json_content"

  log_info "Frontend files created in $FRONTEND_DIR (relative to $PROJECT_ROOT)." # Adjusted log

  log_info "Installing frontend dependencies (npm)..."
  # Store current dir
  local current_dir
  current_dir=$(pwd)
  # Change to the ABSOLUTE frontend directory
  if ! cd "$ABS_FRONTEND_DIR"; then
      log_error "Failed to cd to frontend directory: $ABS_FRONTEND_DIR"
      return 1 # Use return, not exit
  fi

  if [ -f "package.json" ]; then
    log_info "Running 'npm install' in $(pwd)..."
    # Use npm ci for faster, more reliable installs if package-lock.json exists
    if [ -f "package-lock.json" ]; then
        # Add --silent to reduce verbose output, remove if debugging needed
        if ! npm ci --silent; then
            log_error "Failed to install frontend dependencies using 'npm ci'. Trying 'npm install'..."
            # Fallback to npm install if npm ci fails
            if ! npm install --silent; then
                 log_error "Failed to install frontend dependencies using 'npm install' in $(pwd)."
                 cd "$current_dir" || exit 1 # Return or exit
                 return 1
            fi
        fi
    else
        if ! npm install --silent; then
            log_error "Failed to install frontend dependencies using 'npm install' in $(pwd)."
            cd "$current_dir" || exit 1 # Return or exit
            return 1
        fi
    fi
    log_info "Frontend dependencies installed successfully."
  else
    log_info "WARNING: No 'package.json' found in $(pwd). Skipping frontend dependency installation."
  fi

  # Return to original directory
  if ! cd "$current_dir"; then
      log_error "Failed to cd back to original directory: $current_dir"
      exit 1 # Exit here is problematic
  fi
  # Indicate success
  return 0
}


function run_backend {
  log_info "Starting AGENTIC backend (FastAPI) on http://localhost:$BACKEND_PORT..."
  # Store current directory to return to it
  local current_dir
  current_dir=$(pwd)
  # Use explicit absolute path for cd to ensure consistency
  if ! cd "$ABS_BACKEND_DIR"; then
      log_error "Failed to cd to backend directory '$ABS_BACKEND_DIR' to start server."
      return 1 # Cannot start server if not in the correct directory
  fi

  log_info "Activating backend virtual environment '$BACKEND_VENV_NAME'..."
  if [ ! -f "$BACKEND_VENV_NAME/bin/activate" ]; then
      log_error "Virtual environment activate script not found: $BACKEND_VENV_NAME/bin/activate"
      cd "$current_dir" || exit 1
      return 1
  fi
  # Source the activate script into the current shell
  # Use '.' as a shorter alias for 'source'
  if ! . "$BACKEND_VENV_NAME/bin/activate"; then
    log_error "Failed to activate virtual environment '$BACKEND_VENV_NAME/bin/activate' before running backend."
    cd "$current_dir" || exit 1 # Attempt to return to original directory before failing
    return 1
  fi

  log_info "Starting uvicorn server in the background..."
  # Ensure uvicorn is runnable (should be if install succeeded)
  # Pass FRONTEND_PORT as env var so backend CORS can use it
  export FRONTEND_PORT # Make shell variable available to subprocess
  # Redirect uvicorn output to a log file for easier debugging
  local backend_log_file="logs/backend_run.log"
  log_info "Redirecting backend stdout/stderr to $backend_log_file"

  # --- Ensure log directory exists ---
  mkdir -p "$(dirname "$backend_log_file")" || { log_error "Failed to create log directory $(pwd)/logs"; deactivate &> /dev/null; cd "$current_dir" || exit 1; return 1; }
  # -----------------------------------

  # Use --log-level info for uvicorn logging
  # Ensure the main:app module can be found (relative to BACKEND_DIR)
  # Check if watchfiles is needed/installed for --reload with older uvicorn
  # If reload fails, remove --reload or install watchfiles==<compatible_version>
  uvicorn main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload --log-level info > "$backend_log_file" 2>&1 &
  BACKEND_PID=$!
  log_info "Backend process started with PID: $BACKEND_PID"

  # Check if process started successfully (basic check)
  sleep 3 # Give it a bit more time to start or fail
  if ! ps -p $BACKEND_PID > /dev/null; then
      log_error "Backend process (PID: $BACKEND_PID) failed to start or exited quickly."
      log_error "Check logs in $ABS_BACKEND_DIR/$backend_log_file for details."
      # Deactivate might fail if activation failed, but try anyway
      deactivate &> /dev/null
      cd "$current_dir" || exit 1
      return 1
  fi

  # Deactivate environment after starting the background process
  deactivate
  log_info "Virtual environment deactivated (backend process continues)."

  # Return to the original directory
  if ! cd "$current_dir"; then
      log_error "Failed to return to original directory '$current_dir' after starting backend."
      # Don't exit here, backend might be running, but the script state is inconsistent
      return 1 # Indicate potential issue
  fi
  return 0 # Success
}

function run_frontend {
  log_info "Starting AGENTIC frontend (Node.js) server on http://localhost:$FRONTEND_PORT..."
  # Store current directory
  local current_dir
  current_dir=$(pwd)
  # Use explicit absolute path for cd
  if ! cd "$ABS_FRONTEND_DIR"; then
      log_error "Failed to cd to frontend directory '$ABS_FRONTEND_DIR' to start server."
      return 1 # Cannot start if not in correct directory
  fi

  log_info "Starting Node.js server (server.js) in the background..."
  # Check if server.js exists in the CURRENT directory (which is now $ABS_FRONTEND_DIR)
  if [ ! -f "server.js" ]; then
      log_error "Frontend server file 'server.js' not found in $(pwd)." # pwd is now $ABS_FRONTEND_DIR
      cd "$current_dir" || exit 1
      return 1
  fi

  # Pass relevant ports as environment variables to the Node process
  export FRONTEND_PORT
  export BACKEND_PORT
  # Redirect node output to a log file
  # Place log in the project root directory for easier access
  # Use PROJECT_ROOT which was determined at the start
  local frontend_log_file="$PROJECT_ROOT/frontend_run.log"
  log_info "Redirecting frontend stdout/stderr to $frontend_log_file"
  node "server.js" > "$frontend_log_file" 2>&1 &
  FRONTEND_PID=$!
  log_info "Frontend process started with PID: $FRONTEND_PID"

  # Basic check if process started
  sleep 2
  if ! ps -p $FRONTEND_PID > /dev/null; then
      log_error "Frontend process (PID: $FRONTEND_PID) failed to start or exited quickly."
      log_error "Check logs in $frontend_log_file for details."
      cd "$current_dir" || exit 1
      return 1
  fi

  # Return to the original directory
  if ! cd "$current_dir"; then
      log_error "Failed to return to original directory '$current_dir' after starting frontend."
      # Log and indicate potential issue
      return 1
  fi
  return 0 # Success
}


# --- Cleanup Function ---
BACKEND_PID="" # Initialize PID variables globally
FRONTEND_PID=""

function stop_processes {
  log_info "Initiating shutdown..."
  if [ -n "$BACKEND_PID" ]; then
    # Check if the process actually exists before trying to kill
    if ps -p "$BACKEND_PID" > /dev/null; then
        log_info "Stopping backend process (PID: $BACKEND_PID)..."
        # Try graceful termination first (SIGTERM), then force kill (SIGKILL)
        kill "$BACKEND_PID" 2>/dev/null
        sleep 2 # Give it time to shut down
        if ps -p "$BACKEND_PID" > /dev/null; then
            log_info "Backend process $BACKEND_PID did not stop gracefully, forcing kill..."
            kill -9 "$BACKEND_PID" 2>/dev/null
        else
            log_info "Backend process $BACKEND_PID stopped."
        fi
    else
        log_info "Backend process $BACKEND_PID already stopped."
    fi
    BACKEND_PID="" # Clear PID after attempting to stop
  else
      log_info "Backend PID not set, skipping kill."
  fi

  if [ -n "$FRONTEND_PID" ]; then
     if ps -p "$FRONTEND_PID" > /dev/null; then
        log_info "Stopping frontend process (PID: $FRONTEND_PID)..."
        kill "$FRONTEND_PID" 2>/dev/null
        sleep 1
         if ps -p "$FRONTEND_PID" > /dev/null; then
            log_info "Frontend process $FRONTEND_PID did not stop gracefully, forcing kill..."
            kill -9 "$FRONTEND_PID" 2>/dev/null
         else
            log_info "Frontend process $FRONTEND_PID stopped."
         fi
     else
        log_info "Frontend process $FRONTEND_PID already stopped."
     fi
     FRONTEND_PID="" # Clear PID
  else
      log_info "Frontend PID not set, skipping kill."
  fi
  log_info "Shutdown complete."
  # Exit the script cleanly after trap handler finishes
  exit 0
}

# --- Main Script ---

log_info "Starting AGENTIC v1.0.0 deployment as AUGMENTIC..."

# Set trap to call stop_processes on script exit signals
# EXIT signal ensures cleanup even on normal script termination or error exit
trap stop_processes SIGINT SIGTERM EXIT

# Check for required base commands
check_command python3
check_command pip # pip often comes with python3, but check is good
check_command node
check_command npm
# check_command uvicorn # Uvicorn will be installed in venv, check might fail globally

# Directory creation is handled within install functions now, ensuring atomicity

# Install backend dependencies and create files
install_backend_dependencies || { log_error "Backend setup failed. Exiting."; exit 1; } # Exit if setup fails

# Install frontend dependencies and create files
install_frontend_dependencies || { log_error "Frontend setup failed. Exiting."; exit 1; } # Exit if setup fails

# Clear PIDs before running
BACKEND_PID=""
FRONTEND_PID=""

# Run backend and frontend in the background
run_backend || { log_error "Failed to start backend server. Exiting."; exit 1; } # Exit if run fails
run_frontend || { log_error "Failed to start frontend server. Exiting."; exit 1; } # Exit if run fails

log_info "--- AGENTIC v1.0.0 Deployed Successfully ---"
log_info "Backend running on: http://localhost:$BACKEND_PORT (PID: $BACKEND_PID)"
log_info "Frontend running on: http://localhost:$FRONTEND_PORT (PID: $FRONTEND_PID)"
log_info "Backend logs: $ABS_BACKEND_DIR/logs/backend_run.log"
log_info "Frontend logs: $PROJECT_ROOT/frontend_run.log" # Use PROJECT_ROOT for frontend log path
log_info "Press Ctrl+C to stop both servers."

# Keep the script running to manage background processes
# The trap will handle cleanup on exit.
# 'wait' waits for all background jobs started by this script.
# If any background job exits, wait returns. Use infinite loop if needed.
log_info "Script running in foreground, waiting for termination signal (Ctrl+C)..."
wait

# This part is usually not reached if using 'wait' and Ctrl+C (trap handles exit),
# but might be reached if background processes exit on their own.
log_info "Script finished (wait command exited or background process terminated)."
