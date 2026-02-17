# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-17

### Added
- **vps-ssh-analysis.sh**: Complete SSH intrusion analysis script
  - Auth.log parsing with intelligent attack pattern detection
  - Top attackers identification with geolocation support
  - 24h statistics (total attempts, unique IPs, blocked IPs)
  - Attack pattern analysis (brute force, dictionary, targeted)
  - Multi-format output (Terminal, JSON, HTML with charts)
  - Country-based attack visualization with flag badges

- **vps-intrusion-check.sh**: Real-time intrusion detection and system integrity monitoring
  - Active user session monitoring with alert on suspicious logins
  - Network port scanning (established vs listening, suspect detection)
  - SUID file detection with verification against system packages
  - Active network connection monitoring with process tracking
  - Multi-format output (Terminal, JSON, HTML with real-time data)

- **Professional HTML Templates**: Complete dark mode redesign
  - Modern dark theme with professional color palette (#0a0e27, #151932)
  - Bootstrap 5 integration for responsive design
  - Chart.js visualizations (radar charts, bar charts, line charts)
  - Interactive dashboards for all monitoring scripts
  - Consistent design language across all reports
  - Templates: health-check.html, security-audit.html, ssh-analysis.html, intrusion-check.html, index.html

- **Complete Documentation Suite**:
  - INSTALL.md: Step-by-step installation guide
  - USAGE.md: Comprehensive usage documentation with examples
  - CONTRIBUTING.md: Contribution guidelines and coding standards
  - Cron examples: Production, lightweight, and critical monitoring schedules

### Fixed
- **security-audit.sh**: Chart placeholder spacing issues (Chart.js compatibility)
- **security-audit.sh**: Data extraction migrated from grep to jq for reliability
- **ssh-analysis.sh**: JSON extraction using jq instead of grep lookbehind patterns
- **intrusion-check.sh**: Flexible grep patterns for malformed JSON compatibility
- **All templates**: Automated HTML formatting and consistency improvements

### Security
- Removed sensitive files and hardcoded credentials
- Improved configuration template security
- Enhanced alert system privacy controls

### Documentation
- Expanded cron configuration examples

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
- HTML dashboards: Advanced features planned (real-time updates, historical data)
- Telegram alerts: Implemented but needs comprehensive testing
- Geolocation for SSH: Requires whois, optional dependency

## [Unreleased]

### Planned for v1.2.0
- Web dashboard with real-time monitoring
- Database integration for historical data
- Advanced anomaly detection with machine learning
- Multi-server management capabilities
- API for external integrations

---

[1.1.0]: https://github.com/TheGlitch1/vps-security-toolkit/releases/tag/v1.1.0
[1.0.0]: https://github.com/TheGlitch1/vps-security-toolkit/releases/tag/v1.0.0
