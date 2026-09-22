ARG AGENT_BROWSER_VERSION=0.3.7
ARG GHIDRA_VERSION=12.1
ARG GHIDRA_BUILD=20260513
ARG JADX_VERSION=1.5.5
ARG OBSERVER_WARD_VERSION=2026.6.28
ARG HTTPX_VERSION=1.9.0

# Build the small HTTP/WebSocket proxy used by the sandbox runtime.
FROM golang:1.26-trixie AS proxy-builder

ENV CGO_ENABLED=0

WORKDIR /src/proxy
COPY proxy/ ./
RUN go build -trimpath -ldflags='-s -w' -o /sandbox-proxy .

FROM ghcr.io/astral-sh/uv:latest AS uv-bin

# Download and normalize agent-browser assets.
FROM debian:trixie-slim AS agent-browser-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG AGENT_BROWSER_VERSION

COPY chrome-extensions.zip /tmp/chrome-extensions.zip
COPY agent-browser-cli.tgz /tmp/agent-browser-cli.tgz

RUN set -eux; \
    sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends tar unzip; \
    mkdir -p \
      /opt/agent-browser/bin \
      /opt/agent-browser/chrome-extension \
      /tmp/agent-browser-cli \
      /tmp/agent-browser-extensions; \
    unzip -q /tmp/chrome-extensions.zip -d /tmp/agent-browser-extensions; \
    extension_dir="$(find /tmp/agent-browser-extensions -type f -name manifest.json -printf '%h\n' | sort | head -n 1)"; \
    test -n "$extension_dir"; \
    echo "agent-browser extension dir: $extension_dir"; \
    cp -a "$extension_dir"/. /opt/agent-browser/chrome-extension; \
    test -f /opt/agent-browser/chrome-extension/manifest.json; \
    tar -xzf /tmp/agent-browser-cli.tgz -C /tmp/agent-browser-cli; \
    cp /tmp/agent-browser-cli/package/bin/agent-browser-cli /opt/agent-browser/bin/agent-browser-cli; \
    chmod 755 /opt/agent-browser/bin/agent-browser-cli; \
    /opt/agent-browser/bin/agent-browser-cli --help >/dev/null; \
    find /opt/agent-browser/chrome-extension -type f \( \
      -name '*.md' -o \
      -name '*.map' \
    \) -delete; \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/*

# Download and trim Ghidra separately so final image layers do not retain
# build-only tools or archive caches.
FROM debian:trixie-slim AS ghidra-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG GHIDRA_VERSION
ARG GHIDRA_BUILD

COPY ghidra.zip /tmp/ghidra.zip

RUN set -eux; \
    sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends binutils unzip; \
    unzip -q /tmp/ghidra.zip -d /opt; \
    ghidra_dir="$(find /opt -maxdepth 1 -type d -name 'ghidra_*_PUBLIC' | sort | head -n 1)"; \
    test -n "$ghidra_dir"; \
    mv "$ghidra_dir" /opt/ghidra; \
    find /opt/ghidra -type d \( \
      -name '.git' -o \
      -name '__pycache__' -o \
      -name 'docs' -o \
      -name 'GPL' \
    \) -prune -exec rm -rf '{}' +; \
    find /opt/ghidra -type f \( \
      -name '*.md' -o \
      -name '*.pdb' -o \
      -name '*.src.zip' \
    \) -delete; \
    find /opt/ghidra -type f -name '*.so' -exec strip --strip-unneeded '{}' + 2>/dev/null || true; \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/*

# Download and trim jadx separately for the same reason.
FROM debian:trixie-slim AS jadx-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG JADX_VERSION

COPY jadx.zip /tmp/jadx.zip

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip; \
    mkdir -p /opt/jadx; \
    unzip -q /tmp/jadx.zip -d /opt/jadx; \
    find /opt/jadx -type d \( \
      -name '.github' -o \
      -name 'docs' -o \
      -name 'samples' \
    \) -prune -exec rm -rf '{}' +; \
    find /opt/jadx -type f \( \
      -name '*.bat' -o \
      -name '*.md' -o \
      -name '*.map' \
    \) -delete; \
    chmod 755 /opt/jadx/bin/jadx; \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/*

# Validate skills in a build-only stage so lint helpers are not copied into
# the final sandbox image.
FROM debian:trixie-slim AS skills-validator

WORKDIR /tmp

RUN set -eux; \
    sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/tmp/*

COPY .agents .agents
RUN set -eux; \
    find .agents/skills -mindepth 2 -name '*.sh' -type f -exec chmod 755 '{}' +; \
    chmod 755 .agents/validate-skills.sh; \
    .agents/validate-skills.sh .agents/skills

# Final sandbox runtime image.
FROM debian:trixie-slim

ENV HOME=/root \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:0 \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    GHIDRA_HOME=/opt/ghidra \
    JADX_HOME=/opt/jadx \
    UV_TOOL_DIR=/opt/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    PATH=/opt/jadx/bin:/opt/ghidra:/opt/ghidra/support:/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH

WORKDIR /root

ARG DEBIAN_FRONTEND=noninteractive
ARG OBSERVER_WARD_VERSION
ARG HTTPX_VERSION

COPY observer-ward.deb /tmp/predownloaded/observer-ward.deb
COPY httpx.zip /tmp/predownloaded/httpx.zip

RUN set -eux; \
    printf '%s\n' \
      'path-exclude=/usr/share/doc/*' \
      'path-exclude=/usr/share/man/*' \
      'path-exclude=/usr/share/info/*' \
      'path-exclude=/usr/share/lintian/*' \
      'path-exclude=/usr/share/locale/*' \
      'path-include=/usr/share/locale/locale.alias' \
      > /etc/dpkg/dpkg.cfg.d/01_nodoc; \
    sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources; \
    echo 'Acquire::Retries "10";' > /etc/apt/apt.conf.d/99retry; \
    echo 'Acquire::http::Timeout "120";' >> /etc/apt/apt.conf.d/99retry; \
    echo 'Acquire::Queue-Mode "access";' >> /etc/apt/apt.conf.d/99retry; \
    apt-get update; \
    apt-get install -y --no-install-recommends --fix-missing \
      7zip \
      apktool \
      ca-certificates \
      binutils \
      binwalk \
      chromium \
      curl \
      dnsutils \
      file \
      fonts-droid-fallback \
      g++ \
      gcc \
      git \
      jq \
      libc6-dev \
      make \
      netcat-openbsd \
      nmap \
      nodejs \
      novnc \
      openssl \
      openjdk-21-jdk \
      npm \
      pkg-config \
      python3 \
      ripgrep \
      supervisor \
      tor \
      util-linux \
      unzip \
      websockify \
      wget \
      whois \
      x11vnc \
      xvfb; \
    apt-get install -y --no-install-recommends /tmp/predownloaded/observer-ward.deb; \
    rm -f /tmp/predownloaded/observer-ward.deb; \
    observer_ward -u; \
    unzip -q /tmp/predownloaded/httpx.zip -d /tmp/httpx; \
    install -m 755 /tmp/httpx/httpx /usr/local/bin/httpx; \
    rm -rf /tmp/predownloaded /tmp/httpx; \
    ln -sf vnc.html /usr/share/novnc/index.html; \
    mkdir -p /data; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/*

COPY --from=uv-bin /uv /usr/local/bin/uv
COPY --from=uv-bin /uvx /usr/local/bin/uvx
COPY --from=agent-browser-builder /opt/agent-browser /opt/agent-browser
COPY --from=ghidra-builder /opt/ghidra /opt/ghidra
COPY --from=jadx-builder /opt/jadx /opt/jadx

RUN set -eux; \
    ln -sf /opt/ghidra/ghidraRun /usr/local/bin/ghidra; \
    ln -sf /opt/ghidra/support/analyzeHeadless /usr/local/bin/analyzeHeadless; \
    ln -sf /opt/jadx/bin/jadx /usr/local/bin/jadx; \
    ln -sf /opt/agent-browser/bin/agent-browser-cli /usr/local/bin/agent-browser-cli; \
    uv tool install --python /usr/bin/python3 sqlmap; \
    uv cache clean; \
    find /opt/uv/tools -type d -name __pycache__ -prune -exec rm -rf '{}' +; \
    rm -rf /root/.cache /tmp/* /var/tmp/*

RUN set -eux; \
    7z i >/dev/null; \
    apktool --version; \
    binwalk --help >/dev/null; \
    dig -v; \
    file --version; \
    g++ --version; \
    gcc --version; \
    git --version; \
    httpx -version; \
    java -version; \
    jadx --version; \
    jq --version; \
    nmap --version; \
    node --version; \
    npm --version; \
    observer_ward --help >/dev/null; \
    openssl version; \
    pkg-config --version; \
    python3 --version; \
    sqlmap --version; \
    supervisord --version; \
    tor --version; \
    unzip -v >/dev/null; \
    rg --version; \
    whois --version; \
    x11vnc -version; \
    chromium --version; \
    agent-browser-cli --help >/dev/null; \
    command -v websockify; \
    test -f /opt/agent-browser/chrome-extension/manifest.json; \
    test -x /opt/agent-browser/bin/agent-browser-cli; \
    test -x /opt/ghidra/ghidraRun; \
    test -x /opt/ghidra/support/analyzeHeadless; \
    test -x /opt/jadx/bin/jadx

COPY --from=proxy-builder --chmod=755 /sandbox-proxy /usr/local/bin/sandbox-proxy
COPY --from=skills-validator /tmp/.agents/skills .agents/skills
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY supervisord.conf /supervisord.conf

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
