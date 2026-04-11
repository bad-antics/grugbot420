# Security Policy

## Supported Versions

| Version | Supported          |
|:--------|:-------------------|
| 1.x     | ✅ Active support  |
| < 1.0   | ❌ Unsupported     |

## Reporting a Vulnerability

If you discover a security vulnerability in GrugBot420, **please do not open a public issue**.

Report via [GitHub Security Advisories](https://github.com/bad-antics/grugbot420/security/advisories/new).

### What to include

- Description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Impact assessment

### Response timeline

| Stage | Timeframe |
|:------|:----------|
| Acknowledgment | Within 48 hours |
| Assessment | Within 1 week |
| Fix | Within 2–4 weeks |
| Disclosure | After fix is released |

### Scope

- **Engine** (`src/`) — All cognitive engine modules
- **Node system** — Pattern nodes, lobes, BrainStem
- **Input processing** — InputQueue, SemanticVerbs, ChatterMode

### Out of scope

- Specimen configurations (JSON personality files)
- Documentation and examples
