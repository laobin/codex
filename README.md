# Codex Local Config

This repository stores reusable local Codex configuration:

- `AGENTS.md`: global Codex working protocol
- `agents/`: local Codex agent definitions
- `skills/`: local Codex skills
- `config.toml`: Codex configuration, including MCP server definitions

Sensitive runtime files are intentionally excluded. The TAPD MCP token is represented by `${TAPD_ACCESS_TOKEN}` and should be provided locally through the environment or a private local override.
