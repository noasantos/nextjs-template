# Security Scanners

This document describes the security scanning tools integrated into the CI/CD
pipeline for AI-assisted development.

## Overview

Three security scanners run automatically on every pull request and push to
main/master branches:

1. **OSV-Scanner** - Dependency vulnerability scanning
2. **actionlint** - GitHub Actions workflow linting
3. **zizmor** - GitHub Actions security auditing

## Tools

### OSV-Scanner

**What it does:** OSV-Scanner is a vulnerability scanner maintained by Google
that checks your dependencies against the OSV (Open Source Vulnerabilities)
database. It scans your `pnpm-lock.yaml` file to identify known vulnerabilities
in your project's dependencies.

**Why it matters for AI-assisted development:** AI coding assistants may suggest
adding new dependencies or updating existing ones. OSV-Scanner automatically
catches vulnerable versions before they reach production, providing a safety net
against AI-suggested dependency updates that introduce security risks.

**How to run locally:**

```bash
# Install (requires Go)
go install github.com/google/osv-scanner/cmd/osv-scanner@latest

# Run against your lockfile
osv-scanner -r pnpm-lock.yaml
```

**What violations mean:**

- **CRITICAL/HIGH**: Known vulnerabilities with significant impact. Update the
  affected dependency immediately.
- **MEDIUM**: Moderate severity vulnerabilities. Should be addressed in the next
  maintenance cycle.
- **LOW**: Low severity issues. Track and address when convenient.

The CI job will fail on high-severity vulnerabilities, blocking merges until
resolved.

---

### actionlint

**What it does:** actionlint is a linter specifically designed for GitHub
Actions workflow files. It checks for syntax errors, invalid action references,
incorrect permissions, and common mistakes in `.github/workflows/*.yml` files.

**Why it matters for AI-assisted development:** When AI assistants generate or
modify workflow files, they may introduce subtle syntax errors or reference
non-existent action versions. actionlint catches these issues before they break
your CI/CD pipeline, ensuring workflow reliability.

**How to run locally:**

```bash
# Install (macOS)
brew install actionlint

# Or install via Go
go install github.com/rhysd/actionlint/cmd/actionlint@latest

# Run against all workflow files
actionlint .github/workflows/*.yml
```

**What violations mean:**

- **Syntax errors**: Invalid YAML structure or GitHub Actions syntax. The
  workflow will fail to run.
- **Invalid action references**: References to actions that don't exist or have
  incorrect versions.
- **Permission issues**: Missing or excessive permissions that could cause job
  failures or security risks.
- **Best practice violations**: Deviations from recommended patterns that could
  cause unexpected behavior.

---

### zizmor

**What it does:** zizmor is a security auditor for GitHub Actions that analyzes
workflow files for security anti-patterns and potential attack vectors. It
checks for issues like:

- Insecure action checkouts (`@main` instead of pinned versions)
- Overly permissive permissions
- Dangerous script injection patterns
- Untrusted input handling
- Known vulnerable action patterns

**Why it matters for AI-assisted development:** AI assistants may not be aware
of the latest GitHub Actions security best practices. zizmor provides an
additional security layer by auditing workflows for common security mistakes,
ensuring AI-generated workflows follow security best practices.

**How to run locally:**

```bash
# Install via pip
pip install zizmor

# Or install via cargo
cargo install zizmor

# Run in auditor mode (most strict)
zizmor --persona auditor .github/workflows

# Run in default mode
zizmor .github/workflows
```

**What violations mean:**

- **high**: Critical security issues that could lead to workflow compromise.
  Must be fixed immediately.
- **medium**: Significant security concerns that should be addressed before
  merging.
- **low**: Minor security improvements or informational findings.
- **note**: Informational findings for awareness.

The `--persona auditor` flag runs zizmor in the most strict mode, treating all
findings as potential issues.

---

## Integration with AI-Assisted Development

These tools are essential for maintaining security in an AI-assisted development
workflow:

1. **Automated Safety Net**: AI assistants can make mistakes. These scanners
   provide automated checks that catch security issues before they reach
   production.

2. **Learning Tool**: When a scanner flags an AI-suggested change, review the
   violation to understand the security concern. This helps you provide better
   prompts to the AI in the future.

3. **Consistency**: Security scanning ensures that both human-written and
   AI-generated code meet the same security standards.

4. **Defense in Depth**: Multiple scanners provide overlapping coverage.
   OSV-Scanner catches dependency issues, actionlint catches syntax errors, and
   zizmor catches security anti-patterns.

## Troubleshooting

### OSV-Scanner fails on a dependency

1. Check the OSV database entry for the vulnerability
2. Update to a patched version if available
3. If no patch exists, consider alternative dependencies or apply mitigations
4. Document any accepted risks in your security policy

### actionlint reports workflow errors

1. Review the specific error message
2. Check the action documentation for correct syntax
3. Ensure action versions are pinned (e.g., `@v4` not `@main`)
4. Validate permissions are correctly specified

### zizmor reports security issues

1. Review the finding in the context of your workflow
2. Pin action versions to specific commits or tags
3. Reduce permissions to minimum required
4. Avoid passing untrusted input to `run` steps
5. Use the `--persona` flag to adjust strictness based on your needs

## References

- [OSV-Scanner Documentation](https://google.github.io/osv-scanner/)
- [actionlint GitHub Repository](https://github.com/rhysd/actionlint)
- [zizmor Documentation](https://docs.zizmor.sh/)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
