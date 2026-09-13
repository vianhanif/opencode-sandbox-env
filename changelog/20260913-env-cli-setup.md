# env-cli-setup: Install aws / kubectl / gh / glab + dotfiles in sandbox env

Date: 2026-09-13
Status: Planning only — no implementation yet.

## Context
Extends OCSE-001 scope item "External CLIs direct install (aws/gh/glab)". Add `kubectl`. CLIs must be baked into the deployment image so the agent container can run deployments against AWS and Kubernetes without manual setup.

Additionally: user dotfiles (aliases, functions, zsh configs) are sourced from a separate private `env` repo for maintainability and backup.

## Goal
- Image contains: aws-cli v2, kubectl, gh (GitHub CLI), glab (GitLab CLI). Version-pinned, sha256-verified where possible, smoke-tested.
- User aliases/functions cloned from `vianhanif/env` (private) at SHA-pinned commit.
- No credential material in image; creds injected at runtime.

## Disk footprint reference (local install sizes)
| CLI       | Size  |
|-----------|-------|
| aws-cli   | 232M  |
| kubectl   | 66M   |
| glab      | 49M   |
| gh        | 40M   |
| **Total** | ~387M |

## Approach: separate private `env` repo
- New private GitHub repo `vianhanif/env` stores all dotfiles, aliases, functions, and configs.
- `opencode-sandbox-env` Dockerfile clones `env` repo at a **SHA-pinned commit** during image build (same pattern as Firstmate/9router).
- Updates to aliases/configs: commit + push to `env` repo → trigger redeploy in `opencode-sandbox-env` with new `ENV_REPO_SHA`.
- Backup bonus: all non-secret dotfiles are versioned in a separate private repo, recoverable via `git clone` on a fresh machine.

## Secrets strategy: vault-first, not git-first
- **Primary vault: Bitwarden free tier.** All secret values (AWS creds, kube config, tokens, API keys) live in Bitwarden vault only.
- **Commit templates only:** `secrets.zsh.example` and `exports.local.zsh.example` go into `env` repo — keys with placeholder values, documenting what's needed.
- **Printed emergency kit:** vault master password + recovery code + TOTP backup codes on paper in a physical location. This is the recovery root — survives machine loss.
- **Never in git:** even in private repos, secrets in git history are permanent. Rotation is the only cleanup.

## Secrets mount in container
- Secrets mounted at runtime via env files or Docker secrets, never baked into image layers.
- `env/opencode.env.example` documents the shape; real values sourced from Bitwarden or CI secrets at deploy time.
- For interactive use: copy from vault to a `.env` file on VPS that's gitignored.

## Portability
- Paths use `$HOME` / env vars, not hardcoded `/Users/pid-alvian/`.
- kubernetes.zsh port-forward aliases are project-specific — kept in `env` repo under a `profiles/` subdir, loaded per project.
- `multilogs` function included with dependency check (install script documented).

## Planned steps (deferred — changelog only)
1. **Create `vianhanif/env` repo (private)**
   - Structure: `zsh/aliases/`, `zsh/functions/`, `zsh/completions/`, `zsh/exports.zsh`, `zsh/lazyload.zsh`
   - Templates: `secrets.zsh.example`, `exports.local.zsh.example`
   - README with restore instructions
   - `.gitignore` to block any real secret files
   - `gitleaks` pre-commit hook (optional, recommended)

2. **Copy local dotfiles to `env` repo**
   - Migrate from `~/.zsh/*` with path portability fixes (`$HOME` not hardcoded)
   - Remove machine-specific aliases (tencent SSH, personal port-forwards) or move to `profiles/` subdir

3. **Dockerfile additions**
   - `ARG ENV_REPO_SHA` — pinned commit hash
   - Clone `vianhanif/env` at that SHA (requires deploy key for private repo)
   - Symlink or source zsh configs from `/home/opencode/.env-config/`
   - CLI installs: aws-cli v2, kubectl, gh, glab (already in current Dockerfile)
   - Smoke: `aws --version && kubectl version --client && gh --version && glab --version`

4. **CI pipeline**
   - Deploy key (read-only) for `env` repo stored in GitHub Actions secrets
   - `ENV_REPO_SHA` as build arg (manual update when env changes)
   - `gitleaks` check on `env` repo before build (optional)

5. **Validation**
   - Build image → exec shell → verify aliases load, CLIs resolve, no hardcoded paths fail
   - Push → deploy → smoke checks on VPS

## Open decisions
- SHA pinning for `env` repo: fixed commit hash as build ARG (same pattern as `FIRSTMATE_REF`)? **Recommend: yes**
- `gitleaks` in CI to scan `env` repo before push? **Recommend: yes (pre-commit hook)**
- Deploy key scope: one read-only key for `env` repo only? **Recommend: yes**
