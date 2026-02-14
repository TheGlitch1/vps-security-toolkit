# VPS Security Toolkit - Phase 1 Implementation Plan

**Overview:** Build a production-ready 4-script security monitoring suite for Ubuntu VPS with terminal, JSON, and HTML outputs. Start with foundational structure, then implement each script sequentially (health-check → security-audit → ssh-analysis → intrusion-check), each generating three output formats with alerting capabilities.

## Implementation Steps

### 1. Initialize Project Structure
Create baseline directories, README.md, .gitignore, setup.sh, and config templates for reuse across scripts

**Deliverables:**
- Project directory structure (docs/, scripts/, config/, tests/)
- README.md with features, prerequisites, installation
- .gitignore for logs, JSON, HTML outputs and sensitive data
- setup.sh for dependency installation and directory creation
- shared-functions.sh for common code (colors, logging, alerting)
- config/vps-toolkit.conf for global configuration

### 2. Implement `vps-health-check.sh`
Foundation script with common functions, CPU/RAM/disk metrics, service checks, JSON/HTML outputs

**Requirements:**
- Uptime, load average, CPU/RAM/SWAP usage with thresholds (>80% warning, >90% critical)
- Disk space for main partitions + /tmp
- Service status: sshd, fail2ban (if installed), cron
- Active network connections (ESTABLISHED count)
- Zombie processes detection
- CPU temperature (if available)
- Last system update date
- Three output formats: color-coded terminal table, JSON, HTML fragment

**Configuration:**
- CPU_WARNING=80, CPU_CRITICAL=90
- RAM_WARNING=80, RAM_CRITICAL=90
- DISK_WARNING=80, DISK_CRITICAL=90
- Email/Telegram alert support

### 3. Implement `vps-security-audit.sh`
SSH hardening checks, fail2ban validation, firewall status, updates available, user account audit with scoring system

**Requirements:**

**SSH Configuration Checks:**
- PermitRootLogin (must be "no" or "prohibit-password")
- PasswordAuthentication (recommended: no)
- Port SSH configuration
- PubkeyAuthentication (must be yes)
- PermitEmptyPasswords (must be no)
- X11Forwarding (recommended: no)
- MaxAuthTries (recommended: ≤3)
- ClientAliveInterval/CountMax

**Fail2ban Status:**
- Installation status
- Active/inactive status
- Active jails count
- jail.local configuration check

**Firewall & Network:**
- UFW status and rules count
- iptables rules summary
- Open ports (ss -tunlp)

**System Updates:**
- Security updates available count
- Kernel version vs latest
- Reboot required flag

**User Accounts:**
- Active shell accounts
- UID 0 accounts (must be root only)
- Password status for all users
- Last login timestamps

**Output:**
- Terminal: Checklist with ✅/⚠️/❌ status
- JSON: Structured report with 0-100 scores
- HTML: Color-coded table with recommendations

### 4. Implement `vps-ssh-analysis.sh`
Parse auth.log for brute-force patterns, identify top attackers, detect anomalies, integrate fail2ban

**Requirements:**

**Global Statistics:**
- Total failed attempts (24h, 7d, 30d, all-time)
- Successful login attempts with timestamps/IPs/users
- Failure/success ratio
- Attack wave detection vs continuous

**Top Attackers:**
- Top 20 IPs by attempt count
- Top 10 IPs targeting root specifically
- Geographic distribution (country via whois, fallback "Unknown")
- Temporal patterns (hour of day, day of week)

**User Analysis:**
- Top 15 targeted usernames
- Invalid vs valid account distinction
- Admin account targeting alert (🔴 CRITICAL)

**Anomaly Detection:**
- Successful connections from unknown IPs
- Multi-user scans from single IP
- Burst attacks (>10 attempts/minute)
- New IPs never seen before

**Fail2ban Integration:**
- Currently banned IPs
- Ban history
- Ban effectiveness metrics

**Output:**
- Terminal: Formatted report with ASCII graphs (█ ▓ ▒ ░)
- JSON: Raw data + calculated statistics
- HTML: Dashboard with sortable tables

