# 🛡️ VPS Security Toolkit

> Suite professionnelle de monitoring et audit de sécurité pour VPS Ubuntu

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](VERSION)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash%204.0%2B-orange.svg)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/ubuntu-20.04%20|%2022.04%20|%2024.04-purple.svg)](https://ubuntu.com/)
[![Tested](https://img.shields.io/badge/tested-passing-brightgreen.svg)](tests/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## 📋 Description

VPS Security Toolkit est une collection de scripts bash professionnels conçus pour monitorer, auditer et sécuriser vos serveurs VPS Ubuntu. Détectez les intrusions, analysez les attaques SSH, générez des rapports automatisés et recevez des alertes en temps réel.

## ✨ Fonctionnalités

### 🏥 Health Check (`vps-health-check.sh`)
- Monitoring des ressources système (CPU, RAM, SWAP, Disk)
- Vérification des services critiques (SSH, fail2ban, cron)
- Détection des processus zombies
- Surveillance de la température CPU
- Alertes configurables par seuils

### 🔒 Security Audit (`vps-security-audit.sh`)
- Audit complet de la configuration SSH
- Vérification fail2ban et firewall (UFW/iptables)
- Analyse des comptes utilisateurs
- Détection des mises à jour de sécurité
- Score de sécurité (0-100)

### 🔍 SSH Analysis (`vps-ssh-analysis.sh`)
- Analyse des tentatives d'intrusion SSH
- Top 20 des IPs attaquantes avec géolocalisation
- Détection de patterns d'attaque (brute-force, scans)
- Statistiques temporelles (24h, 7j, 30j, all-time)
- Intégration fail2ban pour suivi des bans

### 🚨 Intrusion Check (`vps-intrusion-check.sh`)
- Détection d'intrusion et compromission
- Surveillance des sessions SSH actives
- Détection de processus suspects (miners, backdoors)
- Vérification d'intégrité système
- Analyse des modifications système suspectes

## 🎯 Formats de Sortie

Chaque script génère **3 formats de sortie** :

1. **Terminal** : Rapport coloré avec tableaux formatés
2. **JSON** : Données structurées pour intégration externe
3. **HTML** : Dashboard responsive avec graphiques interactifs

## 📦 Installation

### Prérequis

**Système d'exploitation :**
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

**Dépendances obligatoires :**
- bash 4.0+
- coreutils
- procps-ng

**Dépendances optionnelles :**
- `bc` : Calculs précis
- `jq` : Parsing JSON avancé
- `whois` : Géolocalisation des IPs
- `sensors` : Température CPU
- `mail` : Alertes email
- `curl` : Alertes Telegram
- `fail2ban` : Détection d'intrusions
- `ufw` : Firewall

### Installation rapide

```bash
# 1. Cloner le repository
cd /opt
sudo git clone https://github.com/votre-username/vps-security-toolkit.git
cd vps-security-toolkit

# 2. Rendre les scripts exécutables
sudo chmod +x scripts/*.sh
sudo chmod +x setup.sh

# 3. Exécuter l'installation
sudo ./setup.sh

# 4. Vérifier l'installation
sudo ./scripts/vps-health-check.sh
```

### Installation manuelle

```bash
# Créer les répertoires de logs
sudo mkdir -p /var/log/vps-toolkit/{json,html}

# Installer les dépendances optionnelles
sudo apt update
sudo apt install -y bc jq whois lm-sensors mailutils curl fail2ban ufw

# Copier la configuration
sudo cp config/vps-toolkit.conf /etc/vps-toolkit.conf

# Configurer les permissions
sudo chown -R root:root /opt/vps-security-toolkit
```

## 🚀 Utilisation

### Exécution basique

```bash
# Health check
sudo ./scripts/vps-health-check.sh

# Security audit
sudo ./scripts/vps-security-audit.sh

# SSH analysis
sudo ./scripts/vps-ssh-analysis.sh

# Intrusion check
sudo ./scripts/vps-intrusion-check.sh
```

### Options avancées

```bash
# Mode verbose
sudo ./scripts/vps-health-check.sh --verbose

# Mode silencieux (JSON uniquement)
sudo ./scripts/vps-health-check.sh --silent

# Désactiver la génération HTML
sudo ./scripts/vps-health-check.sh --no-html

# Alertes email
sudo ./scripts/vps-security-audit.sh --email admin@example.com

# Alertes Telegram
sudo ./scripts/vps-intrusion-check.sh \
  --telegram "YOUR_BOT_TOKEN" "YOUR_CHAT_ID"

# Combinaison complète
sudo ./scripts/vps-ssh-analysis.sh --verbose \
  --email security@example.com \
  --telegram "$BOT_TOKEN" "$CHAT_ID"
```

### Analyse des logs SSH avancée

```bash
# Analyser tous les logs (pas de limite)
sudo ./scripts/vps-ssh-analysis.sh --full-logs

# Limiter à 50000 dernières lignes
sudo ./scripts/vps-ssh-analysis.sh --max-lines 50000
```

## ⏰ Automatisation (Cron)

### Configuration recommandée

```bash
# Éditer le crontab root
sudo crontab -e

# Ajouter les lignes suivantes (horaires décalés pour éviter les pics de charge)
```

```cron
# VPS Security Toolkit - Automated Monitoring

# Health check toutes les 6 heures
0 */6 * * * /opt/vps-security-toolkit/scripts/vps-health-check.sh --silent >> /var/log/vps-toolkit/cron.log 2>&1

# Security audit quotidien à 2h du matin
0 2 * * * /opt/vps-security-toolkit/scripts/vps-security-audit.sh --silent --email admin@example.com >> /var/log/vps-toolkit/cron.log 2>&1

# SSH analysis quotidien à 3h du matin
0 3 * * * /opt/vps-security-toolkit/scripts/vps-ssh-analysis.sh --silent >> /var/log/vps-toolkit/cron.log 2>&1

# Intrusion check quotidien à 4h du matin (alerte critique par email + Telegram)
0 4 * * * /opt/vps-security-toolkit/scripts/vps-intrusion-check.sh --silent --email security@example.com --telegram "$BOT_TOKEN" "$CHAT_ID" >> /var/log/vps-toolkit/cron.log 2>&1
```

### Import de configuration pré-configurée

```bash
sudo cp config/vps-toolkit.cron /etc/cron.d/vps-toolkit
sudo chmod 644 /etc/cron.d/vps-toolkit
sudo systemctl restart cron
```

## 📊 Emplacement des Rapports

```
/var/log/vps-toolkit/
├── health-check.log          # Logs texte health check
├── security-audit.log        # Logs texte security audit
├── ssh-analysis.log          # Logs texte SSH analysis
├── intrusion-check.log       # Logs intrusion check
├── cron.log                  # Logs des exécutions cron
│
├── json/                     # Rapports JSON (30 jours)
│   ├── health-check_2026-02-14_12-00-00.json
│   ├── security-audit_2026-02-14_02-00-00.json
│   ├── ssh-analysis_2026-02-14_03-00-00.json
│   └── intrusion-check_2026-02-14_04-00-00.json
│
└── html/                     # Dashboards HTML (7 jours)
    ├── dashboard_latest.html
    ├── health-check_latest.html
    ├── security-audit_latest.html
    ├── ssh-analysis_latest.html
    └── intrusion-check_latest.html
```

## 🔔 Configuration des Alertes

### Email (avec `mail`)

```bash
# Installer mailutils
sudo apt install -y mailutils

# Configurer postfix ou utiliser SMTP externe
sudo dpkg-reconfigure postfix

# Tester
echo "Test" | mail -s "Test VPS Toolkit" admin@example.com
```

### Telegram

```bash
# 1. Créer un bot avec @BotFather
# 2. Récupérer le token : 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
# 3. Obtenir votre chat_id : https://api.telegram.org/bot<TOKEN>/getUpdates

# Tester
curl -X POST "https://api.telegram.org/bot123456789:ABCdefGHIjklMNOpqrsTUVwxyz/sendMessage" \
  -d chat_id="987654321" \
  -d text="🛡️ Test VPS Security Toolkit"

# Ajouter au script
sudo ./scripts/vps-health-check.sh \
  --telegram "123456789:ABCdefGHIjklMNOpqrsTUVwxyz" "987654321"
```

## 🛠️ Configuration Avancée

### Modifier les seuils d'alerte

Éditer `/etc/vps-toolkit.conf` ou passer en ligne de commande :

```bash
# Dans le script (éditer directement)
CPU_WARNING=70
CPU_CRITICAL=85
RAM_WARNING=75
RAM_CRITICAL=90
DISK_WARNING=80
DISK_CRITICAL=95
```

### Personnaliser les sorties

```bash
# Désactiver la couleur (pour piping)
export NO_COLOR=1
sudo ./scripts/vps-health-check.sh

# JSON uniquement
sudo ./scripts/vps-health-check.sh --no-html --silent

# HTML uniquement
sudo ./scripts/vps-health-check.sh --no-json --silent
```

## 📈 Cas d'Usage Réels

### Scénario 1 : Détection d'attaque SSH massive

```bash
$ sudo ./scripts/vps-ssh-analysis.sh

🔍 VPS SSH Analysis Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Global Statistics (All Time)
  Total failed attempts: 16,393
  Successful logins: 8
  Failure ratio: 99.95%
  
🚨 Top Attackers
  1. 167.99.150.0     → 3,382 attempts (DigitalOcean, USA)
  2. 103.142.25.98    → 2,891 attempts (Vietnam)
  3. 78.47.204.33     → 1,764 attempts (Hetzner, Germany)
  
⚠️  CRITICAL: Account 'admin' targeted 4,224 times
⚠️  WARNING: 89 unique IPs detected in last 24h

✅ Rapport complet: /var/log/vps-toolkit/html/ssh-analysis_latest.html
```

### Scénario 2 : Détection de miner de crypto

```bash
$ sudo ./scripts/vps-intrusion-check.sh

🚨 VPS Intrusion Detection Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  THREAT LEVEL: COMPROMISED

❌ CRITICAL FINDINGS:
  [1] Suspicious process detected: /tmp/.xmrig (PID: 12345)
      CPU: 98.5% | User: www-data | Started: 2026-02-13 18:30
      
  [2] Unauthorized SSH key in /var/www/.ssh/authorized_keys
      Fingerprint: SHA256:abc123...
      Added: 2026-02-13 18:25
      
  [3] Outbound connection to mining pool:
      45.32.108.12:3333 (ESTABLISHED)

🔧 RECOMMENDED ACTIONS:
  1. Kill process: sudo kill -9 12345
  2. Remove SSH key: sudo rm /var/www/.ssh/authorized_keys
  3. Block IP: sudo ufw deny out to 45.32.108.12
  4. Investigate /tmp directory: sudo ls -la /tmp
  
📧 Email alert sent to: security@example.com
📱 Telegram alert sent to chat_id: 987654321
```

## 🤝 Contribution

Les contributions sont les bienvenues ! Consultez [CONTRIBUTING.md](docs/CONTRIBUTING.md) pour les guidelines.

## 📚 Documentation Complète

- [Installation détaillée](docs/INSTALL.md)
- [Guide d'utilisation](docs/USAGE.md)
- [Exemples JSON](docs/examples/)
- [API Reference](docs/API.md)

## 🐛 Dépannage

### Le script ne s'exécute pas

```bash
# Vérifier les permissions
ls -l /opt/vps-security-toolkit/scripts/

# Rendre exécutable
sudo chmod +x /opt/vps-security-toolkit/scripts/*.sh

# Vérifier l'interpréteur
head -n1 /opt/vps-security-toolkit/scripts/vps-health-check.sh
# Doit afficher: #!/bin/bash
```

### Erreur "command not found"

```bash
# Installer les dépendances manquantes
sudo ./setup.sh

# Vérifier manuellement
command -v bc jq whois sensors mail curl
```

### Les alertes email ne fonctionnent pas

```bash
# Tester la configuration mail
echo "Test" | mail -s "Test" votre@email.com

# Vérifier les logs
sudo tail -f /var/log/mail.log
```

## 📝 Changelog

### Version 1.0.0 (2026-02-14)
- ✨ Première version stable
- ✅ 4 scripts de monitoring complets
- ✅ Support multi-format (Terminal, JSON, HTML)
- ✅ Alertes email et Telegram
- ✅ Documentation complète

## 📄 License

Ce projet est sous licence MIT. Voir [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

**VPS Security Toolkit Team**

## 🙏 Remerciements

- Communauté Ubuntu pour la documentation
- fail2ban pour la détection d'intrusions
- Bootstrap pour les templates HTML

---

⭐ **Si ce projet vous est utile, n'hésitez pas à lui donner une étoile sur GitHub !**

🔒 **Sécurisez vos VPS dès aujourd'hui avec VPS Security Toolkit**
