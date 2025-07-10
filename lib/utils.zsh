#!/usr/bin/env zsh
#
# utils.zsh - Utility functions
#

# Debug logging function
zshai_log() {
  local level="$1"
  local message="$2"
  
  # Only show debug logs if verbose mode is enabled
  if [[ "$level" == "DEBUG" && "$ZSHAI_VERBOSE" != "true" ]]; then
    return
  fi
  
  # Color code based on level
  case "$level" in
    "ERROR") echo "$(zshai_colorize "❌ ERROR:" "red") $message" ;;
    "WARN")  echo "$(zshai_colorize "⚠️  WARN:" "yellow") $message" ;;
    "INFO")  echo "$(zshai_colorize "ℹ️  INFO:" "blue") $message" ;;
    "DEBUG") echo "$(zshai_colorize "🔍 DEBUG:" "cyan") $message" ;;
    *)       echo "$message" ;;
  esac
}

# Print usage information
zshai_print_usage() {
  cat <<EOF
Usage: ai <natural language query>
       aiexplain <command>
       ai-config [set <key> <value>|get <key>|test|models|safety|history]

Examples:
  ai "list all files sorted by size"
  ai "find all python files modified in the last week"
  aiexplain "find . -type f -exec du -h {} \\; | sort -h"
  ai-config set DEFAULT_MODEL "codellama"
  ai-config get SAFETY_LEVEL
  ai-config test
  ai-config models
  ai-config safety high
  ai-config history 20

Aliases:
  aiexplain   # Same as zshai_explain
  aiconfig    # Same as ai-config

Key bindings:
  Ctrl+X, Ctrl+A  # Convert current buffer to command

Configuration:
  Config file: $ZSHAI_USER_CONFIG
  History file: $ZSHAI_HISTORY_FILE

For more help, visit: https://github.com/your-username/zsh-ai
EOF
}

# Process a natural language query
zshai_process_query() {
  local query="$1"
  local model="$(zshai_get_config DEFAULT_MODEL)"
  
  # Debug logging
  zshai_log "DEBUG" "Processing query: $query"
  zshai_log "DEBUG" "Using model: $model"
  zshai_log "DEBUG" "Ollama API URL: $ZSHAI_OLLAMA_API_URL"
  
  # Validate input
  if [[ -z "$query" ]]; then
    zshai_error "No query provided"
    return 1
  fi
  
  # Check if Ollama is running
  zshai_log "DEBUG" "Checking if Ollama is running..."
  if ! zshai_check_ollama; then
    zshai_error "Ollama is not running. Please start it with 'ollama serve'"
    echo ""
    echo "To start Ollama:"
    echo "  1. Run: $(zshai_colorize "ollama serve" "green")"
    echo "  2. In another terminal, test with: $(zshai_colorize "ai-config test" "green")"
    return 1
  fi
  zshai_log "DEBUG" "✅ Ollama is running"
  
  # Check if model is available
  zshai_log "DEBUG" "Checking if model '$model' is available..."
  if ! zshai_check_model "$model" >/dev/null 2>&1; then
    zshai_error "Model '$model' is not available"
    echo ""
    echo "To install the model:"
    echo "  $(zshai_colorize "ollama pull $model" "green")"
    echo ""
    echo "Or choose a different model:"
    echo "  $(zshai_colorize "ai-config models" "green")"
    echo "  $(zshai_colorize "ai-config set DEFAULT_MODEL <model_name>" "green")"
    return 1
  fi
  zshai_log "DEBUG" "✅ Model '$model' is available"
  
  # Get command context from history if enabled
  local context=""
  if [[ "$(zshai_get_config HISTORY_ENABLED)" == "true" ]]; then
    context=$(zshai_get_history_context)
  fi
  
  # Generate the prompt with context awareness
  local prompt
  if [[ -n "$context" ]]; then
    prompt=$(zshai_generate_command_prompt "$query" "$context")
  else
    # Use contextual prompt that considers current directory and environment
    prompt=$(zshai_generate_contextual_prompt "$query")
  fi
  
  # Get command from Ollama
  echo "🤔 Thinking..."
  local command=$(zshai_ollama_generate "$prompt" "$model")
  
  # Check if command is empty
  if [[ -z "$command" ]]; then
    zshai_error "Failed to generate command"
    return 1
  fi
  
  # Clean up the command (remove any extra whitespace or formatting)
  command=$(zshai_clean_command "$command")
  
  # Check if command is still empty after cleaning
  if [[ -z "$command" ]]; then
    zshai_error "Generated command is empty after cleaning"
    return 1
  fi
  
  # Log the generated command if verbose
  zshai_log "INFO" "Generated command: $command"
  
  # Validate the command and get confirmation if needed
  if zshai_check_and_confirm "$command"; then
    # Print the command with formatting
    echo ""
    echo "💻 Generated command:"
    echo "$(zshai_format_command "$command")"
    echo ""
    
    # Add to history if enabled (before execution)
    if [[ "$(zshai_get_config HISTORY_ENABLED)" == "true" ]]; then
      zshai_add_to_history "$query" "$command"
    fi
    
    # Ask for confirmation before executing
    echo -n "Execute this command? [y/N] "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      echo ""
      zshai_info "Executing command..."
      
      # Execute the command and capture the exit code
      eval "$command"
      local exit_code=$?
      
      if [[ $exit_code -eq 0 ]]; then
        zshai_success "Command executed successfully"
      else
        zshai_warn "Command exited with code $exit_code"
      fi
    else
      echo "Command not executed."
    fi
  fi
}

