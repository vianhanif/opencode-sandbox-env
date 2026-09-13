# OpenCode Sandbox — Firstmate Agent Harness
# ponytail: minimal viable image; add build tools (gcc, make) when native modules needed

ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm-slim

# Build args for pinning
ARG OPENCODE_VERSION=1.18.30
ARG FIRSTMATE_REF=b182d0f908b78d08c7ccb8dce3775bdca8c5d657

# Rename existing node user/group to opencode (UID/GID 1000 preserved)
RUN groupmod -n opencode node && usermod -l opencode -d /home/opencode -m node

# System packages (dev tooling, CLIs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    git \
    tmux \
    curl \
    ripgrep \
    jq \
    procps \
    python3 \
    python3-pip \
    ca-certificates \
    openssh-client \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# GitLab CLI (glab) — version pinned
ARG GLAB_VERSION=1.117.0
RUN curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_$(dpkg --print-architecture).deb" -o /tmp/glab.deb \
    && dpkg -i /tmp/glab.deb && rm /tmp/glab.deb

# AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
    && cd /tmp && unzip -q awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# OpenCode CLI (version-pinned)
RUN npm install -g opencode-ai@${OPENCODE_VERSION}

# Ensure opencode homedir and shell
RUN chsh -s /bin/bash opencode

# Volume mount points (owned by opencode)
RUN mkdir -p /home/opencode/projects \
             /home/opencode/data \
             /home/opencode/state \
             /home/opencode/config \
             /home/opencode/scratchpad \
             /home/opencode/sessions \
    && chown -R opencode:opencode /home/opencode

# Clone Firstmate at pinned commit
USER opencode
WORKDIR /home/opencode
RUN git clone --depth 50 https://github.com/kunchenguid/firstmate /home/opencode/.firstmate \
    && cd /home/opencode/.firstmate && git checkout ${FIRSTMATE_REF}

# Add firstmate bin to PATH; FM_HOME = operational home (data/state/config/projects/scratchpad),
# NOT the tracked code root (/home/opencode/.firstmate). See firstmate docs/configuration.md.
ENV PATH="/home/opencode/.firstmate/bin:${PATH}"
ENV FM_HOME="/home/opencode"

# Seed config for firstmate + opencode (copied at runtime only when missing)
COPY --chown=opencode:opencode config/ /opt/opencode-seed/
RUN mkdir -p /home/opencode/.config/opencode
COPY --chown=opencode:opencode config/opencode.json /home/opencode/.config/opencode/opencode.json

# Copy entrypoint
COPY --chown=opencode:opencode scripts/entrypoint.sh /home/opencode/entrypoint.sh
RUN chmod +x /home/opencode/entrypoint.sh

WORKDIR /home/opencode/.firstmate
ENTRYPOINT ["/home/opencode/entrypoint.sh"]
