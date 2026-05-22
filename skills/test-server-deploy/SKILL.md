---
name: test-server-deploy
description: Update test-server projects through the restricted Deploy API. Use when the user asks to update, deploy, refresh, or publish code to the test server, especially phrases like "更新测试服", "部署测试服", "更新测试服 cms", or "deploy test server"; reads DEPLOY_API_SECRET from the environment, defaults DEPLOY_API_BASE_URL to http://120.79.75.254:888, and only calls the update API without SSH, shell, or file upload.
---

# Test Server Deploy

## Overview

Use this skill to trigger the test-server Deploy API from the local machine. It does not SSH to the server, upload files, expose shell commands, or call the disabled frontend upload endpoint.

## Workflow

1. Determine the project name from the user request, such as `cms`.
2. If the user only says "更新测试服", infer the project from the current workspace using `project-aliases.json`.
3. If the project name is ambiguous, use the `jump` skill's workspace resolution first; use the resolved workspace folder name only when it clearly matches the test-server project name.
4. Read `DEPLOY_API_SECRET` from the environment. Do not ask the user to paste the secret into chat.
5. Use `DEPLOY_API_BASE_URL` from the environment when present; otherwise default to `http://120.79.75.254:888`.
6. Run `scripts/deploy-update.ps1 -Project <project>` to call `/api/update`, or omit `-Project` when the current workspace can be inferred.
7. Report `ok`, `project`, `code`, and trimmed stdout/stderr. If the API rejects the request, report the HTTP status and detail.

## Commands

Optional health check, only when `/api/health` is proxied:

```powershell
& "$env:USERPROFILE\.codex\skills\test-server-deploy\scripts\deploy-update.ps1" -Health
```

Update a project:

```powershell
& "$env:USERPROFILE\.codex\skills\test-server-deploy\scripts\deploy-update.ps1" -Project cms
```

Infer project from current workspace:

```powershell
& "$env:USERPROFILE\.codex\skills\test-server-deploy\scripts\deploy-update.ps1"
```

Use a temporary base URL override:

```powershell
& "$env:USERPROFILE\.codex\skills\test-server-deploy\scripts\deploy-update.ps1" -BaseUrl http://120.79.75.254:888 -Project cms
```

## Safety Rules

- Never print `DEPLOY_API_SECRET`.
- Never call SSH, remote shell, `run_shell`, upload tools, or `/api/publish-frontend`.
- Do not pass branch, target directory, script path, shell args, or server paths.
- `project` is passed through to `phpUpdate <project>` by the server after basic format validation; keep project names simple, for example `cms`.

## Project Aliases

Maintain local workspace mappings in `project-aliases.json` inside this skill. Use `nameAliases` when the local folder name matches or can map to a test-server project, and `pathAliases` for exact local paths that need special handling.

Example:

```json
{
  "pathAliases": {
    "E:\\code\\cms-admin": "cms"
  },
  "nameAliases": {
    "cmsystem": "cms",
    "cms": "cms"
  }
}
```
