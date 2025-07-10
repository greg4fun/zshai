#!/usr/bin/env bash
#
# install.sh - Installation script for zsh-ai plugin
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Plugin directory
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="zsh-ai"

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh-ai"
ZSHRC_FILE="$HOME/.zshrc"

# Print colored output
print_color() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

# Print section header
print_header() {
  echo ""
  print_color "$CYAN" "=== $1 ==="
}

# Check for dependencies
check_dependencies() {
  print_header "Checking Dependencies"
  
  local all_good=true
  
  # Check for zsh
  if command -v zsh &> /dev/null; then
    print_color "$GREEN" "✓ zsh is installed"
  else
    print_color "$RED" "✗ zsh is not installed"
    echo "  Please install zsh and try again"
    all_good=false
  fi
  
  # Check for curl
  if command -v curl &> /dev/null; then
    print_color "$GREEN" "✓ curl is installed"
  else
    print_color "$YELLOW" "⚠ curl is not installed"
    echo "  curl is required for API communication with Ollama"
    echo "  Please install curl for full functionality"
  fi
  
  # Check for Ollama (optional but recommended)
  if command -v ollama &> /dev/null; then
    print_color "$GREEN" "✓ Ollama CLI is installed"
    
    # Check if Ollama is running
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:11434/api/tags" 2>/dev/null | grep -q "200"; then
      print_color "$GREEN" "✓ Ollama service is running"
    else
      print_color "$YELLOW" "⚠ Ollama service is not running"
      echo "  Start it with: ollama serve"
    fi
  else
    print_color "$YELLOW" "⚠ Ollama is not installed"
    echo "  Ollama is required for local LLM functionality"
    echo "  Install from: https://ollama.ai"
  fi
  
  # Check for git (for version info)
  if command -v git &> /dev/null; then
    print_color "$GREEN" "✓ git is installed"
  else
    print_color "$YELLOW" "⚠ git is not installed (optional)"
  fi
  
  if [ "$all_good" = true ]; then
    print_color "$GREEN" "All critical dependencies are satisfied"
  else
    print_color "$RED" "Some critical dependencies are missing"
    exit 1
  fi
}

# Create configuration directory and files
setup_config() {
  print_header "Setting Up Configuration"
  
  # Create config directory
  if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    print_color "$GREEN" "Created configuration directory: $CONFIG_DIR"
  else
    print_color "$YELLOW" "Configuration directory already exists: $CONFIG_DIR"
  fi
  
  # Copy default configuration if it doesn't exist
  local user_config="$CONFIG_DIR/config.conf"
  if [ ! -f "$user_config" ]; then
    if [ -f "$PLUGIN_DIR/config/default.conf" ]; then
      cp "$PLUGIN_DIR/config/default.conf" "$user_config"
      print_color "$GREEN" "Created default configuration: $user_config"
    else
      print_color "$YELLOW" "Default config not found, creating basic config"
      cat > "$user_config" <<EOF
# zsh-ai configuration
ZSHAI_DEFAULT_MODEL="llama2"
ZSHAI_OLLAMA_API_URL="http://localhost:11434/api/generate"
ZSHAI_TEMPERATURE=0.7
ZSHAI_SAFETY_LEVEL="medium"
ZSHAI_AUTO_CONFIRM="false"
ZSHAI_HISTORY_ENABLED="true"
ZSHAI_MAX_HISTORY=100
ZSHAI_VERBOSE="false"
EOF
      print_color "$GREEN" "Created basic configuration: $user_config"
    fi
  else
    print_color "$YELLOW" "Configuration already exists: $user_config"
  fi
  
  # Create history file
  local history_file="$CONFIG_DIR/history.txt"
  if [ ! -f "$history_file" ]; then
    touch "$history_file"
    print_color "$GREEN" "Created history file: $history_file"
  else
    print_color "$YELLOW" "History file already exists: $history_file"
  fi
  
  # Set appropriate permissions
  chmod 755 "$CONFIG_DIR"
  chmod 644 "$user_config" 2>/dev/null || true
  chmod 644 "$history_file" 2>/dev/null || true
}

# Install plugin to .zshrc
install_plugin() {
  print_header "Installing Plugin"
  
  # Check if .zshrc exists
  if [ ! -f "$ZSHRC_FILE" ]; then
    print_color "$YELLOW" "Creating new .zshrc file: $ZSHRC_FILE"
    touch "$ZSHRC_FILE"
  fi
  
  # Check if plugin is already installed
  local plugin_line="source \"$PLUGIN_DIR/zsh-ai.plugin.zsh\""
  if grep -Fq "$plugin_line" "$ZSHRC_FILE"; then
    print_color "$YELLOW" "Plugin is already installed in .zshrc"
  else
    # Add plugin to .zshrc
    echo "" >> "$ZSHRC_FILE"
    echo "# zsh-ai plugin - Convert natural language to terminal commands" >> "$ZSHRC_FILE"
    echo "$plugin_line" >> "$ZSHRC_FILE"
    print_color "$GREEN" "Plugin installed successfully to .zshrc"
  fi
}

