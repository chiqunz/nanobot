# CLAUDE.md — Coding Agent Guide for nanobot

## Project Overview

**nanobot** is an ultra-lightweight personal AI assistant framework (~3,500 lines of core agent code). It's a Python-based agentic system that connects to multiple LLM providers and chat platforms, with a tool-use loop at its core. The project prioritizes simplicity, readability, and minimal footprint.

- **Package name**: `nanobot-ai` (on PyPI)
- **License**: MIT
- **Python**: ≥ 3.11
- **Build system**: Hatchling
- **GitHub**: `HKUDS/nanobot`

## Quick Commands

```bash
# Install from source (development)
pip install -e .

# Run linter
ruff check nanobot/

# Run tests
pytest tests/

# Run the agent (single message)
nanobot agent -m "Hello"

# Run the agent (interactive)
nanobot agent

# Start the gateway (all channels)
nanobot gateway

# Check status
nanobot status

# Count core agent lines
bash core_agent_lines.sh
```

## Architecture

The system follows a **message bus** pattern that decouples chat channels from the agent core:

```
Channels (Telegram, Discord, etc.)
    │
    ▼
MessageBus (async queues)
    │
    ▼
AgentLoop (LLM ↔ tool execution cycle)
    │
    ├── ContextBuilder (system prompt assembly)
    ├── ToolRegistry (dynamic tool management)
    ├── SessionManager (conversation persistence)
    ├── MemoryStore (long-term memory + history)
    ├── SkillsLoader (pluggable skill documents)
    └── SubagentManager (background tasks)
```

### Core Flow
1. A channel receives a user message → publishes `InboundMessage` to the bus
2. `AgentLoop` consumes the message, builds context (system prompt + history + memory + skills)
3. Calls the LLM via `LiteLLMProvider`
4. If LLM returns tool calls → executes them via `ToolRegistry` → feeds results back → loops
5. When LLM returns a text-only response → sends `OutboundMessage` back through the bus
6. The channel picks it up and delivers to the user

### Key Design Decisions
- **LiteLLM** is the unified LLM interface — all providers route through it
- **Provider Registry** (`providers/registry.py`) is the single source of truth for provider metadata
- **Config is camelCase JSON** on disk (`~/.nanobot/config.json`) but **snake_case** internally (Pydantic)
- **Sessions are JSONL** files stored in `~/.nanobot/sessions/`
- **Memory** is a two-layer system: `MEMORY.md` (long-term facts) + `HISTORY.md` (grep-searchable log)
- **Skills** are markdown files (`SKILL.md`) with optional YAML frontmatter — progressively loaded
- **Interleaved CoT**: after tool execution, a "Reflect on the results" prompt is injected

## Project Structure

