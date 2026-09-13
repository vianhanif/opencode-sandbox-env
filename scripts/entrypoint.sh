#!/bin/bash
set -euo pipefail

FM_HOME="${FM_HOME:-/home/opencode}"
SEED_DIR=/opt/opencode-seed

# Seed directories on first boot (volumes may be empty)
for dir in projects data state config scratchpad sessions; do
    mkdir -p "$FM_HOME/$dir"
done

# Ensure .ssh exists (even if volume not mounted)
mkdir -p "$FM_HOME/.ssh"
chmod 700 "$FM_HOME/.ssh"

# Seed firstmate config on first boot — only if missing so later manual edits win
if [[ -d "$SEED_DIR" ]]; then
    mkdir -p "$FM_HOME/config"
    for f in backend crew-harness crew-dispatch.json mcp.json; do
        [[ -e "$FM_HOME/config/$f" ]] || cp "$SEED_DIR/$f" "$FM_HOME/config/$f" 2>/dev/null || true
    done
fi

# tmux needs TERM even in non-tty containers
# ponytail: bind-mount host dirs must be owned by uid 1000 (chown on host before up)
export TERM=xterm-256color

# Create tmux session 'firstmate' if not exists
# Runs the OpenCode TUI primary in the Firstmate checkout; crewmates are additional tmux windows
if ! tmux has-session -t firstmate 2>/dev/null; then
    tmux new-session -d -s firstmate -c "$FM_HOME/.firstmate"
    tmux send-keys -t firstmate 'opencode' Enter
fi

# Run OpenCode web server in foreground
# Password auth via OPENCODE_SERVER_PASSWORD env var
exec opencode web --hostname 0.0.0.0 --port 4096
