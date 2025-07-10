#!/usr/bin/env zsh
#
# ollama-client.zsh - API client for Ollama
#

# Send a prompt to Ollama and get the response
# Usage: zshai_ollama_generate "prompt" "model"
zshai_ollama_generate() {
  local prompt="$1"
  local model="${2:-$ZSHAI_DEFAULT_MODEL}"
  local api_url="${ZSHAI_OLLAMA_API_URL:-http://localhost:11434/api/generate}"
  local temp="${ZSHAI_TEMPERATURE:-0.7}"
  
  # Use jq to properly escape JSON if available, otherwise use a more robust sed approach
  local json_payload
  if command -v jq >/dev/null 2>&1; then
    # Use jq for proper JSON encoding
    json_payload=$(jq -n \
      --arg model "$model" \
      --arg prompt "$prompt" \
      --argjson temp "$temp" \
      '{
        model: $model,
        prompt: $prompt,
        temperature: $temp,
        stream: false,
        options: {
          num_predict: 256,
          top_k: 40,
          top_p: 0.9
        }
      }')
  else
    # Fallback: more robust escaping for JSON
    local escaped_prompt=$(printf '%s' "$prompt" | \
      sed 's/\\/\\\\/g' | \
      sed 's/"/\\"/g' | \
      sed 's/$/\\n/' | \
      tr -d '\n' | \
      sed 's/\\n$//')
    
    json_payload=$(cat <<EOF
{
  "model": "$model",
  "prompt": "$escaped_prompt",
  "temperature": $temp,
  "stream": false,
  "options": {
    "num_predict": 256,
    "top_k": 40,
    "top_p": 0.9
  }
}
EOF
)
  fi

  # Debug: Show the JSON payload if verbose
  if [[ "$ZSHAI_VERBOSE" == "true" ]]; then
    echo "🔍 DEBUG: JSON payload:" >&2
    echo "$json_payload" >&2
    echo "" >&2
  fi
  
  # Make the API request with timeout
  local response
  response=$(curl -s --max-time 30 -X POST "$api_url" \
    -H "Content-Type: application/json" \
    -d "$json_payload" 2>/dev/null)
  
  # Check for curl errors
  local curl_exit_code=$?
  if [[ $curl_exit_code -ne 0 ]]; then
    case $curl_exit_code in
      28) echo "Error: Request timed out. Ollama may be busy or unresponsive." ;;
      7)  echo "Error: Failed to connect to Ollama API at $api_url" ;;
      *)  echo "Error: Failed to communicate with Ollama API (exit code: $curl_exit_code)" ;;
    esac
    return 1
  fi
  
  # Check if response is empty
  if [[ -z "$response" ]]; then
    echo "Error: Empty response from Ollama API"
    return 1
  fi
  
  # Check for API errors in response
  if echo "$response" | grep -q '"error"'; then
    local error_msg=$(echo "$response" | grep -o '"error":"[^"]*"' | sed 's/"error":"//;s/"//')
    echo "Error from Ollama: $error_msg"
    return 1
  fi
  
  # Extract the response text with better JSON parsing
  local generated_text
  if command -v jq >/dev/null 2>&1; then
    # Use jq if available for proper JSON parsing
    generated_text=$(echo "$response" | jq -r '.response // empty' 2>/dev/null)
  else
    # Fallback to sed-based parsing
    generated_text=$(echo "$response" | grep -o '"response":"[^"]*"' | sed 's/"response":"//;s/"//' | sed 's/\\n/\n/g' | sed 's/\\r/\r/g' | sed 's/\\t/\t/g')
  fi
  
  # Check if we got a response
  if [[ -z "$generated_text" ]]; then
    echo "Error: No response text found in API response"
    return 1
  fi
  
  echo "$generated_text"
}