# Get explanation for a command
zshai_get_explanation() {
  local command="$1"
  local model="$(zshai_get_config DEFAULT_MODEL)"
  
  # Validate input
  if [[ -z "$command" ]]; then
    zshai_error "No command provided for explanation"
    return 1
  fi
  
  # Check if Ollama is running
  if ! zshai_check_ollama; then
    zshai_error "Ollama is not running. Please start it with 'ollama serve'"
    return 1
  fi
  
  # Check if model is available
  if ! zshai_check_model "$model" >/dev/null 2>&1; then
    zshai_error "Model '$model' is not available. Run 'ai-config models' to see available models."
    return 1
  fi
  
  # Generate the prompt
  local prompt=$(zshai_generate_explanation_prompt "$command")
  
  # Get explanation from Ollama
  zshai_info "Analyzing command..."
  local explanation=$(zshai_ollama_generate "$prompt" "$model")
  
  # Check if explanation is empty
  if [[ -z "$explanation" ]]; then
    zshai_error "Failed to generate explanation"
    return 1
  fi
  
  # Print the explanation with formatting
  echo ""
  echo "📖 Command Explanation:"
  echo "$(zshai_format_command "$command" "blue")"
  echo ""
  echo "$explanation"
  echo ""
}

# Add a query and command to history
zshai_add_to_history() {
  local query="$1"
  local command="$2"
  local max_history="$(zshai_get_config MAX_HISTORY)"
  
  # Format: timestamp|query|command
  local entry="$(date +%s)|$query|$command"
  
  # Add to history file
  echo "$entry" >> "$ZSHAI_HISTORY_FILE"
  
  # Trim history if it exceeds max size
  if [[ $(wc -l < "$ZSHAI_HISTORY_FILE") -gt $max_history ]]; then
    tail -n $max_history "$ZSHAI_HISTORY_FILE" > "${ZSHAI_HISTORY_FILE}.tmp"
    mv "${ZSHAI_HISTORY_FILE}.tmp" "$ZSHAI_HISTORY_FILE"
  fi
}

# Get context from command history
zshai_get_history_context() {
  local max_entries=5
  local context=""
  
  # Get recent history entries
  if [[ -f "$ZSHAI_HISTORY_FILE" ]]; then
    context=$(tail -n $max_entries "$ZSHAI_HISTORY_FILE" | while IFS="|" read -r timestamp query command; do
      echo "Previous query: $query"
      echo "Previous command: $command"
      echo ""
    done)
  fi
  
  echo "$context"
}

