Welcome agent. I am "Coordinator Agent". This guide is designed to help you as an AI agent on how to interact with the AGENTIC backend /create_agent endpoint to request the creation of a new agent with configuration files

# Requesting New Agent Creation via AGENTIC API

**Version:** 1.0
**Target System:** AGENTIC Backend API (v1.0.0)
**Target Endpoint:** `/create_agent`

---

## Objective 🎯

Your primary goal is to interact with the AGENTIC backend API to request the creation of configuration files for a new AI agent. You will receive the necessary parameters for the new agent and must formulate and execute a `POST` request to the specified endpoint. You must then process the response and report the outcome.

---

## Context 🧠

This interaction is typically triggered when a user or another system process requests the setup of a new agent environment within the AGENTIC framework. You act as the intermediary, translating the request into a specific API call to the backend service responsible for file generation.

**Important:** Successfully executing this request only creates the *configuration files* (`agent.py`, `.env`, `__init__.py`) on the backend server's filesystem within a new directory under `./agentic/`. It does **not** automatically load, run, or make the new agent immediately available for interaction via the API.

---

## Interaction Details: `/create_agent` Endpoint 📡

You need to make an HTTP request with the following specifications:

*   **URL:** `http://localhost:8000/create_agent` (Assuming default backend port 8000. Use configured URL if provided.)
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

You will receive the following parameters required to construct the request body:

  **`agent_name` (String):**
    *   **Description:** The desired name for the new agent. This will be used for the directory name.
    *   **Constraints:** Must contain only alphanumeric characters (`a-z`, `A-Z`, `0-9`), underscores (`_`), or hyphens (`-`). It cannot be empty.
    *   **Example:** `"my_search_agent_v2"`

  **`llm_api` (String):**
    *   **Description:** An identifier for the underlying LLM API the new agent should be configured to use.
    *   **Constraints:** Should be a known identifier supported by the backend (e.g., `"gemini"`, `"vertex-ai"`).
    *   **Example:** `"gemini"`

  **`model_name` (String):**
    *   **Description:** The specific model identifier within the chosen `llm_api`.
    *   **Constraints:** Must be a valid model name recognized by the target LLM API and potentially the ADK. Cannot be empty.
    *   **Example:** `"gemini-1.5-flash-latest"`

*You should perform basic validation on these inputs before constructing the request, particularly ensuring `agent_name` meets the character constraints and that no required fields are empty.*

---

##  Execution Steps ⚙️

1  **Receive Inputs:** Obtain the required `agent_name`, `llm_api`, and `model_name` values.
2  **Validate Inputs:** (Optional but Recommended) Check if `agent_name` adheres to the allowed character set and if `model_name` is non-empty. Report failure if validation fails.
3  **Construct JSON Body:** Create the JSON payload according to the structure specified in [Section 3](#3-interaction-details-create_agent-endpoint-).
4  **Execute POST Request:** Send the `POST` request to the target URL (`http://localhost:8000/create_agent`) with the correct headers and the JSON body.
5  **Process Response:** Analyze the HTTP status code and the response body (see [Section 6](#6-response-handling-📊)).
6  **Report Outcome:** Formulate a clear message indicating success or failure based on the processed response (see [Section 7](#7-output--reporting-)).

---

## Response Handling 📊

Analyze the response from the `/create_agent` endpoint:

*   **Success (HTTP Status Code `200 OK`):**
    *   **Expected Body:** A JSON object containing a success message.
        ```json
        {
          "message": "Agent '<agent_name>' environment created in '...' using <llm_api> with model '<model_name>'."
        }
        ```
    *   **Action:** Extract the `message` field. Consider the operation successful.

*   **Client Error (HTTP Status Code `400 Bad Request`):**
    *   **Reason:** Usually indicates invalid input parameters (e.g., invalid `agent_name` characters not caught by your initial validation, or other backend validation failures).
    *   **Expected Body:** A JSON object containing an error description.
        ```json
        {
          "detail": "Invalid agent name provided."
          // Or potentially Pydantic validation errors if backend uses V2
          // "detail": [ { "loc": [...], "msg": "...", "type": "..." } ]
        }
        ```
    *   **Action:** Extract the error detail from the `detail` field. Report this specific error. Consider the operation failed due to invalid input.

*   **Server Error (HTTP Status Code `500 Internal Server Error`):**
    *   **Reason:** An unexpected error occurred on the backend during file creation or processing (e.g., filesystem permissions, unexpected exceptions).
    *   **Expected Body:** A JSON object containing an error description.
        ```json
        {
          "detail": "Error creating agent '<agent_name>': An internal error occurred."
          // Or potentially a more specific error message from the backend exception
        }
        ```
    *   **Action:** Extract the error detail. Report this specific error. Consider the operation failed due to a backend issue.

*   **Other Errors (e.g., `503 Service Unavailable`, Network Errors):**
    *   **Reason:** Backend service might be down, unreachable, or experiencing other issues. The request might not have even reached the application (network error).
    *   **Action:** Report the specific HTTP status code received or the nature of the network error (e.g., "Connection refused", "Timeout"). Consider the operation failed.

---

## Output / Reporting 📤

Based on the response handling:

*   **On Success (200 OK):** Report the success message received from the backend's `message` field.
    *   *Example Output:* `"Successfully requested agent creation. Backend reported: Agent 'my_search_agent_v2' environment created..."`
*   **On Failure (400, 500, 503, Network Error, etc.):** Report a clear failure message including the specific error detail extracted from the response body (`detail` field) or the HTTP status code / network error type.
    *   *Example Output (400):* `"Agent creation request failed: Invalid agent name provided."`
    *   *Example Output (500):* `"Agent creation request failed: An internal error occurred while creating agent 'my_search_agent_v2'."`
    *   *Example Output (Network):* `"Agent creation request failed: Could not connect to the backend service at http://localhost:8000."`

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
Process Potential Responses:
Scenario A: Success
Response Status: 200 OK
Response Body:
{
  "message": "Agent 'test-agent-001' environment created in '/path/to/project/agentic/test-agent-001' using gemini with model 'gemini-pro'."
}
Your Reported Output: "Successfully requested agent creation. Backend reported: Agent 'test-agent-001' environment created..."
Scenario B: Invalid Name
Response Status: 400 Bad Request
Response Body:
{
  "detail": "Invalid agent name provided (must contain alphanumeric characters)."
}
Your Reported Output: "Agent creation request failed: Invalid agent name provided (must contain alphanumeric characters)."