# Test the installation
test_installation() {
  print_header "Testing Installation"
  
  # Source the plugin in a subshell to test
  if (
    export ZSHAI_DIR="$PLUGIN_DIR"
    source "$PLUGIN_DIR/zsh-ai.plugin.zsh" 2>/dev/null
    # Test if main function is available
    if declare -f ai >/dev/null 2>&1 && declare -f zshai_init_plugin >/dev/null 2>&1; then
      echo "Plugin functions loaded successfully"
      exit 0
    else
      echo "Failed to load plugin functions"
      exit 1
    fi
  ); then
    print_color "$GREEN" "✓ Plugin loads successfully"
  else
    print_color "$RED" "✗ Plugin failed to load"
    echo "  Check the installation and try again"
    return 1
  fi
  
  # Check if Ollama is accessible
  if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:11434/api/tags" 2>/dev/null | grep -q "200"; then
    print_color "$GREEN" "✓ Ollama API is accessible"
  else
    print_color "$YELLOW" "⚠ Ollama API is not accessible"
    echo "  Make sure Ollama is running: ollama serve"
  fi
}

# Print usage instructions
print_instructions() {
  print_header "Installation Complete"
  
  print_color "$GREEN" "zsh-ai plugin has been installed successfully!"
  echo ""
  
  print_color "$CYAN" "Next Steps:"
  echo "1. Restart your terminal or run: source ~/.zshrc"
  echo "2. Make sure Ollama is running: ollama serve"
  echo "3. Pull a model: ollama pull llama2"
  echo ""
  
  print_color "$CYAN" "Basic Usage:"
  echo "  ai \"list all files sorted by size\""
  echo "  ai \"find all python files modified today\""
  echo "  aiexplain \"find . -name '*.py' -mtime -1\""
  echo ""
  
  print_color "$CYAN" "Configuration:"
  echo "  ai-config                      # Show current settings"
  echo "  ai-config set SAFETY_LEVEL high"
  echo "  ai-config get DEFAULT_MODEL"
  echo "  ai-config test                 # Test Ollama connection"
  echo "  ai-config models               # List available models"
  echo ""
  
  print_color "$CYAN" "Aliases:"
  echo "  aiexplain \"command\"           # Explain a command"
  echo "  aiconfig                       # Same as ai-config"
  echo "  ai-help                        # Show help"
  echo "  ai-test                        # Test connection"
  echo ""
  
  print_color "$CYAN" "Key Bindings:"
  echo "  Ctrl+X, Ctrl+A                 # Convert current buffer to command"
  echo ""
  
  print_color "$CYAN" "Files Created:"
  echo "  Config: $CONFIG_DIR/config.conf"
  echo "  History: $CONFIG_DIR/history.txt"
  echo ""
  
  print_color "$CYAN" "For help and troubleshooting:"
  echo "  ai --help                      # Show usage information"
  echo "  ai-config                      # Show current configuration"
  echo "  ai-config test                 # Test Ollama connection"
  echo "  ai-config history              # Show command history"
  echo ""
  
  print_color "$YELLOW" "Note: Make sure to have a compatible model installed in Ollama"
  echo "Popular choices: llama2, codellama, mistral, mixtral"
}

# Uninstall function
uninstall() {
  print_header "Uninstalling zsh-ai Plugin"
  
  # Remove from .zshrc
  if [ -f "$ZSHRC_FILE" ]; then
    # Create backup
    cp "$ZSHRC_FILE" "$ZSHRC_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Remove plugin lines
    grep -v "zsh-ai.plugin.zsh" "$ZSHRC_FILE" | grep -v "# zsh-ai plugin" > "$ZSHRC_FILE.tmp"
    mv "$ZSHRC_FILE.tmp" "$ZSHRC_FILE"
    
    print_color "$GREEN" "Removed plugin from .zshrc (backup created)"
  fi
  
  # Ask about removing config
  echo -n "Remove configuration directory $CONFIG_DIR? [y/N] "
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR"
    print_color "$GREEN" "Removed configuration directory"
  else
    print_color "$YELLOW" "Configuration directory preserved"
  fi
  
  print_color "$GREEN" "Uninstallation complete"
  echo "Restart your terminal to complete the process"
}

# Main installation process
main() {
  # Parse command line arguments
  case "${1:-}" in
    "uninstall"|"--uninstall"|"-u")
      uninstall
      exit 0
      ;;
    "help"|"--help"|"-h")
      echo "Usage: $0 [uninstall]"
      echo ""
      echo "Options:"
      echo "  (no args)    Install the zsh-ai plugin"
      echo "  uninstall    Remove the zsh-ai plugin"
      echo "  help         Show this help message"
      exit 0
      ;;
  esac
  
  print_color "$BLUE" "zsh-ai Plugin Installer"
  print_color "$BLUE" "======================="
  
  check_dependencies
  setup_config
  install_plugin
  test_installation
  print_instructions
}

# Run the installer
main "$@"