# Format output with colors
zshai_colorize() {
  local text="$1"
  local color="$2"
  
  case "$color" in
    red)    echo "\033[31m$text\033[0m" ;;
    green)  echo "\033[32m$text\033[0m" ;;
    yellow) echo "\033[33m$text\033[0m" ;;
    blue)   echo "\033[34m$text\033[0m" ;;
    cyan)   echo "\033[36m$text\033[0m" ;;
    *)      echo "$text" ;;
  esac
}

# Check if a command exists
zshai_command_exists() {
  command -v "$1" >/dev/null 2>&1
}


# Error logging
zshai_error() {
  local message="$1"
  echo "$(zshai_colorize "❌ Error: $message" "red")" >&2
  zshai_log "ERROR" "$message"
}

# Warning logging
zshai_warn() {
  local message="$1"
  echo "$(zshai_colorize "⚠️  Warning: $message" "yellow")" >&2
  zshai_log "WARN" "$message"
}

# Info logging
zshai_info() {
  local message="$1"
  echo "$(zshai_colorize "ℹ️  $message" "blue")"
  zshai_log "INFO" "$message"
}

# Success logging
zshai_success() {
  local message="$1"
  echo "$(zshai_colorize "✅ $message" "green")"
  zshai_log "SUCCESS" "$message"
}

