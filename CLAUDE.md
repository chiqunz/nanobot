# CLAUDE.md

Guide for AI assistants working on the nanobot codebase.

## Project Overview

nanobot is an ultra-lightweight personal AI assistant framework (~3,500 lines of core agent code, ~7,500 lines total Python). It connects to 13 LLM providers and 9 chat platforms through a modular architecture. Built with Python 3.11+, licensed under MIT.

**Package name**: `nanobot-ai` (PyPI)
**Entry point**: `nanobot.cli.commands:app`
**Config location**: `~/.nanobot/config.json`
**Workspace**: `~/.nanobot/workspace/`

## Repository Structure

```
nanobot/                  # Main Python package
├── agent/                # Core agent logic
│   ├── loop.py           # Agent processing loop (LLM ↔ tool execution)
│   ├── context.py        # Prompt builder & context assembly
│   ├── memory.py         # Two-layer persistent memory system
│   ├── skills.py         # Skills loader & management
│   ├── subagent.py       # Background task execution
│   └── tools/            # Built-in tools (11 tools)
│       ├── base.py       # Abstract Tool base class
│       ├── registry.py   # Tool registry
│       ├── filesystem.py # read_file, write_file, edit_file, list_dir
│       ├── shell.py      # exec tool with safety guards
│       ├── web.py        # web_search, web_fetch
│       ├── message.py    # message delivery
│       ├── spawn.py      # Spawn subagents
│       └── cron.py       # Schedule tasks
├── channels/             # Chat platform integrations (9 channels)
│   ├── base.py           # Base channel interface
│   ├── manager.py        # Channel lifecycle manager
│   ├── telegram.py, discord.py, whatsapp.py, feishu.py,
│   │   dingtalk.py, mochat.py, slack.py, email.py, qq.py
├── providers/            # LLM provider abstraction
│   ├── registry.py       # Provider registry (single source of truth)
│   ├── base.py           # LLMProvider base class
│   ├── litellm_provider.py  # LiteLLM wrapper
│   └── transcription.py  # Groq Whisper voice transcription
├── skills/               # Built-in skills (YAML frontmatter + Markdown)
│   ├── github/, weather/, summarize/, tmux/,
│   │   skill-creator/, memory/, cron/
├── session/manager.py    # JSONL-based session storage
├── config/schema.py      # Pydantic config schema
├── cron/                 # Scheduled task service
├── heartbeat/            # Proactive wake-up tasks
├── bus/                  # Message bus (events + queue)
├── cli/commands.py       # CLI commands
└── utils/helpers.py      # Common utilities
bridge/                   # WhatsApp bridge (TypeScript, Baileys SDK)
tests/                    # Test suite (pytest + pytest-asyncio)
workspace/                # Agent workspace templates
```

## Build & Development Commands

### Setup
```bash
pip install -e ".[dev]"       # Install with dev dependencies
```

### Running
```bash
nanobot chat                  # Interactive CLI chat
nanobot gateway               # Start gateway server (all channels)
```

### Testing
```bash
pytest                        # Run all tests
pytest tests/test_tool_validation.py  # Run specific test file
```

### Linting
```bash
ruff check nanobot/           # Lint check
ruff check --fix nanobot/     # Lint with auto-fix
ruff format nanobot/          # Format code
```

### Building
```bash
pip install build
python -m build               # Build wheel and sdist
```

### Docker
```bash
docker build -t nanobot .     # Build Docker image
```

## Code Style & Conventions

- **Line length**: 100 characters (E501 ignored by ruff)
- **Python target**: 3.11+
- **Linter**: ruff with rules E, F, I, N, W
- **Type hints**: Use modern Python syntax (`str | None` instead of `Optional[str]`, `dict[str, Any]` instead of `Dict`)
- **Async-first**: All tools, channels, and the agent loop are async
- **Logging**: Use `loguru.logger` (not stdlib `logging`)
- **Config validation**: Pydantic v2 models in `config/schema.py`
- **Data serialization**: JSONL for sessions, Markdown for memory/skills

## Architecture Patterns

### Agent Loop (`agent/loop.py`)
The core processing engine:
1. Receives messages from the message bus
2. Builds context (history, memory, skills) via `ContextBuilder`
3. Calls the LLM with tool definitions
4. Executes tool calls iteratively (max 20 iterations)
5. Sends responses back through the bus

