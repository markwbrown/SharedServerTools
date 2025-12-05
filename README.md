# server-tools

A lightweight collection of shell utilities for common server administration tasks.  
Designed to be:

- **Consistent** — all commands follow similar patterns and output styles
- **Portable** — pure Bash, no dependencies outside standard Linux tooling
- **Extensible** — add your own scripts under `bin/` and shared helpers under `lib/`
- **Safe** — sane defaults, validation, helpful error messages

Current scope focuses on **Fail2Ban helpers**, but the toolkit is structured to grow into an all-purpose server admin utility suite (nginx helpers, docker helpers, backup helpers, monitoring tools, etc.).

---

## Features

### ✔ Fail2Ban Utilities
| Script | Description |
|--------|-------------|
| `fail2ban-list-jails` | Prints all active jails on the system. |
| `fail2ban-status-all` | Shows detailed `fail2ban-client status` for each jail. |
| `fail2ban-unban-ip` | Unban an IP from a specific jail *or all jails where it's present*. |
| `fail2ban-ban-ip` | Manually ban an IP in a specific jail. |

### ✔ Symlink-safe script resolution
All executables correctly resolve their location even when symlinked into `/usr/local/bin`.

### ✔ Standardized library of shared helpers
Color functions, error handling, command validation, and a wrapper for `fail2ban-client` with automatic sudo use.

---

## Repository Structure