# List available models from Ollama
zshai_list_models() {
  local api_url="${ZSHAI_OLLAMA_API_URL%/api/generate}/api/tags"
  
  # Make the API request
  local response
  response=$(curl -s --max-time 10 "$api_url" 2>/dev/null)
  
  # Check for errors
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to connect to Ollama API"
    return 1
  fi
  
  # Check if response is empty
  if [[ -z "$response" ]]; then
    echo "Error: Empty response from Ollama API"
    return 1
  fi
  
  # Extract and display model names
  echo "Available models:"
  if command -v jq >/dev/null 2>&1; then
    # Use jq if available for proper JSON parsing
    echo "$response" | jq -r '.models[]?.name // empty' 2>/dev/null | while read -r model; do
      if [[ "$model" == "$ZSHAI_DEFAULT_MODEL" ]]; then
        echo "  $(zshai_colorize "$model" "green") (default)"
      else
        echo "  $model"
      fi
    done
  else
    # Fallback to sed-based parsing
    echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' | while read -r model; do
      if [[ "$model" == "$ZSHAI_DEFAULT_MODEL" ]]; then
        echo "  $(zshai_colorize "$model" "green") (default)"
      else
        echo "  $model"
      fi
    done
  fi
}

# Check if Ollama is running
zshai_check_ollama() {
  local api_url="${ZSHAI_OLLAMA_API_URL%/api/generate}/api/tags"
  
  # Try to connect to the API with a short timeout
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$api_url" 2>/dev/null)
  
  # Check if we got a successful response
  if [[ "$http_code" == "200" ]]; then
    return 0
  else
    return 1
  fi
}

# Check if a specific model is available
zshai_check_model() {
  local model="$1"
  
  if [[ -z "$model" ]]; then
    echo "Usage: zshai_check_model <model_name>"
    return 1
  fi
  
  # Get list of models and check if the specified model exists
  local models
  models=$(zshai_list_models 2>/dev/null | grep -v "Available models:" | sed 's/^[[:space:]]*//' | sed 's/ (default)$//' | sed 's/\x1b\[[0-9;]*m//g')
  
  # Debug logging (only when verbose mode is enabled)
  if [[ "$ZSHAI_VERBOSE" == "true" ]]; then
    echo "🔍 DEBUG: Looking for model: '$model'"
    echo "🔍 DEBUG: Available models from API:"
    echo "$models" | while read -r line; do
      echo "🔍 DEBUG:   '$line'"
    done
  fi
  
  # Escape special regex characters in the model name
  local escaped_model=$(echo "$model" | sed 's/[[\.*^$()+?{|]/\\&/g')
  if [[ "$ZSHAI_VERBOSE" == "true" ]]; then
    echo "🔍 DEBUG: Escaped model pattern: '^$escaped_model$'"
  fi
  
  if echo "$models" | grep -q "^$escaped_model$"; then
    echo "✅ Model '$model' is available"
    return 0
  else
    echo "❌ Model '$model' is not available"
    echo ""
    echo "Available models:"
    echo "$models"
    echo ""
    echo "To pull a model, run: ollama pull $model"
    return 1
  fi
}

# Pull a model using Ollama CLI
zshai_pull_model() {
  local model="$1"
  
  if [[ -z "$model" ]]; then
    echo "Usage: zshai_pull_model <model_name>"
    return 1
  fi
  
  # Check if ollama CLI is available
  if ! command -v ollama &> /dev/null; then
    echo "Error: Ollama CLI is not installed or not in PATH"
    return 1
  fi
  
  echo "Pulling model '$model'..."
  ollama pull "$model"
}

# Test the connection to Ollama with a simple prompt
zshai_test_connection() {
  local model="${1:-$ZSHAI_DEFAULT_MODEL}"
  
  echo "Testing connection to Ollama..."
  echo "Model: $model"
  echo "API URL: $ZSHAI_OLLAMA_API_URL"
  echo ""
  
  # Check if Ollama is running
  if ! zshai_check_ollama; then
    echo "❌ Ollama is not running or not accessible"
    echo "Please start Ollama with: ollama serve"
    return 1
  fi
  
  echo "✅ Ollama is running"
  
  # Check if model is available
  if ! zshai_check_model "$model" >/dev/null 2>&1; then
    echo "❌ Model '$model' is not available"
    return 1
  fi
  
  echo "✅ Model '$model' is available"
  
  # Test with a simple prompt
  echo ""
  echo "Testing with a simple prompt..."
  local test_response
  test_response=$(zshai_ollama_generate "Say 'Hello from zsh-ai!'" "$model")
  
  if [[ $? -eq 0 && -n "$test_response" ]]; then
    echo "✅ Test successful!"
    echo "Response: $test_response"
    return 0
  else
    echo "❌ Test failed"
    return 1
  fi
}