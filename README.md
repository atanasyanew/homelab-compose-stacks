# Homelab Docker Compose Collection

## Overview

This repository is a modular Docker Compose homelab collection.
Each app is defined as a reusable module (`compose.<app>.yaml`), and machine-specific stacks combine modules with `include:` in `compose.stack.<name>.yaml`.
Runtime configuration lives in `provision/<app>.env`, persistent data lives in `volumes/<app>/...`, and optional local overrides (for example `*.prod.env`) let you customize per machine without modifying tracked module files.

## Environment files

### `.env` vs `provision/*.env`

- Root `.env` is for Compose interpolation values used in compose files (for example `${CONTENT_ROOT}` in volume paths).
- `provision/<app>.env` (and optional `provision/<app>.prod.env`) are loaded with `env_file:` and provide runtime environment variables to containers.
- Service `env_file:` values are not a replacement for Compose interpolation sources; use root `.env`, exported shell vars, or `docker compose --env-file ...` when a compose file needs `${VAR}` resolution.

## Modules and stacks

### Repo layout

```text
repo/
├── compose.<appName1>.yaml
├── compose.<appName2>.yaml
├── compose.<appName3>.yaml
├── provision/
│   ├── <appName1>.env
│   ├── <appName2>.env
│   └── <appName3>.env
├── volumes/
│   ├── <appName1>/
│   ├── <appName2>/
│   └── <appName3>/
└── README.md
```

## Naming conventions

### Rules

1. File naming

app modules: compose.<app>.yaml

runnable stacks: compose.stack.<name>.yaml

Prefer `.yaml` as the repo convention. Keep `.yml` only for legacy files until they are consolidated.

Examples:

compose.aqualinks.yaml
compose.paperless.yaml
compose.stack.media.yaml

2. App identity

Each module has exactly one app identity, reused everywhere:

service names
network names
volume names
comments
env file

If app is aqualinks, use:
service: aqualinks
sidecars: aqualinks-db, aqualinks-redis
env file: ./provision/aqualinks.env
bind paths: ./volumes/aqualinks/...

3. No generic names

Never use:
app
db
redis
backend
frontend

Always prefix:
aqualinks-db
paperless-redis

4. Prefer bind mounts only under one convention

Always:

./volumes/<app>/<purpose>:<container_path>

Examples:

- ./volumes/aqualinks/data:/data
- ./volumes/paperless/media:/usr/src/paperless/media

5. Env files always here

Always:

env_file:
  - ./provision/<app>.env

Not nested unless truly needed.

For DB-backed apps, keep app and database vars in `./provision/<app>.env` and avoid hardcoding secrets in compose files.

6. Keep host ports minimal

Prefer expose or reverse proxy integration over direct ports.

7. Every module should run alone

You should be able to do:
docker compose -f compose.aqualinks.yaml up -d
without requiring a stack file.

## Validation and run commands

### Runtime verification checklist

After editing a module, validate and smoke test with:

```bash
docker compose -f compose.<app>.yaml config -q
docker compose -f compose.<app>.yaml up -d
docker compose -f compose.<app>.yaml ps
docker compose -f compose.<app>.yaml logs --no-color --tail=80 <service>
curl -I http://localhost:<port>
```

Use `https://` when the service exposes TLS.

8. Docker Desktop / WSL networking note

For browser-facing UIs on Docker Desktop/WSL, prefer explicit `ports` mappings.
`network_mode: host` may work inside Linux but still be unreachable from Windows browsers.

9. DB storage note for Docker Desktop / WSL

If a database container fails with permission errors on bind mounts (for example Postgres under `./volumes/<app>/db`), switch DB data to a named volume.

### Module template
This is the pattern used for every app module.

For example

```yaml
services:

  aqualinks:
    image: ghcr.io/example/aqualinks:latest
    container_name: aqualinks
    env_file:
      - ./provision/aqualinks.env
    volumes:
      - ./volumes/aqualinks/data:/data
    ports:
      - "80:80"
    restart: unless-stopped

networks:
  default:
```

Template for app with database, Example:

```yaml
services:

  paperless-db:
    image: postgres:16
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: paperless
    volumes:
      - ./volumes/paperless/db:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U paperless -d paperless"]
      interval: 20s
      timeout: 5s
      retries: 5

  paperless-redis:
    image: redis:7
    restart: unless-stopped

  paperless:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    env_file:
      - ./provision/paperless.env
    depends_on:
      paperless-db:
        condition: service_healthy
      paperless-redis:
        condition: service_started
    volumes:
      - ./volumes/paperless/data:/usr/src/paperless/data
      - ./volumes/paperless/media:/usr/src/paperless/media
      - ./volumes/paperless/consume:/usr/src/paperless/consume
    ports:
      - "8000"
    restart: unless-stopped
```