### Tool Design (`agent/tools/base.py`)
All tools inherit from `Tool` ABC:
- `name` property — tool identifier for LLM function calls
- `description` property — human-readable description
- `parameters` property — JSON Schema dict
- `execute(**kwargs)` — async execution method
- `validate_params(dict)` — parameter validation
- `to_schema()` — OpenAI-compatible function schema

Tools are stateless and registered in `ToolRegistry`.

### Provider System (`providers/registry.py`)
Registry-driven provider management:
- **Single source of truth** — all 13 providers defined in one registry
- **Gateway detection** — OpenRouter and AiHubMix detected by API key prefix or base URL
- **Standard detection** — providers matched by model name keywords
- Adding a new provider requires only entries in `registry.py` and `config/schema.py`

### Memory System (`agent/memory.py`)
Two-layer memory:
- **MEMORY.md** — long-term facts (preferences, context, relationships)
- **HISTORY.md** — append-only event log (grep-searchable)

### Skills (`skills/`)
YAML frontmatter + Markdown instruction format (compatible with OpenClaw):
- **Always-loaded** skills are inlined into the system prompt
- **On-demand** skills are loaded via `read_file` when needed
- Each skill directory contains a `SKILL.md` file

### Channels (`channels/`)
All channels inherit from a base interface in `base.py`:
- Channels register with the message bus
- Messages flow: Channel → Bus → AgentLoop → Bus → Channel
- Per-channel-user sessions keyed as `channel:chat_id`

### Session Management (`session/manager.py`)
- JSONL format for persistence
- Per-channel-user sessions
- Message history with timestamps and metadata

## Key Files to Know

| File | Purpose |
|------|---------|
| `agent/loop.py` | Core agent processing loop |
| `agent/context.py` | System prompt and context assembly |
| `agent/tools/registry.py` | Tool registration and lookup |
| `providers/registry.py` | LLM provider definitions (single source of truth) |
| `config/schema.py` | Pydantic configuration schema |
| `channels/manager.py` | Channel lifecycle management |
| `cli/commands.py` | CLI entry points |
| `bus/queue.py` | Message bus implementation |

## Testing Conventions

- **Framework**: pytest with pytest-asyncio
- **Async mode**: `asyncio_mode = "auto"` (no need for `@pytest.mark.asyncio`)
- **Test paths**: `tests/` directory
- **Patterns**: Use async fixtures, mock/patch external dependencies
- **Test files**: `test_cli_input.py`, `test_tool_validation.py`, `test_email_channel.py`

## Security Considerations

- Shell execution (`agent/tools/shell.py`) blocks dangerous commands (rm -rf /, fork bombs, mkfs, dd)
- File operations respect `allowed_dir` boundary when `restrictToWorkspace` is enabled
- Channel access controlled via `allowFrom` whitelists
- API keys stored in `~/.nanobot/config.json` (should be mode 0600)
- WhatsApp bridge binds to localhost only (127.0.0.1:3001)
- Never commit API keys or `.env` files

## Common Patterns When Making Changes

**Adding a new tool**: Create a class in `agent/tools/` inheriting from `Tool`, implement `name`, `description`, `parameters`, and `execute()`. Register it in `agent/loop.py`.

**Adding a new provider**: Add an entry to the `PROVIDERS` dict in `providers/registry.py` and add config fields in `config/schema.py`.

**Adding a new channel**: Create a file in `channels/` inheriting from the base channel, implement the connection and message handling methods, register in `channels/manager.py` and add config in `config/schema.py`.

**Adding a new skill**: Create a directory under `skills/` with a `SKILL.md` file containing YAML frontmatter and Markdown instructions.

## Dependencies

Core dependencies include: `typer` (CLI), `litellm` (LLM abstraction), `pydantic` (validation), `httpx` (HTTP), `loguru` (logging), `rich` (terminal UI), `croniter` (scheduling), `prompt-toolkit` (interactive CLI). Channel-specific SDKs: `python-telegram-bot`, `lark-oapi`, `slack-sdk`, `qq-botpy`, `dingtalk-stream`, `python-socketio`, `msgpack`.

## Commit Message Style

Follow the conventional commits pattern used in this repo:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation
- `bump:` for version bumps
- `Merge pull request #N` for merge commits
