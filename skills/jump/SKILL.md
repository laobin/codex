---
name: jump
description: Resolve an existing project workspace from a user prompt and switch subsequent work into that directory. Use when the user asks to enter a project, switch to a repo, or start work in a folder by name or path.
---

# Jump

Use this skill when the user wants Codex to start working in a specific existing directory.

## Goal

Turn a natural-language request such as "进入 all-in-ai 项目" or "去 d/code 下的 test" into one concrete existing workspace path.

## Workflow

1. Extract the target from the user prompt.
2. Run `scripts/resolve-workspace.ps1` with the raw prompt text.
3. If the script returns an existing path, use that path as the `workdir` for all subsequent shell commands in the task.
4. If the script reports that no existing directory matched, stop and tell the user which path or project name was attempted.
5. Tell the user which directory was selected when it is materially useful.
6. If the user commonly refers to a workspace by a nickname, maintain `workspace-aliases.json` in this skill directory and let the script resolve aliases before general matching.

## Resolution Rules

- Prefer explicit absolute paths from the prompt.
- Normalize drive-relative Windows inputs like `d:code/foo` to `D:\code\foo`.
- If the prompt names a project without a full path, first search common workspace roots:
  - `D:\code`
  - `C:\Users\zhang`
- Prefer an exact directory-name match over fuzzy matches.
- Check configured aliases before general project-name extraction.
- If multiple matches exist, choose the shallowest path under the preferred roots.
- If nothing matches, do not create a directory. Return the intended target and explain that no existing workspace was found.
- If the prompt references a parent location plus a project name, resolve it under that parent and verify that it already exists.

## Notes

- "Entering" a directory means all later tool calls in the task must use the resolved path as `workdir`.
- This skill should not create target workspaces. Its job is path resolution and workspace switching.
- If the prompt is ambiguous and multiple different targets are equally plausible, state the assumption you chose.
