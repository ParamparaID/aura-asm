# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| `main` | ✅ |

## Reporting a Vulnerability

Please **do not** open public issues for security vulnerabilities.

Instead, report vulnerabilities privately by email:

- `security@aurashell.dev` *(placeholder security inbox)*

Expected response time: **within 72 hours**.

Please include:

- affected version, branch, or commit
- reproduction steps or proof-of-concept
- potential impact and severity assessment
- relevant logs, traces, or crash data

We appreciate responsible disclosure. Security researchers who report valid findings may be acknowledged in
`CHANGELOG` (with permission).

## Scope

We are especially interested in reports related to:

- memory corruption in allocator or memory-management paths
- buffer overflows in rendering pipelines (including fonts and PNG handling)
- privilege escalation through plugin interfaces
- Wayland protocol violations that can compromise stability or safety
