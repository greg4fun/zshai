#!/usr/bin/env zsh
#
# prompt-templates.zsh - LLM prompt engineering
#

# Generate a prompt for command generation
zshai_generate_command_prompt() {
  local query="$1"
  local context="$2"
  
  # System prompt for command generation
  local system_prompt="You are a helpful assistant that converts natural language queries into terminal commands. Your task is to generate the most appropriate command for the user's query.

IMPORTANT RULES:
1. Provide ONLY the command with no explanation or additional text
2. Do not include any markdown formatting, backticks, or code blocks
3. Generate commands that are safe and commonly used
4. Prefer standard Unix/Linux commands that work across different systems
5. If the query is ambiguous, choose the most common interpretation
6. Do not generate commands that require sudo unless explicitly requested
7. Ensure the command is syntactically correct and executable
8. Consider the current working directory and file context when relevant
9. Use relative paths when appropriate
10. Prefer portable commands over system-specific ones

Examples:
Query: \"list all files sorted by size\"
Response: ls -laSh

Query: \"find all python files\"
Response: find . -name \"*.py\"

Query: \"show disk usage\"
Response: df -h

Query: \"count lines in all text files\"
Response: find . -name \"*.txt\" -exec wc -l {} +

Query: \"show git status\"
Response: git status"

  # Build the user prompt
  local user_prompt=""
  
  # Add context if available
  if [[ -n "$context" && "$context" != "" ]]; then
    user_prompt="Here are some recent commands I've run for context:\n\n$context\n\nBased on this context and my current working directory, please convert the following query to a terminal command: $query"
  else
    user_prompt="Convert the following query to a terminal command: $query"
  fi
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a prompt for command explanation
zshai_generate_explanation_prompt() {
  local command="$1"
  
  # System prompt for explanation
  local system_prompt="You are a helpful assistant that explains terminal commands in detail. Your task is to provide a clear, comprehensive explanation of what the command does, breaking it down into its components.

EXPLANATION FORMAT:
1. Start with a brief summary of what the command does
2. Break down each part of the command and explain its purpose
3. Mention any important flags or options used
4. Explain the expected output or result
5. Note any potential risks or side effects
6. Suggest related commands or alternatives if relevant

Be educational and thorough, but keep the explanation accessible to users who may not be experts."

  # User prompt
  local user_prompt="Explain the following terminal command in detail: $command"
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a prompt for command improvement
zshai_generate_improvement_prompt() {
  local command="$1"
  local feedback="$2"
  
  # System prompt
  local system_prompt="You are a helpful assistant that improves terminal commands based on user feedback. Your task is to modify the command to better match the user's intent.

IMPORTANT RULES:
1. Provide ONLY the improved command with no explanation or additional text
2. Do not include any markdown formatting, backticks, or code blocks
3. Consider the user's feedback carefully and adjust accordingly
4. Maintain the core functionality while addressing the feedback
5. Ensure the improved command is syntactically correct"

  # User prompt
  local user_prompt="Here is a command: $command\n\nBased on this feedback: \"$feedback\", please improve the command."
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a prompt for command alternatives
zshai_generate_alternatives_prompt() {
  local command="$1"
  
  # System prompt
  local system_prompt="You are a helpful assistant that provides alternative ways to accomplish the same task in the terminal. Your task is to suggest different commands that achieve the same result as the original command.

IMPORTANT RULES:
1. Provide ONLY the alternative commands, one per line
2. Do not include any markdown formatting, backticks, or code blocks
3. Do not include explanations or additional text
4. Provide 2-3 practical alternatives
5. Ensure all alternatives are syntactically correct
6. Consider different tools or approaches that accomplish the same goal"

  # User prompt
  local user_prompt="Provide alternative commands that accomplish the same task as: $command"
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a prompt for command validation/safety check
zshai_generate_safety_prompt() {
  local command="$1"
  
  # System prompt
  local system_prompt="You are a security-focused assistant that analyzes terminal commands for potential risks. Your task is to identify any safety concerns with the given command.

ANALYSIS FORMAT:
1. Overall risk level (LOW/MEDIUM/HIGH)
2. Specific risks identified
3. Potential consequences
4. Safer alternatives if applicable
5. Recommendations for safe execution

Be thorough in your analysis and err on the side of caution."

  # User prompt
  local user_prompt="Analyze the following command for potential security risks and safety concerns: $command"
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a prompt for command history analysis
zshai_generate_history_analysis_prompt() {
  local history_context="$1"
  local current_query="$2"
  
  # System prompt
  local system_prompt="You are a helpful assistant that analyzes command history to provide better command suggestions. Your task is to understand the user's workflow and provide a command that fits their current context.

IMPORTANT RULES:
1. Provide ONLY the command with no explanation or additional text
2. Do not include any markdown formatting, backticks, or code blocks
3. Consider the user's recent commands to understand their current task
4. Generate commands that logically follow from their recent activity
5. Maintain consistency with their preferred tools and patterns"

  # User prompt
  local user_prompt="Based on this command history:\n\n$history_context\n\nGenerate a command for this query: $current_query"
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a prompt for learning from corrections
zshai_generate_learning_prompt() {
  local original_query="$1"
  local generated_command="$2"
  local corrected_command="$3"
  
  # System prompt
  local system_prompt="You are a learning assistant that analyzes the difference between generated and corrected commands to improve future suggestions. Your task is to understand what went wrong and how to improve.

ANALYSIS FORMAT:
1. What was different between the generated and corrected commands
2. Why the correction was better
3. What patterns or preferences this reveals about the user
4. How to apply this learning to future similar queries

Provide insights that can help improve command generation accuracy."

  # User prompt
  local user_prompt="Original query: $original_query\nGenerated command: $generated_command\nCorrected command: $corrected_command\n\nAnalyze the difference and provide insights for improvement."
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}

# Generate a context-aware prompt based on current directory and environment
zshai_generate_contextual_prompt() {
  local query="$1"
  local pwd_info="$(pwd)"
  local ls_info="$(ls -la 2>/dev/null | head -10)"
  local git_info=""
  local project_info=""
  
  # Check if we're in a git repository
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local branch=$(git branch --show-current 2>/dev/null || echo 'unknown')
    local status_count=$(git status --porcelain 2>/dev/null | wc -l)
    git_info="Git repository (branch: $branch, modified files: $status_count)"
  fi
  
  # Detect project type
  if [[ -f "package.json" ]]; then
    project_info="Node.js/JavaScript project"
  elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
    project_info="Python project"
  elif [[ -f "Cargo.toml" ]]; then
    project_info="Rust project"
  elif [[ -f "go.mod" ]]; then
    project_info="Go project"
  elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
    project_info="Java project"
  elif [[ -f "Makefile" ]]; then
    project_info="Project with Makefile"
  elif [[ -f "docker-compose.yml" ]] || [[ -f "Dockerfile" ]]; then
    project_info="Docker project"
  fi
  
  # System prompt
  local system_prompt="You are a context-aware assistant that generates terminal commands based on the user's current environment. Consider the current directory, files present, and project context when generating commands.

IMPORTANT RULES:
1. Provide ONLY the command with no explanation or additional text
2. Do not include any markdown formatting, backticks, or code blocks
3. Consider the current working directory and files when generating commands
4. Use relative paths when appropriate
5. Adapt commands to the apparent project type or environment
6. For project-specific tasks, use the appropriate tools (npm, pip, cargo, go, etc.)
7. Consider git context when relevant to the query"

  # Build context information
  local context_info="Current directory: $pwd_info\n"
  if [[ -n "$git_info" ]]; then
    context_info="$context_info$git_info\n"
  fi
  if [[ -n "$project_info" ]]; then
    context_info="$context_info$project_info\n"
  fi
  context_info="$context_info\nFiles in current directory:\n$ls_info"
  
  # User prompt
  local user_prompt="Environment context:\n$context_info\n\nGenerate a command for this query: $query"
  
  # Combine prompts
  echo "$system_prompt\n\n$user_prompt"
}