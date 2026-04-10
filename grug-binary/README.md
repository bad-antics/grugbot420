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

**First run** launches the interactive install wizard:
1. Welcome screen
2. License agreement (type `accept` to proceed)
3. Dependency check — detects Julia, downloads it if missing
4. Configuration summary
5. App starts automatically

Every run after that goes straight to the `Brain >` prompt.

To re-run the wizard at any time:
```bash
bindboss reset grugbot420
./grugbot420
```

## What it does

GrugBot is a neuromorphic AI engine. Many pattern nodes compete to respond to your input. Loudest node wins. Type `/help` at the prompt for the full command reference.

## Integrity

```bash
bindboss verify ./grugbot420
```

Hash: `eeea4dd9f54e7287196701e4aedbac0e78348067b3f307fbe97849e25c0a03f0`