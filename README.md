<div align="center">

<img src="assets/hexstrike-logo.png" alt="HexStrike AI Logo" width="220" style="margin-bottom: 20px;"/>

</div>



# HexStrike AI Kit 📦

> One-click build, instant development, continuously track upstream  
> Pack HexStrike AI into a box and take it away!

---

## 🌟 One-sentence pitch
HexStrike AI Kit is the **containerized distribution** of [hexstrike-ai](https://github.com/<upstream>/hexstrike-ai):  
- code + environment + dependencies + utilities are baked into a single Dockerfile.  
- **Clone → build → run** and you instantly get a bit-for-bit reproducible environment that keeps itself in-sync with upstream.  
- A web UI, job storage and more batteries-included features are already on the roadmap.

---

## 🚀 Quick start
1. Clone (SSH is faster)
   ```bash
   git clone git@github.com:<your-namespace>/hexstrike-ai-kit.git
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
Upstream license follows [hexstrike-ai](https://github.com/0x4m4/hexstrike-ai/blob/main/LICENSE).

---

## 💬 Contact
- Issues: bugs, questions or feature requests  
- Discussions: roadmap & ideas  

**Star ⭐ us to get notified of every new release!**

