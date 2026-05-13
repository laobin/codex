# Codex Local Config

This repository stores reusable local Codex configuration:

- `AGENTS.md`: global Codex working protocol
- `agents/`: local Codex agent definitions
- `skills/`: local Codex skills
- `config.example.toml`: Codex configuration template, including MCP server definitions

Sensitive runtime files are intentionally excluded. The real local `config.toml` is ignored because it can contain tokens. The TAPD MCP token in `config.example.toml` is represented by `${TAPD_ACCESS_TOKEN}` and should be provided locally through the environment or a private local override.
