<div align="center">

<img src="hexstrike-ai-kit.png" alt="HexStrike AI Kit Logo" width="220" style="margin-bottom: 20px;"/>

</div>



# HexStrike AI Kit 📦

> One-click build, instant development, continuously track upstream  
> Pack HexStrike AI into a box and take it away!

---

## 🌟 One-sentence pitch
HexStrike AI Kit is the **containerized distribution** of [hexstrike-ai](https://github.com/0x4m4/hexstrike-ai):  
- code + environment + dependencies + utilities are baked into a single Dockerfile.  
- **Clone → build → run** and you instantly get a bit-for-bit reproducible environment that keeps itself in-sync with upstream.  
- A web UI, job storage and more batteries-included features are already on the roadmap.

---

## 📥 Pull Pre-built Image from GHCR (Alternative to Local Build)
To save time on local image building, you can directly pull the official pre-built image from GitHub Container Registry (GHCR). We provide region-optimized addresses for faster access:


### 1. GHCR Pull Addresses
| User Region       | GHCR Pull Address                              | Description                                                                 |
|--------------------|------------------------------------------------|-----------------------------------------------------------------------------|
| Global (International) | `ghcr.io/airskye/hexstrike-ai-kit:latest`     | Default address for users outside Mainland China, with global CDN support. |
| Mainland China     | `ghcr.nju.edu.cn/airskye/hexstrike-ai-kit:latest` | Mirrored address for users in Mainland China, optimized for local network speed. |

### 2. Pull & Run Commands
Skip the **Build** step in the "Quick Start" section, and use the commands below to pull the image and run the container directly.

#### For Global Users:
```bash
# Pull the image from official GHCR
docker pull ghcr.io/airskye/hexstrike-ai-kit:latest


# Run the container (replace the image name with the GHCR address)
docker run --rm -it \
  -p 8888:8888 \
  -e HEXSTRIKE_HOST=0.0.0.0 \
  -e HEXSTRIKE_PORT=8888 \
  -e DEBUG_MODE=0 \
  ghcr.io/airskye/hexstrike-ai-kit:latest
```

#### For Mainland China Users:
```bash
# Pull the image from the mirrored GHCR
docker pull ghcr.nju.edu.cn/airskye/hexstrike-ai-kit:latest


# Run the container (replace the image name with the mirrored address)
docker run --rm -it \
  -p 8888:8888 \
  -e HEXSTRIKE_HOST=0.0.0.0 \
  -e HEXSTRIKE_PORT=8888 \
  -e DEBUG_MODE=0 \
  ghcr.nju.edu.cn/airskye/hexstrike-ai-kit:latest
```

---

## 🚀 Quick start
1. Clone (SSH is faster)
   ```bash
   git clone git@github.com:bayuncao/hexstrike-ai-kit.git
   cd hexstrike-ai-kit
   ```

2. Build
   ```bash
   sudo docker build -t hexstrike-ai-kit:latest .
   ```

3. Run
   ```bash
   docker run --rm -it \
     -p 8888:8888 \
     -e HEXSTRIKE_HOST=0.0.0.0 \
     -e HEXSTRIKE_PORT=8888 \
     -e DEBUG_MODE=0 \
     hexstrike-ai-kit:latest
   ```

---

## 🔁 Stay in-sync with upstream
We auto-merge upstream commits daily through GitHub Actions into branch `upstream-sync`.  
Prefer manual control?
```bash
./scripts/sync-upstream.sh
```
The script will:
1. Add the upstream remote if missing
2. Fetch & merge the latest main branch
3. Generate a merge report and pause on conflicts for manual resolution

Usage:
- Make it executable
  ```bash
  chmod +x ./scripts/sync-upstream.sh
  ```
- Optional flags
  - `--remote <name>`: upstream remote name (default: `upstream`)
  - `--target-branch <name>`: local merge branch (default: `upstream-sync`)
  - `-h, --help`: show help

Behavior:
- Ensures a clean working tree before proceeding
- Detects upstream default branch (HEAD), falling back to `main`/`master`
- Preserves Dockerfile-related files during merge (`Dockerfile`, `Dockerfile.*`, `.dockerignore`, `docker/**`, plus `README.md` and `hexstrike-ai-kit.png`)
- Generates `MERGE_UPSTREAM_REPORT.md` and pauses on conflicts for manual resolution

---

## 🧩 Roadmap
- ✅ Containerization (done)
- 🚧 Web UI (React + FastAPI, branch `feature/web-ui`, target v0.3.0)
- 🚧 Job storage (SQLite/PostgreSQL dual backend, supports caching & resume)
- 📦 One-click deployment scripts (AWS / GCP / on-prem K8s)
- 🌐 Multi-language docs (EN & CN)

---

## 🤝 Contributing
1. Fork this repo
2. Create `feature/xxx`
3. Open a PR to `main`  
All code is auto-formatted and unit-tested via pre-commit; contributions are under MIT.

---

## 📄 License
MIT © HexStrike AI Kit  
Upstream license follows [hexstrike-ai](https://github.com/0x4m4/hexstrike-ai/blob/master/README.md).

---

## 💬 Contact
- Issues: bugs, questions or feature requests  
- Discussions: roadmap & ideas  

**Star ⭐ us to get notified of every new release!**

