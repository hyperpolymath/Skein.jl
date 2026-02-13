<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Skein.jl, please report it responsibly.

**Preferred:** Use [GitHub Security Advisories](https://github.com/hyperpolymath/Skein.jl/security/advisories/new)

**Alternative:** Email [jonathan.jewell@open.ac.uk](mailto:jonathan.jewell@open.ac.uk)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact assessment
- Suggested fix (if any)

### Response Timeline

- **Acknowledgement:** Within 48 hours
- **Initial assessment:** Within 7 days
- **Fix or mitigation:** Within 30 days for critical issues

## Scope

This policy covers:

- The Skein.jl Julia package (src/, ext/)
- SQLite database operations and schema
- Data import/export functionality
- The KnotTheory.jl extension

## Safe Harbour

We will not pursue legal action against security researchers who:

- Act in good faith
- Avoid privacy violations and data destruction
- Report findings promptly
- Allow reasonable time for remediation before disclosure

## Security Best Practices

When using Skein.jl:

- Use `:memory:` databases for untrusted data
- Validate Gauss code input before storage
- Keep dependencies updated (`Pkg.update()`)
