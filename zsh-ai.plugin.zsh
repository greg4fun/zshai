#!/usr/bin/env zsh
#
# zsh-ai - Convert natural language to terminal commands using Ollama
#
# Author: Greg Stenhouse
# License: MIT
# Version: 0.1.0
#

# Plugin directory
ZSHAI_DIR="${0:A:h}"

# Source library files
source "${ZSHAI_DIR}/lib/config.zsh"
source "${ZSHAI_DIR}/lib/utils.zsh"
source "${ZSHAI_DIR}/lib/ollama-client.zsh"
source "${ZSHAI_DIR}/lib/command-validator.zsh"
source "${ZSHAI_DIR}/lib/prompt-templates.zsh"

# Initialize configuration and check dependencies
zshai_init_plugin() {
  # Check dependencies first
  if ! zshai_check_dependencies; then
    zshai_error "Failed to initialize zsh-ai plugin due to missing dependencies"
    return 1
  fi
  
  # Initialize configuration
  zshai_init_config
  
  # Log successful initialization if verbose
  zshai_log "INFO" "zsh-ai plugin initialized successfully"
  
  return 0
}

# Initialize the plugin
zshai_init_plugin

# Define the main function
ai() {
  # Handle special arguments
  case "$1" in
    "--help"|"-h"|"help")
      zshai_print_usage
      return 0
      ;;
    "--version"|"-v"|"version")
      echo "zsh-ai version 0.1.0"
      echo "A zsh plugin for converting natural language to terminal commands using Ollama"
      return 0
      ;;
    "")
      zshai_print_usage
      return 1
      ;;
  esac
  
  # Parse arguments
  local query="$*"
  
  # Process the query
  zshai_process_query "$query"
}

# Alias for backward compatibility
zshai() {
  ai "$@"
}

# Define the command explanation function
zshai_explain() {
  local cmd="$*"
  
  # Check if command is empty
  if [[ -z "$cmd" ]]; then
    echo "Usage: zshai_explain <command>"
    return 1
  fi
  
  # Get explanation for the command
  zshai_get_explanation "$cmd"
}

# Define configuration function
ai-config() {
  case "$1" in
    "")
      zshai_print_config
      ;;
    "set")
      if [[ -z "$2" || -z "$3" ]]; then
        echo "Usage: ai-config set <key> <value>"
        return 1
      fi
      zshai_set_config "$2" "$3"
      ;;
    "get")
      if [[ -z "$2" ]]; then
        echo "Usage: ai-config get <key>"
        return 1
      fi
      zshai_get_config "$2"
      ;;
    "test")
      zshai_test_connection
      ;;
    "models")
      zshai_list_models
      ;;
    "safety")
      if [[ -n "$2" ]]; then
        zshai_set_safety_level "$2"
      else
        echo "Current safety level: $ZSHAI_SAFETY_LEVEL"
        zshai_get_safety_description
      fi
      ;;
    "history")
      case "$2" in
        "clear")
          zshai_clear_history
          ;;
        *)
          zshai_history "${2:-10}"
          ;;
      esac
      ;;
    "check"|"status")
      zshai_system_check
      ;;
    *)
      echo "Usage: ai-config [set <key> <value>|get <key>|test|models|safety [level]|history [count|clear]|check]"
      return 1
      ;;
  esac
}

# Alias for backward compatibility
zshai_config() {
  ai-config "$@"
}

# Define aliases
alias aiexplain="zshai_explain"
alias aiconfig="ai-config"
alias ai-help="ai --help"
alias ai-test="ai-config test"
alias ai-models="ai-config models"
alias ai-history="ai-config history"
alias ai-check="ai-config check"

# Define key bindings (optional)
# Ctrl+X, Ctrl+A to trigger ai widget
zshai_widget() {
  BUFFER="ai \"$BUFFER\""
  zle accept-line
}
zle -N zshai_widget
bindkey '^X^A' zshai_widget

# Print plugin loaded message if verbose
if [[ "$ZSHAI_VERBOSE" == "true" ]]; then
  zshai_success "zsh-ai plugin loaded successfully"
  echo "  • Main command: $(zshai_colorize "ai" "green")"
  echo "  • Configuration: $(zshai_colorize "ai-config" "green")"
  echo "  • Explanation: $(zshai_colorize "aiexplain" "green")"
  echo "  • Key binding: $(zshai_colorize "Ctrl+X, Ctrl+A" "green")"
  echo ""
  echo "Run '$(zshai_colorize "ai --help" "cyan")' or '$(zshai_colorize "ai-config" "cyan")' to get started."
fi