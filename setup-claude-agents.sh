#!/bin/bash
# setup-claude-agents.sh - Bootstrap Claude Code agent orchestration for new projects
# Version: 1.0
# Source: aws-n8n-server (proven production configuration)
#
# Usage:
#   ./setup-claude-agents.sh [--project-type <type>] [--source-dir <path>]
#
# Options:
#   --project-type   Type of project: python|nodejs|terraform|generic (default: generic)
#   --source-dir     Path to source .claude directory (default: current directory)
#
# This script sets up a complete agent orchestration environment including:
# - Team agents (builder, validator)
# - Utility agents (meta-agent, work-completion-summary)
# - Hooks system with validators
# - Logging infrastructure
# - Project documentation templates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_TYPE="${1:-generic}"
SOURCE_DIR="${2:-.}"
TARGET_DIR="."

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}🤖 Claude Code Agent Orchestration Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Project Type: ${PROJECT_TYPE}"
    log_info "Target Directory: ${TARGET_DIR}"
    echo ""
}

# Check if source .claude directory exists
check_source() {
    if [ ! -d "${SOURCE_DIR}/.claude" ]; then
        log_error "Source .claude directory not found at: ${SOURCE_DIR}/.claude"
        log_info "Please run this script from the aws-n8n-server directory or specify --source-dir"
        exit 1
    fi
    log_success "Found source .claude directory"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."

    mkdir -p .claude/agents/team
    mkdir -p .claude/hooks/validators
    mkdir -p .claude/hooks/utils/llm
    mkdir -p .claude/hooks/utils/tts
    mkdir -p logs
    mkdir -p specs
    mkdir -p docs

    log_success "Directory structure created"
}

# Copy core agent files
copy_agents() {
    log_info "Copying agent definitions..."

    # Team agents (essential)
    cp "${SOURCE_DIR}/.claude/agents/team/builder.md" .claude/agents/team/
    cp "${SOURCE_DIR}/.claude/agents/team/validator.md" .claude/agents/team/

    # Utility agents (optional but recommended)
    if [ -f "${SOURCE_DIR}/.claude/agents/meta-agent.md" ]; then
        cp "${SOURCE_DIR}/.claude/agents/meta-agent.md" .claude/agents/
    fi

    if [ -f "${SOURCE_DIR}/.claude/agents/work-completion-summary.md" ]; then
        cp "${SOURCE_DIR}/.claude/agents/work-completion-summary.md" .claude/agents/
    fi

    log_success "Agent definitions copied"
}

# Copy hooks system
copy_hooks() {
    log_info "Copying hooks system..."

    # Copy all hook files
    cp -r "${SOURCE_DIR}/.claude/hooks/"*.py .claude/hooks/ 2>/dev/null || true

    # Copy validators
    cp -r "${SOURCE_DIR}/.claude/hooks/validators/" .claude/hooks/ 2>/dev/null || true

    # Copy LLM utilities
    cp -r "${SOURCE_DIR}/.claude/hooks/utils/llm/" .claude/hooks/utils/ 2>/dev/null || true

    # Copy TTS utilities (optional)
    cp -r "${SOURCE_DIR}/.claude/hooks/utils/tts/" .claude/hooks/utils/ 2>/dev/null || true

    log_success "Hooks system copied"
}

