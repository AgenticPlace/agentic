Welcome agent. I am "Coordinator Agent". This guide is designed to help you as a
n AI agent on how to interact with the AGENTIC backend /create_agent endpoint to
 request the creation of a new agent including agentID with configuration files

# Requesting New Agent Creation via AGENTIC API

**Version:** 1.0
**Target System:** AGENTIC Backend API (v1.0.0)
**Target Endpoint:** `/create_agent`

---

## Objective 🎯

Your primary goal is to interact with the AGENTIC backend API to request the cre
ation of configuration files for a new AI agent. You will receive the necessary
parameters for the new agent and must formulate and execute a `POST` request to
the specified endpoint. You must then process the response and report the outcom
e.

---

## Context 🧠

This interaction is typically triggered when a user or another system process re
quests the setup of a new agent environment within the AGENTIC framework. You ac
t as the intermediary, translating the request into a specific API call to the b
ackend service responsible for file generation.

**Important:** Successfully executing this request only creates the *configurati
on files* (`agent.py`, `.env`, `__init__.py`) on the backend server's filesystem
 within a new directory under `./agentic/`. It does **not** automatically load,
run, or make the new agent immediately available for interaction via the API.

---

## Interaction Details: `/create_agent` Endpoint 📡

You need to make an HTTP request with the following specifications:

*   **URL:** `http://localhost:8000/create_agent` (Assuming default backend port
 8000. Use configured URL if provided.)
*   **Method:** `POST`
*   **Headers:**
    *   `Content-Type`: `application/json`
    *   `Accept`: `application/json` (Indicates you expect a JSON response)
*   **Request Body:** A JSON object containing the details for the new agent.

    ```json
    {
      "agent_name": "<NAME_OF_NEW_AGENT>",
      "llm_api": "<LLM_API_IDENTIFIER>",
      "model_name": "<SPECIFIC_MODEL_NAME>"
    }
    ```

---

## Input Parameters 📥

You will receive the following parameters required to construct the request body
:

  **`agent_name` (String):**
    *   **Description:** The desired name for the new agent. This will be used f
or the directory name.
    *   **Constraints:** Must contain only alphanumeric characters (`a-z`, `A-Z`
, `0-9`), underscores (`_`), or hyphens (`-`). It cannot be empty.
    *   **Example:** `"my_search_agent_v2"`

  **`llm_api` (String):**
    *   **Description:** An identifier for the underlying LLM API the new agent
should be configured to use.
    *   **Constraints:** Should be a known identifier supported by the backend (
e.g., `"gemini"`, `"vertex-ai"`).
    *   **Example:** `"gemini"`

  **`model_name` (String):**
    *   **Description:** The specific model identifier within the chosen `llm_ap
i`.
    *   **Constraints:** Must be a valid model name recognized by the target LLM
 API and potentially the ADK. Cannot be empty.
    *   **Example:** `"gemini-1.5-flash-latest"`

*You should perform basic validation on these inputs before constructing the req
uest, particularly ensuring `agent_name` meets the character constraints and tha
t no required fields are empty.*

---

##  Execution Steps ⚙️

1  **Receive Inputs:** Obtain the required `agent_name`, `llm_api`, and `model_n
ame` values.
2  **Validate Inputs:** (Optional but Recommended) Check if `agent_name` adheres
 to the allowed character set and if `model_name` is non-empty. Report failure i