### 5. Implement `vps-intrusion-check.sh`
Monitor active sessions, suspicious processes, filesystem anomalies, integrity checks, network connections

**Requirements:**

**Active Sessions:**
- Unexpected SSH sessions (w, who)
- Unauthorized recent logins (last -20)
- Auth.log anomalies

**System Modifications:**
- Recently created user accounts
- sudo/wheel group modifications
- Unauthorized SSH keys in authorized_keys files
- /etc/sudoers* recent changes
- Suspicious cron jobs

**Suspicious Processes:**
- Crypto miners (xmrig, minerd, cpuminer, ethminer, cgminer, bfgminer)
- Backdoors (ncat -l, socat, reverse shells)
- Random/hidden process names
- High CPU without reason
- Unexpected listening ports

**File System:**
- Scripts in /tmp, /var/tmp, /dev/shm
- Recently modified binaries in /usr/bin, /usr/sbin
- Suspicious hidden files (. or ..)
- Webshells (if web server installed)

**Network Connections:**
- Outbound connections to non-standard destinations
- Unexpected listening ports
- Anomalous traffic patterns

**System Logs:**
- Critical messages in syslog
- Suspicious patterns in auth.log (break-in attempts, root sessions)
- Segfaults and crashes

**Integrity:**
- /etc/passwd, /etc/shadow checksums
- Critical permission checks (/etc/sudoers = 0440)
- SUID/SGID bits verification

**Output:**
- Terminal: Threat level report (CLEAN/SUSPICIOUS/COMPROMISED)
- JSON: Detailed findings with evidence
- HTML: Incident report with color-coded severity

### 6. Create Output Templates & Documentation

**Per-Script Deliverables:**
- Standalone HTML dashboard template (Bootstrap 5, DataTables, Chart.js)
- Realistic JSON example output with sample data
- Installation & configuration instructions
- Usage examples and command reference
- Recommended cron schedules (staggered to avoid load spikes)
- Output format reference

**Global Deliverables:**
- Master HTML dashboard integrating all 4 scripts
- Email alert template
- Telegram message template
- Cron setup documentation
- Troubleshooting guide

---

## Design Decisions

### HTML Template Strategy
**Decision:** Separate dashboards per script with unified CSS/JS libraries for modularity
- **Rationale:** Better performance, independent refresh capability, easier maintenance
- **Alternative considered:** Single master dashboard (rejected: complexity and loading overhead)

### Log Parsing Limits
**Decision:** Configurable analysis depth with default limit to last 100k lines
- **Rationale:** Prevents memory exhaustion on high-traffic systems, warns if data truncated
- **Flags:** `--full-logs`, `--max-lines N`

### Dependency Handling
**Decision:** Graceful degradation + setup.sh with optional dependencies
- **Rationale:** Works on minimal systems, better user experience
- **Behavior:** Warn when tools unavailable, skip checks gracefully, provide setup.sh for optional enhancement

### Cron Scheduling
**Decision:** Staggered execution times to prevent load spikes
- **Recommended Schedule:**
  - health-check.sh: Every 6 hours (00:00, 06:00, 12:00, 18:00)
  - security-audit.sh: Daily at 02:00
  - ssh-analysis.sh: Daily at 03:00
  - intrusion-check.sh: Daily at 04:00

### Git Initialization
**Decision:** Initialize git repository immediately with proper .gitignore
- **Rationale:** Version control from start, prevent accidental commits of logs/data

---

## Technical Specifications (Common)

### Mandatory Script Structure
```bash
#!/bin/bash
# Script: [name].sh
# Description: [description]
# Auteur: VPS Security Toolkit
# Version: 1.0.0
# Compatibilité: Ubuntu 20.04, 22.04, 24.04

VERSION="1.0.0"
SCRIPT_NAME=$(basename "$0")
LOG_DIR="/var/log/vps-toolkit"
JSON_DIR="$LOG_DIR/json"
HTML_DIR="$LOG_DIR/html"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Verbosity: silent, normal, verbose
VERBOSITY="normal"

# Output modes
OUTPUT_TERMINAL=true
OUTPUT_JSON=true
OUTPUT_HTML=true

# Alert configuration
ENABLE_EMAIL=false
ENABLE_TELEGRAM=false
EMAIL_TO=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Threshold configuration
CPU_WARNING=80
CPU_CRITICAL=90
# ... etc
```

