# Security policy

## Supported versions

The latest minor release receives security fixes. Older versions are best-effort.

| Version | Supported |
|---------|-----------|
| 1.x     | ✅         |

## Reporting a vulnerability

**Please do not open a public issue for security reports.**

Email the maintainers privately or use [GitHub's private security advisory](https://github.com/nikolayAsparuhov/MacSense/security/advisories/new):

1. Open the linked page
2. Describe the issue, impact, and reproduction steps
3. Include the MacSense version (`About MacSense`) and macOS version
4. We respond within 7 days

If the issue is confirmed:

- Coordinated disclosure: we'll agree on a release date and credit you in the changelog
- Responsible disclosure: you give us a reasonable window (typically 90 days) to ship a fix before publishing

## Threat model

MacSense is a local-only app. Network calls are limited to:

- One opt-in public-IP lookup against `api.ipify.org` (with 3 fallbacks)

Anything that breaks this — exfiltration, credential theft, bypass of the Trash safety guard, code execution from a crafted plist, etc. — is in scope.

Out of scope:

- Issues that require physical access to an unlocked Mac
- Issues that depend on the user already running malware with root
- macOS itself bugs (report to Apple)

## Hardening checklist

We try to:

- Always move files to Trash, not delete in place
- Never modify code-signed app bundles (login-item helpers, etc.)
- Never write to system-protected paths without `do shell script ... with administrator privileges` (which prompts the user)
- Never make outbound network calls except the documented public-IP lookup
- Never collect telemetry, crash reports, or user identifiers
