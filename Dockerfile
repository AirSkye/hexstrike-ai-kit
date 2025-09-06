# syntax=docker/dockerfile:1.7

# 基础镜像：使用官方 Python slim 版本，便于跨平台（多架构）构建
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    UV_SYSTEM_PYTHON=1 \
    UV_LINK_MODE=copy \
    UV_HTTP_TIMEOUT=120 \
    HEXSTRIKE_HOST=0.0.0.0 \
    HEXSTRIKE_PORT=8888

# 安装系统工具与 Chrome/Chromedriver 以支持 Browser Agent
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        unzip \
        xvfb \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libc6 \
        libcairo2 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libexpat1 \
        libgbm1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnss3 \
        libnspr4 \
        libu2f-udev \
        libx11-6 \
        libxau6 \
        libxcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxkbcommon0 \
        libxrandr2 \
        libxrender1 \
        libxshmfence1 \
        libxtst6 \
        lsb-release \
        xdg-utils \
        build-essential \
        libpcap-dev \
        git; \
    rm -rf /var/lib/apt/lists/*

# 安装 masscan（从源码构建，适配多架构）
RUN set -eux; \
    git clone --depth 1 https://github.com/robertdavidgraham/masscan.git /tmp/masscan; \
    make -C /tmp/masscan -j"$(nproc)"; \
    make -C /tmp/masscan install; \
    rm -rf /tmp/masscan

# 安装 dnsenum（Perl 依赖 + 官方仓库脚本）
RUN set -eux; \
    git clone --depth 1 https://github.com/fwaeytens/dnsenum /opt/dnsenum; \
    ln -sf /opt/dnsenum/dnsenum.pl /usr/local/bin/dnsenum; \
    chmod +x /opt/dnsenum/dnsenum.pl

# 安装 medusa（优先 apt；失败则源码构建）
RUN set -eux; \
    if ! (apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends medusa); then \
      apt-get update; \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends autoconf automake libtool libssl-dev libssh-dev libpq-dev; \
      git clone --depth 1 https://github.com/jmk-foofus/medusa /tmp/medusa; \
      cd /tmp/medusa; \
      ./configure; \
      make -j"$(nproc)"; \
      make install; \
      rm -rf /tmp/medusa; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# 安装 patator（官方仓库脚本，自动检测入口名）
RUN set -eux; \
    git clone --depth 1 https://github.com/lanjelot/patator /opt/patator; \
    entry=$(find /opt/patator \( -type f -iname 'patator.py' -o -type f -iname 'patator' \) -print | head -n1 || true); \
    if [ -z "$entry" ]; then ls -laR /opt/patator >&2; echo "patator entry not found" >&2; exit 1; fi; \
    ln -sf "$entry" /usr/local/bin/patator; \
    chmod +x "$entry"; \
    if [ -f /opt/patator/requirements.txt ]; then uv pip install --system --no-cache -r /opt/patator/requirements.txt || true; else uv pip install --system --no-cache paramiko requests pysmb PySocks || true; fi
# 安装 Google Chrome（稳定版）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64)  CHROME_ARCH=amd64 ;; \
      arm64)  CHROME_ARCH=arm64 ;; \
      *) echo "Unsupported arch for Chrome: $arch"; exit 1 ;; \
    esac; \
    wget -O /tmp/chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_${CHROME_ARCH}.deb"; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/chrome.deb; \
    rm -f /tmp/chrome.deb; \
    rm -rf /var/lib/apt/lists/*

# 依赖 Selenium 4 的 Selenium Manager 在运行时自动管理 Chromedriver（不在构建期安装）

# 安装 uv（Python 包与虚拟环境快速管理）
RUN set -eux; \
    pip install --no-cache-dir uv

WORKDIR /app

# 仅拷贝依赖清单，先行构建依赖层
COPY requirements.txt /app/requirements.txt

# 使用 uv 安装依赖（到系统 Python，因为设置了 UV_SYSTEM_PYTHON=1）
RUN set -eux; \
    uv pip install --system --no-cache -r /app/requirements.txt

# 安装 README 安全工具集（网络/WEB/口令/二进制/云）
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        pkg-config \
        python3-dev \
        libkrb5-dev \
        libldap2-dev \
        libsasl2-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        libffi-dev \
        libssl-dev \
        zlib1g-dev \
        # dnsenum 依赖\
        libnet-ip-perl \
        libnet-dns-perl \
        libio-socket-inet6-perl \
        libnet-dns-sec-perl \
        libxml-writer-perl \
        libstring-random-perl \
        # 常见工具 & 依赖\
        ldap-utils \
        smbclient \
        perl \
        cpanminus \
        whois \
        # 网络/WEB/二进制工具（APT 可得，去除易缺失项以避免构建失败）\
        nmap \
        dirb \
        hydra \
        john \
        hashcat \
        gdb \
        binwalk \
        foremost \
        steghide \
        binutils \
        libimage-exiftool-perl \
        # Ruby & Gem（用于 wpscan / evil-winrm）\
        ruby-full \
        ruby-dev \
        # Go 通过官方二进制安装（见下方步骤）\
        ; \
    rm -rf /var/lib/apt/lists/*

# 安装 nikto（从官方仓库）
RUN set -eux; \
    git clone --depth 1 https://github.com/sullo/nikto /opt/nikto; \
    ln -sf /opt/nikto/program/nikto.pl /usr/local/bin/nikto; \
    chmod +x /opt/nikto/program/nikto.pl; \
    cpanm --notest --quiet IO::Socket::SSL Net::SSLeay LWP::UserAgent HTTP::Request URI Encode || true

# 安装 radare2（官方脚本）
RUN set -eux; \
    git clone --depth 1 https://github.com/radareorg/radare2 /tmp/radare2; \
    /tmp/radare2/sys/install.sh; \
    rm -rf /tmp/radare2

# 安装 Go（官方二进制，跨架构）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) GO_ARCH=amd64 ;; \
      arm64) GO_ARCH=arm64 ;; \
      *) echo "Unsupported arch for Go: $arch"; exit 1 ;; \
    esac; \
    GO_VER=$(curl -fsSL https://go.dev/VERSION?m=text | head -n1 || true); \
    if [ -z "$GO_VER" ]; then GO_VER=go1.22.12; fi; \
    curl -fsSL -o /tmp/go.tgz "https://go.dev/dl/${GO_VER}.linux-${GO_ARCH}.tar.gz"; \
    rm -rf /usr/local/go; \
    tar -C /usr/local -xzf /tmp/go.tgz; \
    rm -f /tmp/go.tgz; \
    /usr/local/go/bin/go version

# 追加：Ghidra 运行所需 JRE 与 Ophcrack（二进制分析/口令类）
RUN set -eux; \
    apt-get update; \
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openjdk-21-jre-headless; then \
      arch="$(dpkg --print-architecture)"; \
      case "$arch" in \
        amd64)  J_ARCH=x64 ;; \
        arm64)  J_ARCH=aarch64 ;; \
        *) echo "Unsupported arch for Temurin JRE fallback: $arch"; exit 1 ;; \
      esac; \
      curl -fsSL -o /tmp/temurin-jre.tgz "https://api.adoptium.net/v3/binary/latest/21/ga/linux/${J_ARCH}/jre"; \
      mkdir -p /opt/jdk; \
      tar -xzf /tmp/temurin-jre.tgz -C /opt/jdk; \
      rm -f /tmp/temurin-jre.tgz; \
      JRE_DIR=$(find /opt/jdk -maxdepth 1 -type d -name "jdk-21*" | head -n1); \
      if [ -z "$JRE_DIR" ]; then echo "Temurin JRE extract failed"; exit 1; fi; \
      ln -sf "$JRE_DIR/bin/java" /usr/local/bin/java; \
    fi; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ophcrack || true; \
    rm -rf /var/lib/apt/lists/*

# 设置 Go 环境
ENV GOPATH=/go \
    GOBIN=/go/bin \
    PATH=/usr/local/go/bin:/go/bin:$PATH

# 安装 Go 生态工具（多架构自动构建）
RUN set -eux; \
    go install github.com/OJ/gobuster/v3@latest; \
    go install github.com/ffuf/ffuf@latest; \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest; \
    go install github.com/projectdiscovery/katana/cmd/katana@latest; \
    go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest; \
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest; \
    go install github.com/hahwul/dalfox/v2@latest

# 如果 amass 在 apt 不可用，则使用 Go 安装
RUN set -eux; \
    if ! command -v amass >/dev/null 2>&1; then \
      go install github.com/owasp-amass/amass/v4/cmd/amass@latest; \
    fi

# 安装 Rustscan（通过 GitHub API 动态解析资产，兼容 .deb / .tar.gz）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64)  RS_DEB_PATTERN='rustscan_.*_amd64\.deb'; RS_TGZ_PATTERN='x86_64-unknown-linux-gnu\.tar\.gz' ;; \
      arm64)  RS_DEB_PATTERN='rustscan_.*_arm64\.deb'; RS_TGZ_PATTERN='aarch64-unknown-linux-gnu\.tar\.gz' ;; \
      *) echo "Unsupported arch for rustscan: $arch"; exit 0 ;; \
    esac; \
    RS_API_JSON="$(curl -fsSL https://api.github.com/repos/RustScan/RustScan/releases/latest)"; \
    RS_URL="$(printf '%s' "$RS_API_JSON" | grep -Eo 'https://[^\"]+' | grep -E "$RS_DEB_PATTERN" | head -n1 || true)"; \
    if [ -n "$RS_URL" ]; then \
      wget -O /tmp/rustscan.deb "$RS_URL"; \
      apt-get update; \
      apt-get install -y --no-install-recommends /tmp/rustscan.deb || true; \
      rm -f /tmp/rustscan.deb; \
      rm -rf /var/lib/apt/lists/*; \
    else \
      RS_TGZ_URL="$(printf '%s' "$RS_API_JSON" | grep -Eo 'https://[^\"]+' | grep -E "$RS_TGZ_PATTERN" | head -n1 || true)"; \
      if [ -n "$RS_TGZ_URL" ]; then \
        wget -O /tmp/rustscan.tgz "$RS_TGZ_URL"; \
        mkdir -p /tmp/rustscan; \
        tar -xzf /tmp/rustscan.tgz -C /tmp/rustscan; \
        bin_path="$(find /tmp/rustscan -type f -name 'rustscan' | head -n1 || true)"; \
        if [ -n "$bin_path" ]; then install -m 0755 "$bin_path" /usr/local/bin/rustscan; fi; \
        rm -rf /tmp/rustscan /tmp/rustscan.tgz; \
      else \
        echo "RustScan asset not found for arch: $arch"; \
      fi; \
    fi

# 安装 Feroxbuster（通过 GitHub API 动态解析资产名）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64)  FEROX_PATTERN='x86_64.*linux.*\\.tar\\.gz' ;; \
      arm64)  FEROX_PATTERN='aarch64.*linux.*\\.tar\\.gz' ;; \
      *) echo "Unsupported arch for feroxbuster: $arch"; exit 0 ;; \
    esac; \
    FEROX_API_JSON="$(curl -fsSL https://api.github.com/repos/epi052/feroxbuster/releases/latest)"; \
    FEROX_URL="$(printf '%s' "$FEROX_API_JSON" | grep -Eo 'https://[^\"]+' | grep -E "$FEROX_PATTERN" | head -n1 || true)"; \
    if [ -n "$FEROX_URL" ]; then \
      wget -O /tmp/ferox.tgz "$FEROX_URL"; \
      mkdir -p /tmp/ferox; \
      tar -xzf /tmp/ferox.tgz -C /tmp/ferox; \
      bin_path="$(find /tmp/ferox -type f -name 'feroxbuster' | head -n1 || true)"; \
      if [ -n "$bin_path" ]; then install -m 0755 "$bin_path" /usr/local/bin/feroxbuster; fi; \
      rm -rf /tmp/ferox /tmp/ferox.tgz; \
    else \
      echo "Feroxbuster asset not found for arch: $arch"; \
    fi

# 使用 uv 安装 Python 工具（WEB/云/枚举等）
RUN set -eux; \
    uv pip install --system --no-cache \
      fierce \
      dirsearch \
      sqlmap \
      arjun \
      git+https://github.com/devanshbatham/ParamSpider.git \
      wafw00f \
      theHarvester \
      git+https://github.com/Pennyw0rth/NetExec.git \
      scoutsuite \
      prowler \
      kube-hunter \
      volatility3

# 安装 AutoRecon（独立虚拟环境以避免与 NetExec 的 impacket 版本冲突）
RUN set -eux; \
    python -m venv /opt/autorecon-venv; \
    /opt/autorecon-venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel; \
    /opt/autorecon-venv/bin/pip install --no-cache-dir git+https://github.com/SecureAuthCorp/impacket@impacket_0_10_0; \
    /opt/autorecon-venv/bin/pip install --no-cache-dir git+https://github.com/Tib3rius/AutoRecon.git; \
    ln -sf /opt/autorecon-venv/bin/autorecon /usr/local/bin/autorecon

# 安装 enum4linux-ng（从官方仓库克隆并创建可执行入口）
RUN set -eux; \
    git clone --depth 1 https://github.com/cddmp/enum4linux-ng /opt/enum4linux-ng; \
    if [ -f /opt/enum4linux-ng/requirements.txt ]; then \
      uv pip install --system --no-cache -r /opt/enum4linux-ng/requirements.txt; \
    else \
      uv pip install --system --no-cache pyyaml ldap3 impacket || true; \
    fi; \
    printf '#!/bin/sh\nexec /usr/bin/env python3 /opt/enum4linux-ng/enum4linux-ng.py "$@"\n' > /usr/local/bin/enum4linux-ng; \
    chmod +x /usr/local/bin/enum4linux-ng

# 安装 Ruby 工具（WPScan / Evil-WinRM）
RUN set -eux; \
    gem install --no-document wpscan evil-winrm

# 安装 Trivy（官方文档：/usr/share/keyrings + generic main）
RUN set -eux; \
    install -m 0755 -d /usr/share/keyrings; \
    curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends trivy; \
    rm -rf /var/lib/apt/lists/*

# 安装 kube-bench（参考官方仓库：下载最新 Linux 二进制并安装）
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) KB_PATTERN='linux_amd64\\.tar\\.gz' ;; \
      arm64) KB_PATTERN='linux_arm64\\.tar\\.gz' ;; \
      *) echo "Unsupported arch for kube-bench: $arch"; exit 0 ;; \
    esac; \
    KB_API_JSON="$(curl -fsSL https://api.github.com/repos/aquasecurity/kube-bench/releases/latest)"; \
    KB_URL="$(printf '%s' "$KB_API_JSON" | grep -Eo 'https://[^\"]+' | grep -E "$KB_PATTERN" | head -n1 || true)"; \
    if [ -n "$KB_URL" ]; then \
      wget -O /tmp/kb.tgz "$KB_URL"; \
      mkdir -p /tmp/kb; \
      tar -xzf /tmp/kb.tgz -C /tmp/kb; \
      bin_path="$(find /tmp/kb -type f -name 'kube-bench' | head -n1 || true)"; \
      if [ -n "$bin_path" ]; then install -m 0755 "$bin_path" /usr/local/bin/kube-bench; fi; \
      rm -rf /tmp/kb /tmp/kb.tgz; \
    else \
      echo "kube-bench asset not found for arch: $arch"; \
    fi

# 安装 docker-bench-security（参考官方：克隆仓库并提供启动器）
RUN set -eux; \
    git clone --depth 1 https://github.com/docker/docker-bench-security.git /opt/docker-bench-security; \
    printf '#!/bin/sh\nexec /bin/sh /opt/docker-bench-security/docker-bench-security.sh "$@"\n' > /usr/local/bin/docker-bench-security; \
    chmod +x /usr/local/bin/docker-bench-security

# 安装 checksec（脚本）
RUN set -eux; \
    curl -fsSL https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec -o /usr/local/bin/checksec; \
    chmod +x /usr/local/bin/checksec

# 安装 Responder（Git）并创建可执行入口
RUN set -eux; \
    git clone --depth 1 https://github.com/lgandx/Responder.git /opt/Responder; \
    printf '#!/bin/sh\nexec /usr/bin/env python3 /opt/Responder/Responder.py "$@"\n' > /usr/local/bin/responder; \
    chmod +x /usr/local/bin/responder

# 安装 hash-identifier（Git）并创建可执行入口
RUN set -eux; \
    git clone --depth 1 https://github.com/blackploit/hash-identifier.git /opt/hash-identifier; \
    chmod +x /opt/hash-identifier/hash-id.py; \
    printf '#!/bin/sh\nexec /usr/bin/env python3 /opt/hash-identifier/hash-id.py "$@"\n' > /usr/local/bin/hash-identifier; \
    chmod +x /usr/local/bin/hash-identifier

# 安装 Ghidra 并创建可执行入口（包含 headless）
RUN set -eux; \
    GHIDRA_URL=$(curl -fsSL https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest | grep browser_download_url | grep PUBLIC | grep -i zip | cut -d '"' -f4 | head -n1); \
    if [ -n "$GHIDRA_URL" ]; then \
      wget -O /tmp/ghidra.zip "$GHIDRA_URL"; \
      mkdir -p /opt/ghidra; \
      unzip -q /tmp/ghidra.zip -d /opt/ghidra; \
      rm -f /tmp/ghidra.zip; \
      GHIDRA_DIR=$(find /opt/ghidra -maxdepth 1 -type d -name "ghidra_*" | head -n1); \
      ln -sf "$GHIDRA_DIR/ghidraRun" /usr/local/bin/ghidra; \
      ln -sf "$GHIDRA_DIR/support/analyzeHeadless" /usr/local/bin/analyzeHeadless; \
    else \
      echo "Failed to resolve Ghidra release URL"; \
    fi

# 预拉取 nuclei templates（可加速首启，失败不阻断）
RUN nuclei -update-templates || true
# 复制项目源代码
COPY . /app

# 暴露 API 端口
EXPOSE 8888

# 健康检查：依赖应用启动后提供 /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${HEXSTRIKE_PORT}/health" || exit 1

# 入口：允许通过环境变量覆盖端口与调试开关
ENV DEBUG_MODE=0

# 默认启动命令（使用 uv 运行）
CMD ["uv", "run", "--", "python", "-u", "/app/hexstrike_server.py"]
