# OCSE-001: opencode-sandbox-env scaffold + deploy

Date: 2026-09-13

## Context
Replace bloated Hermes sandbox with lightweight Agent sandbox on Tencent VPS.
Stack: Firstmate (distro/orchestration) + OpenCode (harness, web+TUI) + 9router (models).
Browser access via `opencode web` + Caddy + Cloudflare Tunnel.

## Scope (confirmed)
- One container (tmux crew), no worker containers
- Firstmate AGENTS.md = sole authority; `agents` repo = skill pack only
- 9router-api:20127 co-located, models General/Balanced/Deep-Thinker, auth ROUTER9_API_KEY
- External CLIs direct install (aws/gh/glab); Open Connector deferred
- No dashboard besides `opencode web`; no Pi harness
- Deploy via GitHub Actions (9router-deploy pattern: SHA-pin, smoke, rollback)

## Todos (from plan)
1. Scaffold repo structure (wiki/ + changelog/ + dirs)
2. Dockerfile (node + firstmate pinned + opencode + CLIs + tmux)
3. docker-compose.yml (opencode + caddy + cloudflared)
4. docker-compose.vps.yml (join 9router_9router-net)
5. Firstmate config + OpenCode provider config (9router-api)
6. agents repo → skill pack (no AGENTS.md overlay)
7. entrypoint.sh (seed-on-first-boot + launch)
8. Caddy + cloudflared configs
9. Env templates (.env.example, env/opencode.env.example)
10. GitHub Actions deploy (smoke + rollback)
11. Firstmate+OpenCode checkpoint (attached session)
12. Final validation + README + commit

## Status
In progress.