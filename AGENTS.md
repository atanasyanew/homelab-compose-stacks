# AGENTS.md
Operational guide for coding agents in this repository.

## Repository overview
- This repo is a modular Docker Compose collection for homelab/self-hosting.
- Root files are mostly `compose.<app>.yaml` modules and `compose.<stack>.yaml` entrypoints.
- Standalone media stack lives at `Standalone stacks/media-server/docker-compose.yml`.
- Primary repo guidance: `CLAUDE.md` and `README.md`.

## Rules files (Cursor / Copilot)
- Searched for `.cursor/rules/`, `.cursorrules`, and `.github/copilot-instructions.md`.
- None found.
- If added later, treat them as mandatory and update this file.

## Key paths
- Modules: `compose.*.yaml` (preferred) / `compose.*.yml` (legacy)
- Stack example: `compose.iot-stack.yaml`
- Env files: `provision/<app>.env`
- Scripts: `scripts/<scope>/...` for operational helper automation
- Persistent data: `volumes/<app>/...`
- Standalone stack: `Standalone stacks/media-server/`

## Build / lint / test commands
There is no traditional compile/build step in repo root.
Use Docker Compose validation plus runtime smoke checks.

### Prerequisites
- Docker daemon running
- Docker Compose v2 (`docker compose`)
- Optional: `yamllint`

### Single test (recommended)
Fastest check for one changed file:

```bash
docker compose -f compose.n8n.yaml config -q
```

General form:

```bash
docker compose -f compose.<app-or-stack>.yaml config -q
```

### Validate all root compose files
```bash
for f in compose.*.y*ml; do docker compose -f "$f" config -q; done
```

### Run one module
```bash
docker compose -f compose.n8n.yaml up -d
```

### Run one stack entrypoint
```bash
docker compose -f compose.iot-stack.yaml up -d
```

### Run standalone media stack
```bash
docker compose -f "Standalone stacks/media-server/docker-compose.yml" up -d
```

### Single-service smoke test
```bash
docker compose -f compose.n8n.yaml up -d n8n-db n8n && docker compose -f compose.n8n.yaml ps
```

### Logs and shutdown
```bash
docker compose -f compose.n8n.yaml logs --no-color --tail=200 n8n
docker compose -f compose.n8n.yaml down
```

### Optional YAML lint
```bash
yamllint compose.*.y*ml
yamllint "Standalone stacks/media-server/docker-compose.yml"
```

## Pre-handoff checklist
- Validate every edited compose file with `docker compose ... config -q`.
- If behavior changed, run `up -d` and verify `ps`.
- For stack edits, validate stack and at least one included module.
- Record commands run in your handoff note.

## Code style guidelines
This repo is YAML-first. Keep config explicit and predictable.

### Naming conventions
- Module filename: `compose.<app>.yaml`
- Stack filename: `compose.<stack>.yaml`
- Use one app identity everywhere:
  - Service: `<app>`
  - Sidecars: `<app>-db`, `<app>-redis`, etc.
  - Env file: `./provision/<app>.env`
  - Volumes: `./volumes/<app>/<purpose>:<container-path>`
- Never use generic names like `db`, `redis`, `app`, `backend`, `frontend`.

### Formatting
- Use 2-space indentation.
- Keep blank lines between services.
- Quote port mappings, e.g. `"5678:5678"`.
- Keep `env_file` as a list even for one item.
- Prefer stable key order:
  - `container_name`, `image`, `restart`, `depends_on`, `env_file`, `environment`, `volumes`, `ports`/`expose`, `healthcheck`, `network_mode`.

### Container/network policy
- Follow current repo convention: set `container_name` matching service identity.
- Prefer default bridge network unless host mode is required.
- Use `network_mode: host` only for LAN/hardware-critical services.
- Prefer internal exposure over host ports unless external access is required.
- In Docker Desktop/WSL environments, prefer explicit `ports` for browser-facing UIs; `network_mode: host` can be unreachable from Windows browsers.

### Volumes, env, secrets
- Persist only under `./volumes/<app>/...`.
- Store vars in `./provision/<app>.env`.
- Do not hardcode secrets in compose YAML.
- Treat env files as sensitive.
- For database engines in Docker Desktop/WSL, prefer named volumes for DB data when bind-mount permissions cause startup failures.

### Volume layout template (recommended)
- Keep folders purpose-based so backup/restore and troubleshooting stay predictable.
- For db-backed apps, use:
  - `./volumes/<app>/db` for database files
  - `./volumes/<app>/data` for app runtime data
  - `./volumes/<app>/config` for app configuration
  - `./volumes/<app>/cache` only when cache persistence is intentional
- For stateless/web apps, prefer:
  - `./volumes/<app>/config`
  - `./volumes/<app>/data` only if the app writes required state
- For media apps, separate domains:
  - `./volumes/<app>/config`
  - `./volumes/<app>/downloads` (incomplete or transient payloads)
  - `./volumes/<app>/library` (organized persistent media)
- Use read-only bind mounts when possible (e.g. `/etc/localtime:/etc/localtime:ro`).
- Do not share writable `db` volumes across apps.
- Avoid manually editing runtime files under `volumes/` except for recovery/migrations.

### Error handling and reliability
- Add health checks for stateful dependencies where possible.
- Use `depends_on` conditions when startup order matters.
- Keep health checks lightweight and deterministic (`pg_isready`, `redis-cli ping`).
- Use explicit restart policies (`unless-stopped` or `always`).

### Imports / includes
- In this repo, imports are Compose `include:` entries.
- Use explicit relative includes, e.g. `./compose.<app>.yaml`.
- Re-validate stack config after include changes.

### Types, scripts, and naming in helper code
- YAML has no static typing; use `docker compose config -q` as the type/syntax gate.
- If adding scripts:
  - Shell: `set -euo pipefail`
  - Python: type hints on public functions
- Script/function names should be descriptive and app-scoped when possible.

### Imports and formatting in helper code
- Keep imports grouped and sorted (stdlib, third-party, local) in Python.
- Avoid unused imports and dead code.
- Keep lines readable and formatting consistent with existing files.

### Error handling in helper code
- Fail fast on missing files/env vars with clear messages.
- Return non-zero exit codes on automation failures.
- Log actionable context (service/file affected), not secrets.

### Comments and docs
- Add comments only when behavior is non-obvious.
- Keep comments operational, short, and current.
- Update docs when adding modules or changing stack behavior.
- Do not edit runtime-generated data under `volumes/` unless explicitly requested.

## Agent workflow tips
- Make minimal, targeted edits; avoid unrelated refactors.
- Follow adjacent compose patterns before introducing new structure.
- When both `.yml` and `.yaml` variants exist, edit the one referenced by stack `include:` unless asked to consolidate.

## Definition of done
- Edited files pass `docker compose ... config -q`.
- Relevant services start without immediate crash-loop.
- Naming/env/volume conventions remain consistent.
- No secrets are introduced in tracked files.
- For web UIs, verify an HTTP(S) endpoint responds (`curl -I`) in addition to `ps` and logs.
