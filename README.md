# zsh-ai

A zsh plugin that converts natural language to terminal commands using a local LLM via Ollama API.

![Demo](intro.gif)

## Features

- 🤖 **Natural Language to Commands**: Convert plain English to terminal commands
- 📚 **Command Explanation**: Get detailed explanations of complex commands
- 🔒 **Safety Validation**: Built-in safety checks to prevent dangerous operations
- 📝 **History Integration**: Learn from your command history for better suggestions
- ⚙️ **Flexible Configuration**: Customize models, safety levels, and behavior
- 🎯 **Context Awareness**: Considers your current directory and recent commands
- 🔧 **Multiple Models**: Support for various Ollama models (llama2, codellama, mistral, etc.)

## Prerequisites

- **zsh** shell
- **curl** for API communication
- **[Ollama](https://ollama.ai)** for local LLM functionality

## Installation

### Quick Install

```bash
# Clone the repository
git clone git@github.com:greg4fun/zshai.git ~/.zsh-ai

# Run the installer
cd ~/.zsh-ai && ./install.sh

# Restart your shell
exec zsh
```

### Manual Install

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/zsh-ai.git ~/.zsh-ai
   ```

2. Add to your `.zshrc`:
   ```bash
   source ~/.zsh-ai/zsh-ai.plugin.zsh
   ```

3. Create configuration directory:
   ```bash
   mkdir -p ~/.config/zsh-ai
   cp ~/.zsh-ai/config/default.conf ~/.config/zsh-ai/config.conf
   ```

4. Restart your shell:
   ```bash
   exec zsh
   ```

## Setup Ollama

1. Install Ollama from [ollama.ai](https://ollama.ai)

2. Start the Ollama service:
   ```bash
   ollama serve
   ```

3. Pull a model (recommended):
   ```bash
   ollama pull llama2
   # or for code-focused tasks:
   ollama pull codellama
   ```

## Usage

### Basic Commands

```bash
# Generate commands from natural language
zshai "list all files sorted by size"
zshai "find all python files modified in the last week"
zshai "show disk usage for each directory"

# Explain existing commands
zshai_explain "find . -name '*.py' -exec grep -l 'import pandas' {} \;"

# Configuration management
zshai_config                    # Show current settings
zshai_config set SAFETY_LEVEL high
zshai_config get DEFAULT_MODEL
```

### Aliases

```bash
ai "your query here"           # Same as zshai
aiexplain "command here"       # Same as zshai_explain
aiconfig                       # Same as zshai_config
```

### Key Bindings

- **Ctrl+X, Ctrl+A**: Convert current buffer content to a command

### Example Workflow

```bash
# Natural language query
$ zshai "show me all large files over 100MB"
🤔 Thinking...

💻 Generated command:
find . -type f -size +100M -exec ls -lh {} \;

Execute this command? [y/N] y

🚀 Executing...
-rw-r--r-- 1 user user 150M Oct 15 10:30 ./data/large_dataset.csv
-rw-r--r-- 1 user user 200M Oct 14 15:45 ./videos/presentation.mp4
```

## Configuration

The plugin uses a configuration file at `~/.config/zsh-ai/config.conf`. Key settings include:

### Model Settings
```bash
ZSHAI_DEFAULT_MODEL="llama2"           # Default model to use
ZSHAI_TEMPERATURE=0.7                  # Creativity level (0.0-1.0)
ZSHAI_OLLAMA_API_URL="http://localhost:11434/api/generate"
```

### Safety Settings
```bash
ZSHAI_SAFETY_LEVEL="medium"            # low, medium, high
ZSHAI_AUTO_CONFIRM="false"             # Auto-execute dangerous commands
```

### History Settings
```bash
ZSHAI_HISTORY_ENABLED="true"           # Track command history
ZSHAI_MAX_HISTORY=100                  # Maximum history entries
```

## Safety Features

The plugin includes multiple safety layers:

### Safety Levels

- **Low**: Blocks only extremely dangerous commands (rm -rf /, fork bombs)
- **Medium**: Blocks dangerous file operations and system modifications
- **High**: Blocks all potentially risky commands including sudo and system services

### Validation Examples

```bash
# Safe commands (allowed at all levels)
zshai "list files"                     # ✅ ls -la
zshai "find python files"              # ✅ find . -name "*.py"

# Potentially dangerous (blocked at medium/high)
zshai "delete all temporary files"     # ⚠️  Warns about rm -rf
zshai "install package with sudo"      # ⚠️  Warns about sudo usage

# Extremely dangerous (blocked at all levels)
zshai "format the disk"                # ❌ Blocked: mkfs commands
zshai "delete everything"              # ❌ Blocked: rm -rf /
```

## Available Models

Popular Ollama models that work well with zsh-ai:

### General Purpose
- **llama2**: Good balance of speed and capability
- **llama2:13b**: Better quality, slower
- **mistral**: Fast and efficient
- **mixtral**: High quality for complex tasks

### Code-Focused
- **codellama**: Specialized for code generation
- **codellama:13b**: Better code understanding
- **phi**: Small and fast for simple tasks

### Changing Models

```bash
# Pull a new model
ollama pull codellama

# Update configuration
zshai_config set DEFAULT_MODEL codellama

# Test the new model
zshai_test_connection codellama
```

## Advanced Features

### History Integration

The plugin learns from your command history to provide better suggestions:

```bash
# View recent history
zshai_history

# Clear history
zshai_clear_history
```

### Context Awareness

Commands are generated considering:
- Current working directory
- Files in the current directory
- Git repository status (if applicable)
- Recent command history

### Testing and Debugging

```bash
# Test Ollama connection
zshai_test_connection

# Test safety validation
zshai_test_validation

# Enable verbose mode
zshai_config set VERBOSE true
```

## Troubleshooting

### Common Issues

1. **"Ollama is not running"**
   ```bash
   ollama serve
   ```

2. **"Model not found"**
   ```bash
   ollama pull llama2
   zshai_config set DEFAULT_MODEL llama2
   ```

3. **"Command generation fails"**
   ```bash
   zshai_test_connection
   zshai_config
   ```

4. **"Plugin not loading"**
   ```bash
   # Check .zshrc
   grep zsh-ai ~/.zshrc
   
   # Reload configuration
   source ~/.zshrc
   ```

### Debug Mode

Enable verbose logging:
```bash
zshai_config set VERBOSE true
source ~/.zshrc
```

## File Structure

```
zsh-ai/
├── zsh-ai.plugin.zsh         # Main plugin file
├── lib/                      # Library directory
│   ├── ollama-client.zsh     # API client for Ollama
│   ├── command-validator.zsh # Command safety validation
│   ├── config.zsh            # Configuration management
│   ├── utils.zsh             # Utility functions
│   └── prompt-templates.zsh  # LLM prompt engineering
├── config/                   # Config directory
│   └── default.conf          # Default configuration template
├── install.sh                # Installation script
└── README.md                 # This file
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -am 'Add feature'`
5. Push to the branch: `git push origin feature-name`
6. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [Ollama](https://ollama.ai) for providing the local LLM infrastructure
- The zsh community for excellent plugin architecture
- Contributors and testers who help improve the plugin

## Changelog

### v0.1.0 (Initial Release)
- Natural language to command conversion
- Command explanation functionality
- Safety validation system
- History integration
- Flexible model configuration
- Comprehensive installation script