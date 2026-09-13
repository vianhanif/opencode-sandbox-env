# opencode-sandbox-env — Lightweight AI Agent Sandbox (Revised per Review + Browser-Access Discussion)

## Problem
Replace bloated Hermes stack with a lightweight, composable AI coding agent sandbox on Tencent Cloud VPS: **Firstmate** (agent distro / orchestration) + **OpenCode** (coding harness, browser + TUI) + **9router** (model routing). Revised after plan review — original layering was wrong. Second ChatGPT discussion adds native browser access via `opencode web` + Caddy + Cloudflare Tunnel.

## Corrected Architecture (per review + browser-access discussion)
* **ONE container**, not separate worker containers: OpenCode hosts Firstmate; crewmates = **tmux windows** in a single container.
* **Firstmate sits ABOVE OpenCode, not beside it** (captain → agent → crew). It is an agent distro (AGENTS.md + skills + bash scripts) running *inside* the harness — not a daemon.
* **Two interfaces, one backend**: Browser = captain/observation console (`opencode web :4096`); tmux + SSH = operational/debug. Both attach to the **same OpenCode backend/session** (`opencode attach`).
* **Do NOT tunnel the tmux TUI.** Run OpenCode server persistently; clients attach to it. No TUI mirroring.
* **Caddy + cloudflared RE-INTRODUCED** — an HTTP surface now exists (`opencode web`). Browser → Cloudflare Tunnel → Caddy → `127.0.0.1:4096`. Password auth via `OPENCODE_SERVER_PASSWORD`. Never expose 4096 directly.
* **AGENTS.md authority**: Firstmate ships its own authoritative AGENTS.md + `.agents/skills`. Do NOT overlay user's `~/.agents` — one authority only.
* **9router** external/co-located model routing via `ROUTER9_GATEWAY_URL`; sits under all workers (Firstmate primary + crew are all OpenCode).
* **OpenCode is a verified Firstmate harness** with a TUI-plugin supervision path (softens earlier concern; still checkpoint it).
* Persist **FM_HOME** layout: `projects/`, `data/`, `state/`, `config/`, `scratchpad*` + `.ssh` (ro) + OpenCode session state.

## Target Architecture
```
Browser ──HTTPS──> opencode.<domain> ──Cloudflare Tunnel──> Caddy ──> 127.0.0.1:4096
                                                                         │
                                                              OpenCode Web/backend
                                                                         │
                                                                    FIRSTMATE
                                                              ┌──────────┼──────────┐
                                                          OpenCode   OpenCode   OpenCode
                                                          worker A   worker B   worker C
                                                              └──────────┼──────────┘
                                                                      9router
                                                              DeepSeek / Gemini / Grok
```

## Proposed Changes

### 1. Repository scaffold (`opencode-sandbox-env`)
```
opencode-sandbox-env/
├── docker-compose.yml             # opencode (tty, stdin_open) + caddy + cloudflared
├── docker-compose.vps.yml         # optional: join existing 9router_9router-net
├── Dockerfile                     # node base + firstmate (pinned SHA) + opencode
├── .env.example                   # deployment-level env
├── .github/workflows/deploy.yml   # 9router-deploy pipeline pattern
├── cloudflared/config.yml.example
├── config/                        # firstmate config (backend, crew-harness, crew-dispatch.json, .env, mcp)
├── env/opencode.env.example       # container runtime env
├── proxy/Caddyfile                # reverse_proxy -> opencode:4096
└── scripts/entrypoint.sh          # seed-on-first-boot then exec
```