```
nanobot/
├── agent/              # Core agent logic
│   ├── loop.py         # AgentLoop — the main LLM↔tool cycle
│   ├── context.py      # ContextBuilder — system prompt assembly
│   ├── memory.py       # MemoryStore — MEMORY.md + HISTORY.md
│   ├── skills.py       # SkillsLoader — discovers and loads skills
│   ├── subagent.py     # SubagentManager — background task execution
│   └── tools/          # Tool implementations
│       ├── base.py     # Tool ABC (name, description, parameters, execute)
│       ├── registry.py # ToolRegistry — dynamic tool management
│       ├── filesystem.py # read_file, write_file, edit_file, list_dir
│       ├── shell.py    # exec — shell command execution
│       ├── web.py      # web_search (Brave), web_fetch (readability)
│       ├── message.py  # message — send to chat channels
│       ├── spawn.py    # spawn — launch subagents
│       └── cron.py     # cron — scheduling tool
├── bus/                # Message routing
│   ├── events.py       # InboundMessage, OutboundMessage dataclasses
│   └── queue.py        # MessageBus — async pub/sub queues
├── channels/           # Chat platform integrations
│   ├── base.py         # BaseChannel ABC (start, stop, send, is_allowed)
│   ├── manager.py      # ChannelManager — starts/stops all channels
│   ├── telegram.py     # Telegram bot channel
│   ├── discord.py      # Discord bot channel
│   ├── whatsapp.py     # WhatsApp via Node.js bridge
│   ├── feishu.py       # Feishu/Lark (WebSocket)
│   ├── dingtalk.py     # DingTalk (Stream mode)
│   ├── mochat.py       # Mochat (Socket.IO)
│   ├── slack.py        # Slack (Socket mode)
│   ├── email.py        # Email (IMAP/SMTP)
│   └── qq.py           # QQ (botpy SDK)
├── cli/
│   └── commands.py     # Typer CLI (onboard, agent, gateway, status, cron, channels)
├── config/
│   ├── schema.py       # Pydantic config models (Config, ProvidersConfig, ChannelsConfig, etc.)
│   └── loader.py       # JSON load/save with camelCase↔snake_case conversion
├── cron/
│   ├── service.py      # CronService — job scheduling engine
│   └── types.py        # CronJob, CronSchedule dataclasses
├── heartbeat/
│   └── service.py      # HeartbeatService — periodic wake-up (30min)
├── providers/
│   ├── base.py         # LLMProvider ABC
│   ├── litellm_provider.py  # LiteLLMProvider — unified LLM interface
│   ├── registry.py     # ProviderSpec + PROVIDERS tuple — provider metadata registry
│   └── transcription.py # Voice transcription (Groq Whisper)
├── session/
│   └── manager.py      # SessionManager + Session — JSONL conversation persistence
├── skills/             # Built-in skill definitions (markdown)
│   ├── cron/SKILL.md
│   ├── github/SKILL.md
│   ├── memory/SKILL.md
│   ├── skill-creator/SKILL.md
│   ├── summarize/SKILL.md
│   ├── tmux/SKILL.md
│   └── weather/SKILL.md
└── utils/
    └── helpers.py      # Path utilities (ensure_dir, safe_filename, etc.)

bridge/                 # Node.js WhatsApp bridge (TypeScript)
workspace/              # Default workspace template files
├── AGENTS.md           # Agent behavior instructions (bootstrap)
├── SOUL.md             # Agent personality (bootstrap)
├── USER.md             # User info (bootstrap)
├── TOOLS.md            # Tool documentation (bootstrap)
├── HEARTBEAT.md        # Periodic tasks checked every 30min
└── memory/
    ├── MEMORY.md       # Long-term memory (facts, preferences)
    └── HISTORY.md      # Grep-searchable conversation log

tests/                  # Test suite
├── test_tool_validation.py
├── test_cli_input.py
└── test_email_channel.py
```

## Code Conventions

### Style
- **Linter**: Ruff (configured in `pyproject.toml`)
- **Line length**: 100 characters (E501 is ignored/allowed to exceed)
- **Ruff rules**: E, F, I (isort), N (naming), W
- **Target**: Python 3.11
- **Type hints**: Used throughout — `str | None` syntax (not `Optional[str]`)
- **Imports**: Standard library → third-party → local (enforced by ruff isort)

### Patterns
- **Async throughout**: All core operations are `async/await`
- **Dataclasses** for simple data containers (`InboundMessage`, `OutboundMessage`, `Session`, `CronJob`)
- **Pydantic BaseModel** for configuration schemas
- **ABC** for interfaces (`Tool`, `BaseChannel`, `LLMProvider`)
- **loguru** for logging (not stdlib `logging`)
- **`from __future__ import annotations`** used in some files (e.g., `registry.py`)

### Naming
- **Files**: snake_case (e.g., `litellm_provider.py`)
- **Classes**: PascalCase (e.g., `AgentLoop`, `ToolRegistry`)
- **Config fields**: snake_case in Python, camelCase in JSON config file
- **Tool names**: snake_case (e.g., `read_file`, `web_search`, `list_dir`)

