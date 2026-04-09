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

**First run** launches the interactive install wizard, which will:
1. Show a welcome screen and license agreement
2. Check that Julia 1.9+ is installed
3. Offer to download Julia if it's missing
4. Confirm configuration before starting

Every run after that goes straight to the `Brain >` prompt — the wizard only runs once.

To re-run the wizard at any time:
```bash
bindboss reset grugbot420
./grugbot420
```

## What it does

GrugBot is a neuromorphic AI engine. Many pattern nodes compete to respond to your input. Loudest node wins. Type `/help` at the prompt for the full command reference.

## Integrity

```bash
# verify the binary is intact (SHA-256 check)
bindboss verify ./grugbot420
```

Hash: `83aee33c72acca921e887fcdc6899e346d383610a4a993ac99b3be3abd6db2e2`