### 2. Docker image (Dockerfile)
* Base: Node image; install git, tmux, curl, ripgrep, jq, python3, node, npm, gh, glab, caddy, **awscli (aws CLI)**.
* Install OpenCode (version-pinned) + clone Firstmate at **pinned commit** (`ARG FIRSTMATE_REF`, mirror 9router's `resolve_sha` pattern) — never `:latest`.
* `gh auth` via `GH_TOKEN` env only — `gh auth login` is interactive, unusable in build/smoke; verify `gh auth status` in smoke test.
* External CLIs (`aws`, `gh`, `glab`) credentials supplied via `env/opencode.env` at runtime — never baked into image:
    * GitHub → `GH_TOKEN`; GitLab → `GITLAB_TOKEN`; AWS → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` (or `AWS_PROFILE` + mounted `~/.aws`, read-only).
    * No secrets in image layers; verify in smoke test that CLIs resolve and auth without interactive prompts.
* `USER 1000` + UID-1000 chown for mounted volumes.

### 3. Compose services
* `opencode` service: `stdin_open: true`, `tty: true` (tmux required); runs `opencode web --hostname 0.0.0.0 --port 4096` with `OPENCODE_SERVER_PASSWORD`; Firstmate primary + crew live in tmux inside it.
* `caddy` service: reverse-proxies `$OPENCODE_DOMAIN` → `opencode:4096` (flush_interval -1 for SSE/streaming).
* `cloudflared` service: outbound tunnel, `CLOUDFLARED_TOKEN` from `.env`.
* Volumes: FM_HOME dirs (`projects/`, `data/`, `state/`, `config/`, `scratchpad*`) + OpenCode session state + `./data/ssh:/home/opencode/.ssh:ro`.
* Env from `env/opencode.env` (GH_TOKEN, GITLAB_TOKEN, ROUTER9_GATEWAY_URL/KEY, OPENCODE_SERVER_PASSWORD, FIRSTMATE_*).
* Port 4096 bound to localhost only (or not published); public ingress via Caddy/tunnel exclusively.

### 4. Config — align to actual Firstmate schema (docs/configuration.md)
* `config/backend`, `config/crew-harness` (harness = opencode), `config/crew-dispatch.json`, `.env` — NOT hermes's `profiles.yaml` schema.
* **OpenCode provider config**: point at co-located `9router-api` (container `9router-api`, port `20127`, network `9router-net`) via `docker-compose.vps.yml`; dev fallback `http://host.docker.internal:20127`. Models exposed: `General`, `Balanced`, `Deep-Thinker` (user's 9router combos). Auth: `ROUTER9_API_KEY` from local env.
* MCP wiring for `9router-gateway` (verify gateway path on 9router-api; hermes used `/api/mcp-gateway`).

### 4b. `agents` repo — supplementary skills only (NOT AGENTS.md authority)
* Firstmate's AGENTS.md is the single authority (review blocker #3). User's `agents` repo (`github.com/vianhanif/agents`) is mapped as a **skill pack**: role skills (`planner`, `coder`, `review`, `tester`, `analyzer`) installed into Firstmate's skill layout — NOT as a competing `~/.agents/AGENTS.md`.
* Worktree convention follows Firstmate's treehouse (`.worktrees/` skill instructions overridden — treehouse owns worktrees).

### 5. 9router integration
* `ROUTER9_GATEWAY_URL` → 9router-api (local `host.docker.internal:20127` in dev; public URL on VPS or co-located network).
* Optional `docker-compose.vps.yml` joins existing external `9router_9router-net` (exact name verified).

### 6. Deploy — 9router-deploy pipeline pattern (NOT hermes's naive SCP+up)
* GitHub Actions on push to `master` + `workflow_dispatch` + `repository_dispatch`.
* Sync **Dockerfile + config/ + compose** (hermes workflow never synced Dockerfile/config — latent bug, don't copy).
* Build → isolated **smoke test** (separate names/ports; verify `gh auth status`, firstmate version, tmux session) → switch images → healthcheck → prune old → **rollback on failure** (`:prev` tag).
* Access via `ssh tencent-cloud` (Tencent VPS).

## Checkpoint (first milestone)
* Verify **OpenCode TUI plugin + Firstmate watcher arm** in an attached session before building further — OpenCode is a verified harness but its supervision path uses a TUI plugin. Also verify `opencode web` + `opencode attach` share session state as documented. If supervision is broken, fall back to a co-primary harness (Claude Code / Pi).

## Open Decision (needs user input)
* **Browser session topology**: (a) browser `opencode web` session IS the Firstmate primary session (one captain → one agent → many workers — discussion's preferred), or (b) a separate browser-facing OpenCode session that inspects/controls the fleet. Recommend (a).

## Out of Scope (v1)
* Separate worker containers (crew = tmux windows in one container)
* Tunneling/mirroring the tmux TUI into the browser
* Pi harness, Telegram/Discord, desktop app, self-learning loop
* Overlaying user `~/.agents` over Firstmate's AGENTS.md
* Third-party browser UIs (e.g. Conduit) — start with native `opencode web`

## Resolved Questions
* **Pi harness**: Dropped — Firstmate is a distro running inside OpenCode; Pi isn't required to run OpenCode.
* **Access**: Browser (`https://$OPENCODE_DOMAIN`) for command/observation + SSH/tmux for operations/debug; deployment via GitHub Actions only.
* **VPS**: Tencent Cloud (`ssh tencent-cloud`). Secrets: TENCENT_HOST / TENCENT_USER / TENCENT_SSH_KEY.
* **Repo name**: `opencode-sandbox-env` (renamed from pi-sandbox-env).
* **LLM endpoint**: co-located `9router-api:20127` (already deployed on same VPS); models `General` / `Balanced` / `Deep-Thinker`; auth via `ROUTER9_API_KEY`.
* **agents repo**: supplementary skill pack only; Firstmate AGENTS.md stays sole authority.

## Considered, Deferred (not v1)
* **Open Connector (openconnector.dev) / Composio** as credential broker + MCP gateway for AWS/GitHub/GitLab.
    * Evaluated: it brokers agent-native tool calls (`GITHUB_ISSUES_CREATE`) and injects credentials server-side; also has a CLI (`composio search|execute|link|proxy`) but that is tool-slug/proxy invocation — **not** `gh pr create`, `glab mr`, `aws s3`, or git-over-SSH parity.
    * Self-hosting burden: API server + Postgres + `CONNECTOR_ENCRYPTION_KEY` + public HTTPS origin + per-provider OAuth apps + Cloudflare Workers/Queues/R2 production shape. A second platform on the same VPS.
    * **Decision**: direct CLI install wins for v1 — exact shape match for "AWS/GitHub/GitLab commands inside the env", zero extra infra, Firstmate crew inherits CLIs naturally.
    * **Revisit when**: adding remote/untrusted secondmates that should not hold raw AWS keys, or adding OAuth-only connectors (Gmail/Slack/Notion/Linear). Then it becomes the credential boundary / audit surface.
* **Third-party OpenCode browser UIs** (e.g. Conduit) — native `opencode web` suffices.

## Notes
* Deploy pattern from `9router-deploy` (SHA-pinned, smoke-tested, rollback-on-failure), not hermes.
* Security: never commit `.env` / `env/*.env`; use `.example` templates.
* Open Connector is NOT indexed in Context7 (only Composio, its SDK-compatible upstream) — see Composio docs `/websites/composio_dev` for broker semantics.