### Output Format: JSON Schema
```json
{
  "metadata": {
    "script": "script-name",
    "version": "1.0.0",
    "timestamp": "2026-02-14T12:30:00Z",
    "hostname": "vps-hostname",
    "duration_seconds": 2.34
  },
  "summary": {
    "status": "WARNING|OK|CRITICAL",
    "critical_issues": 0,
    "warnings": 2,
    "info": 5
  },
  "data": {},
  "alerts": []
}
```

### Output Format: HTML
- Bootstrap 5 CDN
- DataTables for sortable tables
- Chart.js for graphs (if applicable)
- Responsive design
- Inline CSS (standalone export)
- Auto-refresh meta tag (configurable)

### Logging & Rotation
**Locations:**
- `/var/log/vps-toolkit/health-check.log`
- `/var/log/vps-toolkit/json/` (keep 30 days)
- `/var/log/vps-toolkit/html/` (keep 7 days)
- Compress logs >7 days old to .gz

### Color Scheme
- RED: Critical/Error
- GREEN: Success/OK
- YELLOW: Warning
- BLUE: Info
- WHITE: Default

---

## Dependencies

### Required
- bash 4.0+
- coreutils (ps, uptime, free, df)
- procps-ng
- grep, awk, sed

### Optional (graceful degradation if missing)
- bc (calculations)
- jq (JSON parsing)
- whois (geolocation)
- sensors (CPU temperature)
- mail (email alerts)
- curl (Telegram alerts)
- fail2ban (security checks)
- ufw (firewall checks)

---

## Project Structure (Final)
```
vps-security-toolkit/
├── README.md
├── LICENSE
├── .gitignore
├── .git/
├── VERSION
├── setup.sh
├── Makefile
│
├── scripts/
│   ├── vps-health-check.sh
│   ├── vps-security-audit.sh
│   ├── vps-ssh-analysis.sh
│   ├── vps-intrusion-check.sh
│   └── shared-functions.sh
│
├── config/
│   ├── vps-toolkit.conf
│   ├── vps-toolkit.cron
│   └── fail2ban.conf
│
├── templates/
│   ├── dashboard.html
│   ├── health-check.html
│   ├── security-audit.html
│   ├── ssh-analysis.html
│   └── intrusion-check.html
│
├── docs/
│   ├── INSTALL.md
│   ├── USAGE.md
│   ├── CONTRIBUTING.md
│   ├── API.md
│   └── examples/
│       ├── health-check.json
│       ├── security-audit.json
│       ├── ssh-analysis.json
│       └── intrusion-check.json
│
└── tests/
    └── test-suite.sh
```

---

## Success Criteria

- [ ] All 4 scripts execute successfully as root on Ubuntu 20.04+
- [ ] Each script generates valid JSON output
- [ ] Each script generates standalone HTML reports
- [ ] Email/Telegram alerting works when configured
- [ ] No unhandled errors or crashes
- [ ] Performance <5s per script on typical VPS
- [ ] Documentation complete with examples
- [ ] Git repository initialized with clean history

---

## Notes for Refinement

**Questions to consider:**
1. Should we add a dashboard aggregator script that runs all 4 and generates a master report?
2. Should we support Slack webhooks in addition to email/Telegram?
3. Should we add metric graphing (CPU/RAM trends over time)?
4. Should we create a lightweight web server component for real-time monitoring?
5. Should we add database storage option (SQLite) for historical data?

**Future phases (Phase 2+):**
- Automated remediation actions (kill processes, rotate keys, etc.)
- Integration with external SIEMs
- Machine learning for anomaly detection
- Mobile app for push notifications
- Multi-server management dashboard
