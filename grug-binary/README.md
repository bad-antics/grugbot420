# grugbot420 — binary release

This is a self-extracting binary built with [bindboss](https://github.com/marshalldavidson61-arch/Bindboss).

## Requirements

- [Julia 1.9+](https://julialang.org/downloads/) — must be on your PATH
- Linux x86_64

## Running

```bash
chmod +x grugbot420
./grugbot420
```

First run checks that Julia is installed. If it's missing, the binary opens the Julia download page, waits for you to install it, then continues. Every run after that goes straight to the `Brain >` prompt.

## What it does

GrugBot is a neuromorphic AI engine. Many pattern nodes compete to respond to your input. Loudest node wins. Type `/help` at the prompt for the full command reference.

## Integrity

```bash
# verify the binary is intact (SHA-256 check)
bindboss verify ./grugbot420
```

Hash: `03fb36ca7c0dec0c8f7234e967572b464dbfce7ed889c0b458673ec8e3f9a3c3`