### Stack file template

This is the file you actually run.

include:
  - ./compose.immich.yaml
  - ./compose.paperless.yaml
  - ./compose.aqualinks.yaml

Run with:

```bash
docker compose -f compose.stack.media.yaml up -d
```

Name stacks as compose.stack.<name>.yaml for consistent grouping.

### Stack override template

Useful when a specific stack needs custom host ports or other tweaks.

name: media-stack

```yaml
include:
  - ./compose.immich.yaml
  - ./compose.paperless.yaml

services:
  immich:
    ports:
      - "2283:2283"

  paperless:
    ports:
      - "8010:8000"
```

Or if replacing a list:

```yaml
services:
  paperless:
    ports: !override
      - "8010:8000"
```

### Environment override pattern (base + optional prod)

Use this when you want per-machine or production values without editing module files.

Preferred: define this directly in the app module (`compose.<app>.yaml`) so every stack that includes it gets the same behavior.

```yaml
services:
  open-webui:
    env_file:
      - ./provision/open-webui.env
      - path: ./provision/open-webui.prod.env
        required: false
```

Optional: if you need this only for one stack, apply it in the stack file with a `services:` override (and use `!override` when replacing an existing list from included modules).

Behavior:

- Both files are loaded in order.
- If a key exists in both files, the later file wins (`<app>.prod.env`).
- Keys missing from `<app>.prod.env` remain from `<app>.env`.
- If `<app>.prod.env` is absent, Compose still runs because `required: false`.

To keep machine-specific files out of git, ignore them (example):

```gitignore
**/*.prod.env
```

### Safe assumptions

every file compose.<app>.yaml is a reusable and runnable module
every file compose.stack.<name>.yaml may be a runnable stack entrypoint

./provision/<app>.env belongs to app <app>
./volumes/<app>/... belongs to app <app>

### Never do

invent generic service names
reuse db, redis, app
merge modules that expose conflicting host ports without changing them

assume two apps can share the same database service unless explicitly designed that way

### Practical concerns

1. container_name

Avoid ``container_name`` in reusable modules.

Why: it can create collisions if you run multiple projects

Compose already names containers well enough

So prefer:

```yaml
services:
  aqualinks:
    image: ...
```

without:
``container_name: aqualinks``

Unless you have a very specific reason.

2. top-level custom networks

Don't define custom shared networks unless necessary.
Default network is usually enough.

3. direct ports

Only use them when the app truly needs direct access.
Otherwise keep apps internal.

4. secret material in env files

Good for homelab, but for anything sensitive, document that .env may contain secrets and should not be committed.

### Best minimal contract

If you want the shortest workable standard, make it this:

For every compose.<app>.yaml: 
unique service names prefixed by app
env file is ./provision/<app>.env
bind mounts are ./volumes/<app>/...

no generic resource names
runnable standalone
internal-only by default
For every compose.stack.<name>.yaml:

has name: <stack>

uses include:

may override ports or settings if needed

### Example final set

compose.aqualinks.yaml

```yaml
services:

  aqualinks:
    image: ghcr.io/example/aqualinks:latest
    env_file:
      - ./provision/aqualinks.env
    volumes:
      - ./volumes/aqualinks/data:/data
    expose:
      - "80"
    restart: unless-stopped
```

compose.paperless.yaml

```yaml
services:
  paperless-db:
    image: postgres:16
    volumes:
      - ./volumes/paperless/db:/var/lib/postgresql/data
    restart: unless-stopped

  paperless-redis:
    image: redis:7
    restart: unless-stopped

  paperless:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    env_file:
      - ./provision/paperless.env
    depends_on:
      - paperless-db
      - paperless-redis
    volumes:
      - ./volumes/paperless/data:/usr/src/paperless/data
      - ./volumes/paperless/media:/usr/src/paperless/media
      - ./volumes/paperless/consume:/usr/src/paperless/consume
    expose:
      - "8000"
    restart: unless-stopped

```

compose.stack.media.yaml

```yaml

include:
  - ./compose.aqualinks.yaml
  - ./compose.paperless.yaml

```

## Operational notes

- Compose interpolation (`${VAR}` in compose files) should come from root `.env`, exported shell vars, or `docker compose --env-file ...`; service-level `env_file` is runtime-only.
- On Docker Desktop/WSL, browser-facing services are more reliable with explicit `ports` mappings than `network_mode: host`.
- On Docker Desktop/WSL, stateful bind mounts can fail with permission/path issues; use named volumes when reliability matters.
- Keep heavy platforms (for example Kasm Workspaces) in standalone stacks instead of bundling them into general app stacks.
- Validate every changed compose file with `docker compose -f <file> config -q` before `up -d`.