# Spinner for long-running operations
zshai_spinner() {
  local pid=$1
  local message="${2:-Processing...}"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  
  echo -n "$message "
  while kill -0 $pid 2>/dev/null; do
    printf "\b${spin:$i:1}"
    i=$(( (i+1) % ${#spin} ))
    sleep 0.1
  done
  printf "\b✓\n"
}

# Clean up command output (remove extra whitespace, quotes, etc.)
zshai_clean_command() {
  local cmd="$1"
  
  # Remove leading/trailing whitespace
  cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Remove markdown code block formatting if present
  cmd=$(echo "$cmd" | sed 's/^```[a-z]*//;s/```$//')
  
  # Remove backticks if the entire command is wrapped
  if [[ "$cmd" =~ ^\`.*\`$ ]]; then
    cmd=$(echo "$cmd" | sed 's/^`//;s/`$//')
  fi
  
  # Remove quotes if the entire command is wrapped
  if [[ "$cmd" =~ ^\".*\"$ ]]; then
    cmd=$(echo "$cmd" | sed 's/^"//;s/"$//')
  fi
  
  echo "$cmd"
}

# Format command for display
zshai_format_command() {
  local cmd="$1"
  local color="${2:-green}"
  
  echo "$(zshai_colorize "$cmd" "$color")"
}

# Check if we're in a git repository and get status
zshai_get_git_context() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local status=$(git status --porcelain 2>/dev/null | wc -l)
    echo "Git repository (branch: $branch, modified files: $status)"
  fi
}

# Get current directory context for prompts
zshai_get_directory_context() {
  local pwd_info="$(pwd)"
  local file_count=$(ls -1 2>/dev/null | wc -l)
  local dir_type=""
  
  # Detect project type
  if [[ -f "package.json" ]]; then
    dir_type="Node.js project"
  elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
    dir_type="Python project"
  elif [[ -f "Cargo.toml" ]]; then
    dir_type="Rust project"
  elif [[ -f "go.mod" ]]; then
    dir_type="Go project"
  elif [[ -f "Makefile" ]]; then
    dir_type="Project with Makefile"
  elif [[ -f ".git" ]] || [[ -d ".git" ]]; then
    dir_type="Git repository"
  fi
  
  echo "Directory: $pwd_info ($file_count files)"
  if [[ -n "$dir_type" ]]; then
    echo "Project type: $dir_type"
  fi
}

# Validate that required dependencies are available
zshai_check_dependencies() {
  local missing_deps=()
  
  # Check for curl
  if ! zshai_command_exists curl; then
    missing_deps+=("curl")
  fi
  
  # Check for basic Unix tools
  for tool in grep sed awk; do
    if ! zshai_command_exists "$tool"; then
      missing_deps+=("$tool")
    fi
  done
  
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    zshai_error "Missing required dependencies: ${missing_deps[*]}"
    echo "Please install the missing tools and try again."
    return 1
  fi
  
  return 0
}

# Comprehensive system check
zshai_system_check() {
  echo "$(zshai_colorize "zsh-ai System Check" "cyan")"
  echo "===================="
  echo ""
  
  # Check dependencies
  echo "Dependencies:"
  if zshai_check_dependencies >/dev/null 2>&1; then
    echo "  $(zshai_colorize "✓" "green") All dependencies available"
  else
    echo "  $(zshai_colorize "✗" "red") Missing dependencies"
  fi
  
  # Check Ollama
  echo ""
  echo "Ollama:"
  if zshai_check_ollama; then
    echo "  $(zshai_colorize "✓" "green") Ollama is running"
    
    # Check model
    local model="$(zshai_get_config DEFAULT_MODEL)"
    if zshai_check_model "$model" >/dev/null 2>&1; then
      echo "  $(zshai_colorize "✓" "green") Model '$model' is available"
    else
      echo "  $(zshai_colorize "✗" "red") Model '$model' is not available"
    fi
  else
    echo "  $(zshai_colorize "✗" "red") Ollama is not running"
  fi
  
  # Check configuration
  echo ""
  echo "Configuration:"
  if [[ -f "$ZSHAI_USER_CONFIG" ]]; then
    echo "  $(zshai_colorize "✓" "green") Config file exists: $ZSHAI_USER_CONFIG"
  else
    echo "  $(zshai_colorize "✗" "red") Config file missing: $ZSHAI_USER_CONFIG"
  fi
  
  if [[ -f "$ZSHAI_HISTORY_FILE" ]]; then
    echo "  $(zshai_colorize "✓" "green") History file exists: $ZSHAI_HISTORY_FILE"
  else
    echo "  $(zshai_colorize "✗" "red") History file missing: $ZSHAI_HISTORY_FILE"
  fi
  
  echo ""
  echo "Current settings:"
  echo "  Model: $(zshai_get_config DEFAULT_MODEL)"
  echo "  Safety level: $(zshai_get_config SAFETY_LEVEL)"
  echo "  History enabled: $(zshai_get_config HISTORY_ENABLED)"
  echo "  Verbose mode: $(zshai_get_config VERBOSE)"
  
  echo ""
  if zshai_check_ollama && zshai_check_model "$(zshai_get_config DEFAULT_MODEL)" >/dev/null 2>&1; then
    echo "$(zshai_colorize "✅ System is ready to use!" "green")"
    echo ""
    echo "Try: $(zshai_colorize "ai \"list files in current directory\"" "cyan")"
  else
    echo "$(zshai_colorize "⚠️  System needs setup" "yellow")"
    echo ""
    echo "Next steps:"
    if ! zshai_check_ollama; then
      echo "  1. Start Ollama: $(zshai_colorize "ollama serve" "green")"
    fi
    local model="$(zshai_get_config DEFAULT_MODEL)"
    if ! zshai_check_model "$model" >/dev/null 2>&1; then
      echo "  2. Install model: $(zshai_colorize "ollama pull $model" "green")"
    fi
  fi
}

# Show command history
zshai_history() {
  local count="${1:-10}"
  
  if [[ ! -f "$ZSHAI_HISTORY_FILE" ]]; then
    echo "No history found."
    return 0
  fi
  
  echo "Recent zsh-ai history (last $count entries):"
  echo ""
  
  tail -n "$count" "$ZSHAI_HISTORY_FILE" | while IFS="|" read -r timestamp query command; do
    local date_str=$(date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "Unknown date")
    echo "$(zshai_colorize "[$date_str]" "cyan")"
    echo "Query: $query"
    echo "Command: $(zshai_colorize "$command" "green")"
    echo ""
  done
}

# Clear command history
zshai_clear_history() {
  if [[ -f "$ZSHAI_HISTORY_FILE" ]]; then
    > "$ZSHAI_HISTORY_FILE"
    echo "History cleared."
  else
    echo "No history file found."
  fi
}