# Create settings.json based on project type
create_settings() {
    log_info "Creating settings.json for ${PROJECT_TYPE} project..."

    local permissions=""

    case "${PROJECT_TYPE}" in
        python)
            permissions='"Bash(uv:*)", "Bash(pip:*)", "Bash(pytest:*)", "Bash(python:*)",'
            ;;
        nodejs)
            permissions='"Bash(npm:*)", "Bash(yarn:*)", "Bash(pnpm:*)", "Bash(node:*)",'
            ;;
        terraform)
            permissions='"Bash(terraform:*)", "Bash(tofu:*)", "Bash(aws:*)",'
            ;;
        generic)
            permissions='"Bash(make:*)", "Bash(docker:*)",'
            ;;
    esac

    cat > .claude/settings.json << EOF
{
  "permissions": {
    "allow": [
      ${permissions}
      "Bash(mkdir:*)",
      "Bash(find:*)",
      "Bash(mv:*)",
      "Bash(grep:*)",
      "Bash(ls:*)",
      "Bash(cp:*)",
      "Bash(chmod:*)",
      "Bash(touch:*)",
      "Bash(git:*)",
      "Write",
      "Edit"
    ],
    "deny": []
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/pre_tool_use.py\\")\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/pre_tool_use.py"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/post_tool_use.py\\")\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/post_tool_use.py"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/session_start.py\\")\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/session_start.py"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/session_end.py\\")\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/session_end.py"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/user_prompt_submit.py\\") --log-only --store-last-prompt --name-agent\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/user_prompt_submit.py --log-only --store-last-prompt --name-agent"
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/subagent_start.py\\")\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/subagent_start.py"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -Command \\"uv run (Join-Path \$env:CLAUDE_PROJECT_DIR \\".claude/hooks/subagent_stop.py\\") --notify\\"",
            "comment": "Linux/Mac: uv run \$CLAUDE_PROJECT_DIR/.claude/hooks/subagent_stop.py --notify"
          }
        ]
      }
    ]
  }
}
EOF

    log_success "Settings.json created for ${PROJECT_TYPE} project"
}

