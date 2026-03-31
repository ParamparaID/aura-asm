# Security Policy

Aura Shell is early-stage systems software. Please report security issues responsibly.

## Supported Branch

| Branch | Supported |
|---|---|
| `main` | Yes |

## How to Report

Do **not** open a public issue for a suspected vulnerability.

Use a private maintainer contact channel available in this repository (private security report/email configured by maintainers). If no private channel is currently configured, open a minimal public issue without exploit details and request a private handoff.

## What to Include

- commit/branch tested,
- impacted platform (Linux/Windows) and architecture,
- reproduction steps,
- expected vs actual behavior,
- impact assessment,
- proof-of-concept details (if safe to share privately),
- logs/crash traces/offsets.

## Focus Areas

Reports are especially valuable for:

- memory corruption or out-of-bounds behavior,
- ABI misuse that can produce control-flow instability,
- parser/input handling issues with untrusted data,
- plugin boundary and privilege model weaknesses,
- file parsing flaws (including image/asset pipelines).

## Disclosure Process

- We aim to acknowledge reports quickly.
- We may ask for additional validation details.
- We will coordinate disclosure timing after a fix lands.

## Current Security TODOs

- Define and publish a canonical private reporting address.
- Add a `SECURITY_CONTACT` section to project metadata.
- Document supported-version policy once release channels exist.
- Add security regression checks for high-risk parsing paths.
