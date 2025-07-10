#!/usr/bin/env zsh
#
# config.zsh - Configuration management
#

# Default configuration values
ZSHAI_DEFAULT_MODEL="llama2"
ZSHAI_OLLAMA_API_URL="http://localhost:11434/api/generate"
ZSHAI_TEMPERATURE=0.7
ZSHAI_SAFETY_LEVEL="medium"
ZSHAI_AUTO_CONFIRM="false"
ZSHAI_VERBOSE="false"
ZSHAI_HISTORY_ENABLED="true"
ZSHAI_MAX_HISTORY=100
ZSHAI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh-ai"
ZSHAI_HISTORY_FILE="${ZSHAI_CONFIG_DIR}/history.txt"
ZSHAI_USER_CONFIG="${ZSHAI_CONFIG_DIR}/config.conf"

# Initialize configuration
zshai_init_config() {
  # Create config directory if it doesn't exist
  if [[ ! -d "$ZSHAI_CONFIG_DIR" ]]; then
    mkdir -p "$ZSHAI_CONFIG_DIR"
  fi
  
  # Create history file if it doesn't exist and history is enabled
  if [[ "$ZSHAI_HISTORY_ENABLED" == "true" && ! -f "$ZSHAI_HISTORY_FILE" ]]; then
    touch "$ZSHAI_HISTORY_FILE"
  fi
  
  # Create user config file if it doesn't exist
  if [[ ! -f "$ZSHAI_USER_CONFIG" ]]; then
    zshai_create_default_config
  fi
  
  # Load user configuration
  zshai_load_config
}

# Create default configuration file
zshai_create_default_config() {
  local default_config="${ZSHAI_DIR}/config/default.conf"
  
  # If default config exists, copy it
  if [[ -f "$default_config" ]]; then
    cp "$default_config" "$ZSHAI_USER_CONFIG"
  else
    # Otherwise create a basic config
    cat > "$ZSHAI_USER_CONFIG" <<EOF
# zsh-ai configuration

# Ollama settings
ZSHAI_DEFAULT_MODEL="llama2"
ZSHAI_OLLAMA_API_URL="http://localhost:11434/api/generate"
ZSHAI_TEMPERATURE=0.7

# Safety settings
ZSHAI_SAFETY_LEVEL="medium"  # low, medium, high
ZSHAI_AUTO_CONFIRM="false"

# History settings
ZSHAI_HISTORY_ENABLED="true"
ZSHAI_MAX_HISTORY=100

# Misc settings
ZSHAI_VERBOSE="false"
EOF
  fi
}

# Load user configuration
zshai_load_config() {
  if [[ -f "$ZSHAI_USER_CONFIG" ]]; then
    source "$ZSHAI_USER_CONFIG"
  fi
}

# Get a configuration value
zshai_get_config() {
  local key="$1"
  
  # Convert to uppercase using zsh-compatible method
  local var_name="ZSHAI_${key:u}"
  
  # Return the value of the variable
  echo "${(P)var_name}"
}

# Set a configuration value
zshai_set_config() {
  local key="$1"
  local value="$2"
  local var_name="ZSHAI_${key:u}"  # Convert to uppercase using zsh syntax
  
  # Validate the key
  case "$key" in
    DEFAULT_MODEL|OLLAMA_API_URL|TEMPERATURE|SAFETY_LEVEL|AUTO_CONFIRM|HISTORY_ENABLED|MAX_HISTORY|VERBOSE)
      ;;
    *)
      echo "Error: Unknown configuration key '$key'"
      echo "Valid keys: DEFAULT_MODEL, OLLAMA_API_URL, TEMPERATURE, SAFETY_LEVEL, AUTO_CONFIRM, HISTORY_ENABLED, MAX_HISTORY, VERBOSE"
      return 1
      ;;
  esac
  
  # Set the variable
  eval "$var_name=\"$value\""
  
  # Update the config file
  if grep -q "^$var_name=" "$ZSHAI_USER_CONFIG" 2>/dev/null; then
    # Use different sed syntax for better compatibility
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^$var_name=.*/$var_name=\"$value\"/" "$ZSHAI_USER_CONFIG"
    else
      sed -i "s/^$var_name=.*/$var_name=\"$value\"/" "$ZSHAI_USER_CONFIG"
    fi
  else
    echo "$var_name=\"$value\"" >> "$ZSHAI_USER_CONFIG"
  fi
  
  echo "Configuration updated: $key = $value"
}

# Print current configuration
zshai_print_config() {
  echo "zsh-ai configuration:"
  echo ""
  echo "Ollama settings:"
  echo "  Default model: $ZSHAI_DEFAULT_MODEL"
  echo "  API URL: $ZSHAI_OLLAMA_API_URL"
  echo "  Temperature: $ZSHAI_TEMPERATURE"
  echo ""
  echo "Safety settings:"
  echo "  Safety level: $ZSHAI_SAFETY_LEVEL"
  echo "  Auto-confirm: $ZSHAI_AUTO_CONFIRM"
  echo ""
  echo "History settings:"
  echo "  History enabled: $ZSHAI_HISTORY_ENABLED"
  echo "  Max history: $ZSHAI_MAX_HISTORY"
  echo ""
  echo "Misc settings:"
  echo "  Verbose: $ZSHAI_VERBOSE"
  echo ""
  echo "Config file: $ZSHAI_USER_CONFIG"
  echo "History file: $ZSHAI_HISTORY_FILE"
}