# Create CLAUDE.md documentation
create_claude_md() {
    log_info "Creating CLAUDE.md project documentation..."

    cat > CLAUDE.md << 'EOF'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

[Describe your project: what it does, key technologies, architecture]

Example:
```
This project is a [web application|API|infrastructure] that [main purpose].
Built with [primary technologies/frameworks].
```

## Architecture

[High-level architecture description]

Example:
```
- Frontend: [React/Vue/Angular/etc]
- Backend: [Node.js/Python/Go/etc]
- Database: [PostgreSQL/MongoDB/etc]
- Infrastructure: [AWS/GCP/Azure/Docker/Kubernetes]
```

## Common Commands

All commands from the project root:

```bash
# Development
make dev          # Start development environment
make test         # Run tests
make build        # Build for production

# Infrastructure (if applicable)
make deploy       # Deploy to environment
make destroy      # Teardown infrastructure

# Code Quality
make lint         # Run linters
make format       # Format code
```

## Development Workflow

### Making Changes
1. Create feature branch: `git checkout -b feature/description`
2. Make changes following project conventions
3. Run tests: `make test`
4. Submit PR for review

### Using Claude Code Agents
```bash
# Plan changes with team orchestration
/plan_w_team "Add user authentication feature"

# Review plan in specs/ directory
# Approve and execute
/build specs/[plan-name].md

# Agents will:
# 1. Build implementation (builder agent)
# 2. Run validation (validator agent)
# 3. Report results
```

## Code Conventions

### File Structure
```
src/
  components/   # React/Vue components OR business logic
  services/     # API clients, external services
  utils/        # Helper functions
  types/        # TypeScript types OR Python models
tests/          # Test files mirroring src/
docs/           # Documentation
```

### Naming Conventions
- Files: `kebab-case.js` or `snake_case.py`
- Functions: `camelCase` (JS/TS) or `snake_case` (Python)
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`

### Testing
- Write tests for new features
- Maintain >80% code coverage
- Use meaningful test descriptions

## Agent Guidelines

### When to Use Agents
- **builder**: For implementing features, creating files, writing code
- **validator**: For verifying implementations meet acceptance criteria
- **meta-agent**: For creating new specialized agents
- **work-completion-summary**: For audio summaries (use: "tts summary")

### Agent Best Practices
1. Always plan complex changes with `/plan_w_team`
2. Review plans before executing with `/build`
3. Let validators run after builders complete
4. Check logs/ directory for execution history

## Critical Patterns

### [Add project-specific patterns here]

Example:
```
- Always use environment variables for secrets
- Follow REST API conventions for endpoints
- Use transactions for database operations
- Handle errors gracefully with proper logging
```

## Troubleshooting

### Common Issues
1. **Issue**: [Common problem]
   **Solution**: [How to fix]

2. **Issue**: Build fails
   **Solution**: Run `make clean && make build`

3. **Issue**: Tests fail locally
   **Solution**: Ensure dependencies are up to date

## Resources

- [Project documentation](link)
- [API documentation](link)
- [Deployment guide](link)
EOF

    log_success "CLAUDE.md created (customize for your project)"
}

# Create .gitignore entries
update_gitignore() {
    log_info "Updating .gitignore..."

    if [ ! -f .gitignore ]; then
        touch .gitignore
    fi

    # Check if entries already exist
    if ! grep -q "# Claude Code" .gitignore; then
        cat >> .gitignore << 'EOF'

# Claude Code
.env
logs/
*.log
.claude/memory/*.md
EOF
        log_success ".gitignore updated"
    else
        log_warning ".gitignore already contains Claude Code entries"
    fi
}

# Create README for .claude directory
create_claude_readme() {
    log_info "Creating .claude/README.md..."

    cat > .claude/README.md << 'EOF'
# Claude Code Agent Configuration

This directory contains the Claude Code agent orchestration setup for this project.

## Directory Structure

```
.claude/
├── agents/
│   ├── team/
│   │   ├── builder.md        # Implementation agent (Opus)
│   │   └── validator.md      # Validation agent (Opus, read-only)
│   ├── meta-agent.md         # Creates new agents (Sonnet)
│   └── work-completion-summary.md  # Audio summaries (Sonnet)
├── hooks/
│   ├── *.py                  # Event hooks (session, tool use, etc.)
│   ├── validators/           # Code quality validators
│   └── utils/
│       ├── llm/              # LLM integrations (Anthropic, OpenAI, Ollama)
│       └── tts/              # Text-to-speech integrations
├── settings.json             # Permissions and hook configuration
└── README.md                 # This file
```

## Available Agents

### Team Agents (Execution)
- **builder** - Implements features, writes code (uses Opus)
- **validator** - Verifies implementations, read-only (uses Opus)

### Utility Agents
- **meta-agent** - Creates new custom agents (uses Sonnet)
- **work-completion-summary** - Generates audio summaries (uses Sonnet)

## Common Workflows

### Standard Development Flow
```bash
# 1. Plan the work
/plan_w_team "Feature description"

# 2. Review generated plan in specs/

# 3. Execute plan
/build specs/plan-name.md

# 4. Agents auto-execute:
#    - builder: Implements changes
#    - validator: Verifies quality
```

### Quick Changes
```bash
# For simple tasks, just describe what you need
# Claude will handle it directly without agent orchestration
"Add a health check endpoint"
```

### Create Custom Agent
```bash
# Use meta-agent to create specialized agents
"Create a security scanner agent"
# → meta-agent generates .claude/agents/security-scanner.md
```

## Hooks

Active hooks and their purposes:

- **PreToolUse**: Logs before tool execution
- **PostToolUse**: Logs after successful tool execution, runs validators
- **PostToolUseFailure**: Logs tool failures
- **SessionStart**: Logs session initialization, git status
- **SessionEnd**: Logs session termination
- **UserPromptSubmit**: Logs user prompts, names agents
- **SubagentStart**: Logs when agents start
- **SubagentStop**: Logs when agents complete, sends notifications

### Validators (Auto-run by builder)
- **ruff_validator.py**: Python linting
- **ty_validator.py**: Python type checking

## Logs

All events are logged to `logs/` directory:
- `logs/session_start.json` - Session initializations
- `logs/pre_tool_use.json` - All tool calls
- `logs/post_tool_use.json` - Successful tool executions
- `logs/post_tool_use_failure.json` - Failed tool executions
- `logs/subagent_start.json` - Agent launches
- `logs/subagent_stop.json` - Agent completions
- `logs/user_prompt_submit.json` - User inputs

## Configuration

### Add Project-Specific Permissions
Edit `settings.json`:
```json
{
  "permissions": {
    "allow": [
      "Bash(your-command:*)",
      // Add more commands
    ]
  }
}
```

### Add Project-Specific Validators
Create validator in `hooks/validators/`:
```python
#!/usr/bin/env -S uv run --script
# Your validation logic
```

Then add to builder agent hooks.

## Best Practices

1. **Plan complex changes** - Use `/plan_w_team` for multi-step work
2. **Review plans** - Always review generated plans before `/build`
3. **Let validators run** - They catch issues early
4. **Check logs** - Review logs/ for debugging
5. **Use specialized agents** - Create custom agents for repeated patterns

## Troubleshooting

### Agents not responding
- Check `logs/subagent_start.json` for errors
- Verify agent files in `.claude/agents/`
- Ensure settings.json is valid JSON

### Hooks not executing
- Check hook scripts have execute permissions
- Verify Python dependencies installed (`uv` available)
- Review `logs/post_tool_use_failure.json`

### Validators failing
- Check validator output in agent reports
- Run validators manually to debug
- Ensure project dependencies are installed

## Customization

This setup can be customized for your project:
1. Add specialized agents to `agents/`
2. Create project-specific validators in `hooks/validators/`
3. Update permissions in `settings.json`
4. Modify hook behavior in `hooks/*.py`

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Sub-agents Guide](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Hooks Reference](https://docs.anthropic.com/en/docs/claude-code/hooks)
EOF

    log_success ".claude/README.md created"
}

# Create example .env template
create_env_template() {
    log_info "Creating .env.example..."

    cat > .env.example << 'EOF'
# Environment Variables Template
# Copy to .env and fill in values

# Anthropic API (for LLM hooks)
ANTHROPIC_API_KEY=sk-ant-...

# Optional: Engineer name for personalized messages
ENGINEER_NAME=YourName

# Project-specific variables
# Add your project's environment variables below
EOF

    log_success ".env.example created"
}

# Print success summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Setup Complete! 🎉"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📁 Directory structure created:"
    echo "   ✓ .claude/agents/team/ (builder, validator)"
    echo "   ✓ .claude/hooks/ (event hooks + validators)"
    echo "   ✓ logs/ (execution logs)"
    echo "   ✓ specs/ (implementation plans)"
    echo "   ✓ docs/ (documentation)"
    echo ""
    echo "📝 Configuration files created:"
    echo "   ✓ .claude/settings.json (${PROJECT_TYPE} permissions)"
    echo "   ✓ CLAUDE.md (project documentation)"
    echo "   ✓ .claude/README.md (agent guide)"
    echo "   ✓ .env.example (environment template)"
    echo ""
    echo "🚀 Next Steps:"
    echo ""
    echo "1. Customize CLAUDE.md with your project details"
    echo "   ${BLUE}vi CLAUDE.md${NC}"
    echo ""
    echo "2. Create .env file for Anthropic API (optional but recommended)"
    echo "   ${BLUE}cp .env.example .env${NC}"
    echo "   ${BLUE}# Add your ANTHROPIC_API_KEY${NC}"
    echo ""
    echo "3. Test the setup with a simple task"
    echo "   ${BLUE}/plan \"Add a README file\"${NC}"
    echo ""
    echo "4. Review the generated plan and execute"
    echo "   ${BLUE}/build specs/[plan-name].md${NC}"
    echo ""
    echo "📚 Documentation:"
    echo "   - Agent guide: .claude/README.md"
    echo "   - Project guide: CLAUDE.md"
    echo "   - Logs location: logs/"
    echo ""
    echo "🎯 Quick Commands:"
    echo "   ${BLUE}/plan_w_team \"description\"${NC}  - Plan with team orchestration"
    echo "   ${BLUE}/build specs/plan.md${NC}         - Execute implementation plan"
    echo "   ${BLUE}/all_tools${NC}                   - List available tools"
    echo ""
    log_info "Happy coding with Claude Code agents! 🤖"
    echo ""
}

# Main execution
main() {
    print_header
    check_source
    create_directories
    copy_agents
    copy_hooks
    create_settings
    create_claude_md
    update_gitignore
    create_claude_readme
    create_env_template
    print_summary
}

# Run main function
main "$@"
