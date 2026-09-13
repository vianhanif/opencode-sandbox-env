# opencode-sandbox-env

A lightweight AI-agent sandbox for a Tencent Cloud VPS: **Firstmate** (agent distro / orchestration) + **OpenCode** (coding harness, browser + TUI) + **9router** (model routing). Replaces the bloated Hermes deployment.

## Architecture

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

- **One container**: the crew is tmux windows inside a single OpenCode container, not separate worker containers.
- **Two interfaces, one backend**: browser (`opencode web :4096`) is the captain/observation console; tmux + SSH are the operational/debug surface. Both attach to the same OpenCode session (`opencode attach`).
- **Firstmate AGENTS.md is the sole authority**; the `agents` repo (github.com/vianhanif/agents) is used only as a supplementary skill pack (`planner`, `coder`, `review`, `tester`, `analyzer`).
- **9router** routes all model traffic (models `General` / `Balanced` / `Deep-Thinker`, auth via `ROUTER9_API_KEY`).

## Repository layout

| Path | Purpose |
|---|---|
| `Dockerfile` | Node base + Firstmate (pinned SHA) + OpenCode + CLIs (git, tmux, gh, glab, awscli) |
| `docker-compose.yml` | `opencode` + `caddy` + `cloudflared` stack |
| `docker-compose.vps.yml` | VPS override — joins the existing external `9router_9router-net` |
| `config/` | Firstmate config (`backend`, `crew-harness`, `crew-dispatch.json`, `mcp.json`) + OpenCode 9router provider (`opencode.json`) |
| `env/opencode.env.example` | Container runtime env (credentials, 9router keys, OpenCode password) |
| `.env.example` | Deployment-level env (domain, tunnel token, VPS access) |
| `proxy/Caddyfile` | Reverse proxy → `opencode:4096` (SSE-safe `flush_interval -1`) |
| `cloudflared/config.yml.example` | Cloudflare Tunnel ingress |
| `scripts/entrypoint.sh` | Seed-on-first-boot, start tmux session + `opencode web` |
| `.github/workflows/deploy.yml` | Build → smoke test → switch → rollback-on-failure pipeline |

## Quick start (VPS)

1. Clone the repo onto the VPS into `/opt/opencode-sandbox`.
2. Create the runtime env files (never commit real secrets):
   ```bash
   cp .env.example .env
   cp env/opencode.env.example env/opencode.env
   # fill in OPENCODE_DOMAIN, CLOUDFLARED_TOKEN, ROUTER9_*, GH_TOKEN, GITLAB_TOKEN, AWS_*, OPENCODE_SERVER_PASSWORD, TENCENT_*
   ```
3. Provision the data dirs:
   ```bash
   mkdir -p data/projects data/data data/state data/config data/scratchpad data/sessions data/ssh
   ```
4. Start the stack:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.vps.yml up -d --build
   ```
5. Open `https://opencode.<domain>` in a browser; auth uses `OPENCODE_SERVER_PASSWORD`.

## CI/CD

The deploy workflow (`deploy.yml`) runs on push to `master` (plus `workflow_dispatch` / `repository_dispatch`):

1. Syncs `Dockerfile`, `config/`, `env/`, `scripts/`, `proxy/`, compose files to the VPS.
2. Builds a fresh image (Firstmate ref resolved from `main` unless overridden; SHA-pinned for reproducibility).
3. **Smoke-tests** the new image in an isolated container (`smoke-opencode`, port 4097): `gh auth status`, tmux session up, `opencode web` health.
4. Switches the production stack, verifies containers + health, prunes old images.
5. **Rolls back to the previous image** on any failure.

Required GitHub secrets: `TENCENT_HOST`, `TENCENT_USER`, `TENCENT_SSH_KEY`.

## Security notes

- Never commit `.env`, `env/*.env`, or `cloudflared/config.yml` — templates only.
- `opencode web` listens on `127.0.0.1:4096` in compose; public ingress is exclusively via Caddy + Cloudflare Tunnel.
- Credentials (GH_TOKEN, GITLAB_TOKEN, AWS_*) are injected at runtime from `env/opencode.env`, never baked into the image.

## License

MIT