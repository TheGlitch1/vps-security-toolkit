# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-14

### Added
- **vps-health-check.sh**: Complete VPS health monitoring script
  - System metrics (CPU, RAM, SWAP, disk usage)
  - Service status monitoring (SSH, cron, fail2ban)
  - Network statistics (established/listening connections)
  - Process monitoring (total, zombie, running processes)
  - Multi-format output (Terminal, JSON, HTML)
  - Email/Telegram alerting system
  - Threshold-based alerts (WARNING/CRITICAL)
  
- **vps-security-audit.sh**: Comprehensive security audit script
  - SSH configuration hardening check (8 parameters)
  - Fail2ban installation and status verification
  - Firewall audit (UFW + iptables)
  - System updates monitoring (security updates, reboot required)
  - User accounts audit (shell users, UID 0, password status)
  - Security scoring system (0-100 with detailed breakdown)
  - Multi-format output (Terminal, JSON, HTML)
  - Low score alerting system

- **shared-functions.sh**: Comprehensive utility library
  - Color-coded logging system (info, success, warning, error)
  - Terminal formatting (headers, sections, tables, progress bars)
  - Alert functions (email via mailutils, Telegram via API)
  - JSON/HTML generation utilities
  - System checks (root, Ubuntu compatibility, commands)
  - Automatic log cleanup

- **setup.sh**: Automated installation script
  - Dependency detection and installation
  - Interactive configuration
  - Directory structure creation
  - Cron job setup
  - Dry-run mode support

- **Configuration system**:
  - Complete configuration template (vps-toolkit.conf.example)
  - Cron schedule templates (vps-toolkit.cron)
  - Flexible threshold configuration
  - Alert system configuration

- **Testing infrastructure**:
  - Email alert testing script
  - Telegram alert testing script
  - Test documentation

- **Documentation**:
  - Comprehensive README with features, requirements, installation
  - MIT License
  - Test documentation

### Tested
- Ubuntu 24.04 LTS (noble)
- Email alerts: Successfully delivered via mailutils + postfix
- Health monitoring: All metrics accurate (CPU, RAM, disk, services)
- Security audit: Score calculation verified (53/100 on test system)
- Service detection: Ubuntu SSH service name compatibility (ssh vs sshd)
- JSON output: Valid structure, 1-2.5KB per report
- Terminal output: Color-coded, emoji-enhanced, progress bars

### Fixed
- SSH service detection on Ubuntu (handles both 'ssh' and 'sshd')
- Fail2ban status: Distinguishes not_installed vs inactive
- JSON parsing: Robust grep patterns with fallbacks
- Temperature display: Graceful handling when sensors unavailable
- HTML generation: Escaped jQuery $ in bash heredocs
- Verbose logging: Redirected to stderr to avoid JSON pollution
- Score calculation: Proper weighted average across audits

### Known Limitations
- vps-ssh-analysis.sh: Not yet implemented (planned for v1.1.0)
- vps-intrusion-check.sh: Not yet implemented (planned for v1.1.0)
- HTML dashboards: Basic templates only, full Bootstrap dashboards planned
- Telegram alerts: Implemented but not fully tested (deferred)
- Geolocation for SSH: Requires whois, optional dependency

## [Unreleased]

### Planned for v1.1.0
- vps-ssh-analysis.sh: Auth.log parser with attacker detection
- vps-intrusion-check.sh: Active session and filesystem integrity monitoring
- Complete HTML dashboard templates with Chart.js visualizations
- Full Telegram alert testing
- Additional documentation (INSTALL.md, USAGE.md, CONTRIBUTING.md)

### Planned for v1.2.0
- Web dashboard with real-time monitoring
- Database integration for historical data
- Advanced anomaly detection with machine learning
- Multi-server management capabilities
- API for external integrations

---

[1.0.0]: https://github.com/TheGlitch1/vps-security-toolkit/releases/tag/v1.0.0