f validation fails.
3  **Construct JSON Body:** Create the JSON payload according to the structure s
pecified in [Section 3](#3-interaction-details-create_agent-endpoint-).
4  **Execute POST Request:** Send the `POST` request to the target URL (`http://
localhost:8000/create_agent`) with the correct headers and the JSON body.
5  **Process Response:** Analyze the HTTP status code and the response body (see
 [Section 6](#6-response-handling-)).
6  **Report Outcome:** Formulate a clear message indicating success or failure b
ased on the processed response (see [Section 7](#7-output--reporting-)).

---

## Response Handling 📊

Analyze the response from the `/create_agent` endpoint:

*   **Success (HTTP Status Code `200 OK`):**
    *   **Expected Body:** A JSON object containing a success message.
        ```json
        {
          "message": "Agent '<agent_name>' environment created in '...' using <l
lm_api> with model '<model_name>'."
        }
        ```
    *   **Action:** Extract the `message` field. Consider the operation successf
ul.

*   **Client Error (HTTP Status Code `400 Bad Request`):**
    *   **Reason:** Usually indicates invalid input parameters (e.g., invalid `a
gent_name` characters not caught by your initial validation, or other backend va
lidation failures).
    *   **Expected Body:** A JSON object containing an error description.
        ```json
        {
          "detail": "Invalid agent name provided."
          // Or potentially Pydantic validation errors if backend uses V2
          // "detail": [ { "loc": [...], "msg": "...", "type": "..." } ]
        }
        ```
    *   **Action:** Extract the error detail from the `detail` field. Report thi
s specific error. Consider the operation failed due to invalid input.

*   **Server Error (HTTP Status Code `500 Internal Server Error`):**
    *   **Reason:** An unexpected error occurred on the backend during file crea
tion or processing (e.g., filesystem permissions, unexpected exceptions).
    *   **Expected Body:** A JSON object containing an error description.
        ```json
        {
          "detail": "Error creating agent '<agent_name>': An internal error occu
rred."
          // Or potentially a more specific error message from the backend excep
tion
        }
        ```
    *   **Action:** Extract the error detail. Report this specific error. Consid
er the operation failed due to a backend issue.

*   **Other Errors (e.g., `503 Service Unavailable`, Network Errors):**
    *   **Reason:** Backend service might be down, unreachable, or experiencing
other issues. The request might not have even reached the application (network e
rror).
    *   **Action:** Report the specific HTTP status code received or the nature
of the network error (e.g., "Connection refused", "Timeout"). Consider the opera
tion failed.

---

## Output / Reporting 📤

Based on the response handling:

*   **On Success (200 OK):** Report the success message received from the backen
d's `message` field.
    *   *Example Output:* `"Successfully requested agent creation. Backend repor
ted: Agent 'my_search_agent_v2' environment created..."`
*   **On Failure (400, 500, 503, Network Error, etc.):** Report a clear failure
message including the specific error detail extracted from the response body (`d
etail` field) or the HTTP status code / network error type.
    *   *Example Output (400):* `"Agent creation request failed: Invalid agent n
ame provided."`
    *   *Example Output (500):* `"Agent creation request failed: An internal err
or occurred while creating agent 'my_search_agent_v2'."`
    *   *Example Output (Network):* `"Agent creation request failed: Could not c
onnect to the backend service at http://localhost:8000."`

---

## Example Interaction 📝

**Inputs Received:**
*   `agent_name`: `"test-agent-001"`
*   `llm_api`: `"gemini"`
*   `model_name`: `"gemini-pro"`

** Construct Request:**

```http
POST http://localhost:8000/create_agent HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "agent_name": "test-agent-001",
  "llm_api": "gemini",
  "model_name": "gemini-pro"
}
```

**Process Potential Responses:**

**Scenario A: Success**
*Response Status:* `200 OK`
*Response Body:*
```json
{
  "message": "Agent 'test-agent-001' environment created in '/path/to/project/ag
entic/test-agent-001' using gemini with model 'gemini-pro'."
}
```
*Your Reported Output:* `"Successfully requested agent creation. Backend reported:
Agent 'test-agent-001' environment created..."`

**Scenario B: Invalid Name**
*Response Status:* `400 Bad Request`
*Response Body:*
```json
{
  "detail": "Invalid agent name provided (must contain alphanumeric characters)."
}
```
*Your Reported Output:* `"Agent creation request failed: Invalid agent name provide
d (must contain alphanumeric characters)."`
---

## Interaction: Triggering mindX Evolution (`/mindx/evolve/`) 🧠 evolvinator -> AGENTIC AI

This section details how to interact with the integrated mindX `MastermindAgent` to trigger evolutionary processes via the AGENTIC UI and its backend API.

### Objective 🎯

To submit a high-level directive to the mindX `MastermindAgent` for processing and receive the outcome of its evolutionary campaign. This interaction is primarily initiated through the AGENTIC web UI, which then calls the backend API.

### Context 🧠

The mindX integration allows users to leverage complex AI-driven strategic planning and execution capabilities of the `MastermindAgent`. When a directive is submitted, the `MastermindAgent` (running within the AGENTIC backend environment) undertakes a series of actions, potentially involving its BDI (Belief-Desire-Intention) reasoning cycle, interaction with other mindX agents (like Coordinator, Memory, etc.), and use of its configured tools or capabilities. The result is a report on the campaign's outcome.

**Important:** This is an asynchronous-style interaction from the user's perspective. The complexity and duration of mindX's processing will vary based on the directive. The API call itself will be synchronous, but the underlying mindX task might be long-running in a more advanced implementation (though the current `manage_mindx_evolution` call is awaited).

### UI Interaction (via AGENTIC Frontend) 🖥️

The AGENTIC web UI (accessible at `http://localhost:3000` by default) provides the following elements for mindX interaction:

1.  **Section Title:** "Interact with mindX (via Mastermind)"
2.  **Directive Input:**
    *   **Label:** "Directive for mindX:"
    *   **Textarea (id: `mindXDirectiveInput`):** A multi-line text area where you can type or paste the high-level directive for mindX.
3.  **Button (id: `evolveMindXButton`):** "Evolve mindX"
    *   Clicking this button submits the directive to the AGENTIC backend.
4.  **Status Message (id: `mindXStatus`):** A paragraph that displays the status of the request (e.g., "Processing mindX directive...", success messages, or error messages).
5.  **Response Output (id: `mindXResponseOutput`):** A `<pre>` formatted area that displays the JSON response received from the backend after mindX processing is complete.

**Typical UI Flow:**
1.  Navigate to the AGENTIC web UI.
2.  Locate the "Interact with mindX" section.
3.  Enter your desired directive into the textarea.
4.  Click the "Evolve mindX" button.
5.  Observe status updates and the final JSON response in their respective areas.

### API Interaction Details: `/mindx/evolve/` Endpoint 📡

The AGENTIC UI interacts with the backend via the following API endpoint:

*   **URL:** `http://localhost:8000/mindx/evolve/` (Assuming default backend port 8000. Use configured URL if provided.)
*   **Method:** `POST`
*   **Headers:**
    *   `Content-Type`: `application/json`
    *   `Accept`: `application/json`
*   **Request Body:** A JSON object containing the directive.

    ```json
    {
      "directive": "<USER_PROVIDED_DIRECTIVE_STRING>"
    }
    ```

### Input Parameters (for the API call) 📥

*   **`directive` (String):**
    *   **Description:** The high-level directive or goal for the mindX `MastermindAgent` to process.
    *   **Constraints:** Must be a non-empty string.
    *   **Example:** `"Analyze the current codebase for potential new tools and conceptualize one."`

### Response Handling (from `/mindx/evolve/`) 📊

The API endpoint will return a JSON response based on the outcome of the mindX processing.

*   **Success (HTTP Status Code `200 OK`):**
    *   **Expected Body (`MindXEvolutionResponse` model):**
        ```json
        {
          "status": "completed" | "failed_or_incomplete" | "unknown",
          "message": "mindX evolution campaign finished with status: <campaign_status>",
          "details": {
            "overall_campaign_status": "SUCCESS" | "FAILURE_OR_INCOMPLETE",
            "final_bdi_message": "...",
            // ... other details from mindX's manage_mindx_evolution result ...
          }
        }
        ```
    *   **`status` field:** A simplified status for the UI (e.g., "completed").
    *   **`message` field:** A human-readable summary message.
    *   **`details` field:** The detailed JSON object returned by `MastermindAgent.manage_mindx_evolution()`.
    *   **Action:** Interpret the `status` and `message`. Display the `details` for the user to inspect.

*   **Client Error (HTTP Status Code `422 Unprocessable Entity`):**
    *   **Reason:** The request body (e.g., missing `directive`) failed Pydantic validation.
    *   **Expected Body:** Standard FastAPI validation error response.
    *   **Action:** Report the validation error.

*   **Service Unavailable (HTTP Status Code `503 Service Unavailable`):**
    *   **Reason:** mindX components were not available or failed to initialize in the backend.
    *   **Expected Body:**
        ```json
        {
          "detail": "mindX integration is currently unavailable. Check backend logs."
        }
        ```
    *   **Action:** Report that the mindX service is unavailable.

*   **Server Error (HTTP Status Code `500 Internal Server Error`):**
    *   **Reason:** An unexpected error occurred in the backend while processing the mindX directive.
    *   **Expected Body:**
        ```json
        {
          "detail": "An internal error occurred while processing your mindX request: <error_details>"
        }
        ```
    *   **Action:** Report the internal server error.

### Example API Interaction (Conceptual) 📝

**Request:**
```http
POST http://localhost:8000/mindx/evolve/ HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "directive": "Develop a strategy for improving tool discovery."
}
```

**Potential Success Response (200 OK):**
```json
{
  "status": "completed",
  "message": "mindX evolution campaign finished with status: SUCCESS",
  "details": {
    "overall_campaign_status": "SUCCESS",
    "final_bdi_message": "COMPLETED_GOAL_ACHIEVED: Strategy for tool discovery developed and logged.",
    "run_id": "mastermind_run_xxxx",
    "directive": "Develop a strategy for improving tool discovery."
    // ... other mindX specific details ...
  }
}
```

**Potential Error Response (503 Service Unavailable):**
```json
{
  "detail": "mindX integration is currently unavailable. Check backend logs."
}
```
