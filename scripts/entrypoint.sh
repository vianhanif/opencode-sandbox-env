#!/bin/bash
set -euo pipefail

# Seed directories on first boot (volumes may be empty)
for dir in projects data state config scratchpad sessions; do
    mkdir -p "/home/opencode/$dir"
done

# Ensure .ssh exists (even if volume not mounted)
mkdir -p /home/opencode/.ssh
chmod 700 /home/opencode/.ssh

# tmux needs TERM even in non-tty containers
# ponytail: bind-mount host dirs must be owned by uid 1000 (chown on host before up)
export TERM=xterm-256color

# Create tmux session 'firstmate' if not exists
# Runs the OpenCode TUI primary in the Firstmate checkout; crewmates are additional tmux windows
if ! tmux has-session -t firstmate 2>/dev/null; then
    tmux new-session -d -s firstmate -c /home/opencode/.firstmate
    tmux send-keys -t firstmate 'opencode' Enter
fi

# Run OpenCode web server in foreground
# Password auth via OPENCODE_SERVER_PASSWORD env var
exec opencode web --hostname 0.0.0.0 --port 4096