### Config System
- Config lives at `~/.nanobot/config.json` (camelCase JSON)
- Internally uses Pydantic models with snake_case field names
- `loader.py` converts between formats via `camel_to_snake`/`snake_to_camel`
- Environment variables supported via `NANOBOT_` prefix with `__` nesting

## How to Add Things

### Adding a New Tool
1. Create a class extending `Tool` in `nanobot/agent/tools/`
2. Implement the 4 required properties/methods:
   - `name: str` — tool name for function calling
   - `description: str` — what the tool does
   - `parameters: dict` — JSON Schema for parameters
   - `execute(**kwargs) -> str` — async implementation
3. Register it in `AgentLoop._register_default_tools()` in `loop.py`

### Adding a New LLM Provider
1. Add a `ProviderSpec` entry to `PROVIDERS` tuple in `nanobot/providers/registry.py`
2. Add a `ProviderConfig` field to `ProvidersConfig` in `nanobot/config/schema.py`
3. That's it — env vars, model prefixing, config matching all derive automatically

### Adding a New Chat Channel
1. Create a class extending `BaseChannel` in `nanobot/channels/`
2. Implement: `start()`, `stop()`, `send(msg)`
3. Add config model to `nanobot/config/schema.py` (e.g., `MyChannelConfig`)
4. Add the field to `ChannelsConfig`
5. Register in `ChannelManager` (`nanobot/channels/manager.py`)

### Adding a New Skill
1. Create `nanobot/skills/{skill-name}/SKILL.md` (or user workspace `skills/`)
2. Optional: Add YAML frontmatter with metadata, requirements, `always: true`
3. Skills are auto-discovered — no code changes needed

## Testing

```bash
# Run all tests
pytest tests/

# Run specific test
pytest tests/test_tool_validation.py

# Run with asyncio mode (configured in pyproject.toml)
pytest  # asyncio_mode = "auto" is already set
```

- Tests use **pytest** + **pytest-asyncio**
- Test files are in `tests/` directory
- Async tests work automatically (`asyncio_mode = "auto"`)
- Tool validation has good test coverage (`test_tool_validation.py`)

## Important Files to Know

| File | Why it matters |
|------|---------------|
| `agent/loop.py` | The heart of the system — the LLM↔tool execution cycle |
| `agent/context.py` | How the system prompt is assembled (bootstrap files + memory + skills) |
| `config/schema.py` | All configuration models — modify when adding features |
| `providers/registry.py` | Provider metadata — modify when adding LLM providers |
| `agent/tools/base.py` | Tool interface — understand before creating new tools |
| `channels/base.py` | Channel interface — understand before adding channels |
| `bus/events.py` | Message types that flow through the system |
| `cli/commands.py` | CLI entry points — the `gateway` and `agent` commands |

## Gotchas & Notes

- **Line count matters**: The project prides itself on being ~3,500 lines. Run `bash core_agent_lines.sh` to verify. Keep code minimal.
- **Config key conversion**: JSON config uses camelCase, Python uses snake_case. The conversion happens in `config/loader.py`. Be careful when adding config fields.
- **Bootstrap files**: `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md` in the workspace directory are loaded into the system prompt. They're defined in `ContextBuilder.BOOTSTRAP_FILES`.
- **Memory consolidation**: When session messages exceed `memory_window` (default 50), old messages are summarized by the LLM and saved to `MEMORY.md`/`HISTORY.md`, then trimmed from the session.
- **Security**: Dangerous shell commands are blocked (rm -rf /, fork bombs, etc.). File operations have path traversal protection. `restrictToWorkspace` option sandboxes all tools.
- **WhatsApp bridge**: Is a separate Node.js/TypeScript project in `bridge/` — communicates with the Python backend via WebSocket on localhost:3001.
- **No rate limiting**: The framework doesn't implement rate limiting — that's left to the user/deployment.
- **Session key format**: `{channel}:{chat_id}` (e.g., `telegram:123456789`, `cli:direct`)
