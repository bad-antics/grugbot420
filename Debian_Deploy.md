# 🧠 grugbot420 — Debian Deployment Guide

Platform: Debian 12 (Bookworm) · Architecture: x86_64

---

## The short version

GrugBot now ships as a single self-extracting binary. No Julia install required upfront,
no dependency wrangling, no source checkout. Download, chmod, run.

```bash
wget https://github.com/marshalldavidson61-arch/grugbot420/raw/main/grug-binary/grugbot420
chmod +x grugbot420
./grugbot420
```

That is it. The binary handles everything else.

---

## What happens on first run

1. The binary extracts the full GrugBot source to a local directory
2. It checks whether `julia` is on your PATH
3. **If Julia is missing** — the binary opens [julialang.org/downloads](https://julialang.org/downloads/) in your browser, prints the install URL, and waits at the prompt. Install Julia, make sure it is on your PATH, press Enter. The binary re-checks and continues.
4. Once Julia is confirmed present, the engine starts and you land at the `Brain >` prompt
5. Every subsequent run skips the dep check entirely and goes straight to the prompt

---

## Installing Julia on Debian

If you need Julia and want to install it before running grugbot for the first time:

```bash
# Download Julia 1.10 (1.9+ required)
wget https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz
tar -xzf julia-1.10.5-linux-x86_64.tar.gz
sudo mv julia-1.10.5 /opt/julia

# Add to PATH (add this line to ~/.bashrc or ~/.profile for persistence)
export PATH=/opt/julia/bin:$PATH

# Verify
julia --version
```

Then run the binary normally — it will find Julia and proceed without prompting.

---

## Running in the background (daemon mode)

```bash
nohup ./grugbot420 > grugbot.log 2>&1 &
tail -f grugbot.log
```

---

## systemd service

Create `/etc/systemd/system/grugbot420.service`:

```ini
[Unit]
Description=GrugBot420 AI Engine
After=network.target

[Service]
ExecStart=/path/to/grugbot420
WorkingDirectory=/path/to
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable grugbot420
sudo systemctl start grugbot420
sudo journalctl -u grugbot420 -f
```

---

## Verifying the binary

```bash
# Requires bindboss (github.com/marshalldavidson61-arch/Bindboss)
bindboss verify ./grugbot420
```

Expected SHA-256: `03fb36ca7c0dec0c8f7234e967572b464dbfce7ed889c0b458673ec8e3f9a3c3`

Or verify manually:

```bash
# The payload hash is stored in the binary's trailer — bindboss verify does this for you
sha256sum grugbot420
```

---

## Coming soon

GrugBot420 will be available directly from Linux package repositories (apt, etc.).
When that lands, installation will be a single `apt install grugbot420` with no manual steps.
Watch the repo for updates.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `julia: command not found` after installing | Add Julia's `bin/` directory to your PATH and open a new terminal |
| Binary won't run: `Permission denied` | Run `chmod +x grugbot420` |
| Engine starts but crashes immediately | Check `grugbot.log` — most likely a missing Julia package; run `julia --project=. -e 'using Pkg; Pkg.instantiate()'` in the extracted dir |
| Want to force a fresh dep check | `bindboss reset grugbot420` then re-run the binary |