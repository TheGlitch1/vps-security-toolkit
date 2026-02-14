# 📖 Guide d'Utilisation

> Comment utiliser les 4 scripts de VPS Security Toolkit

## 📑 Table des Matières

1. [Vue d'ensemble](#-vue-densemble)
2. [vps-health-check.sh](#-vps-health-checksh)
3. [vps-security-audit.sh](#-vps-security-auditsh)
4. [vps-ssh-analysis.sh](#-vps-ssh-analysissh)
5. [vps-intrusion-check.sh](#-vps-intrusion-checksh)
6. [Configuration](#-configuration)
7. [Sorties et Rapports](#-sorties-et-rapports)
8. [Alertes](#-alertes)
9. [Automatisation](#-automatisation)
10. [Exemples Pratiques](#-exemples-pratiques)

---

## 🎯 Vue d'ensemble

VPS Security Toolkit comprend **4 scripts principaux** :

| Script | Fonction | Fréquence | Alertes |
|--------|----------|-----------|---------|
| `vps-health-check.sh` | Monitoring système | 5-15 min | Oui |
| `vps-security-audit.sh` | Audit de sécurité | Quotidien | Oui (score faible) |
| `vps-ssh-analysis.sh` | Analyse attaques SSH | Horaire | Oui (activité suspecte) |
| `vps-intrusion-check.sh` | Détection d'intrusion | 30-60 min | Oui (critique) |

Chaque script génère **3 types de sorties** :
- 🖥️ **Terminal** : Rapport coloré et formaté
- 📄 **JSON** : Données structurées pour parsing
- 🌐 **HTML** : Dashboard visuel avec graphiques

---

## 🏥 vps-health-check.sh

### Description

Surveillance en temps réel de la santé du système : CPU, RAM, disque, services, réseau, processus.

### Utilisation de base

```bash
# Exécution simple
sudo ./scripts/vps-health-check.sh

# Mode verbeux (affiche les détails)
sudo ./scripts/vps-health-check.sh --verbose

# Mode silencieux (aucune sortie terminal)
sudo ./scripts/vps-health-check.sh --silent
```

### Options disponibles

```bash
-h, --help              # Afficher l'aide
-v, --verbose           # Mode verbeux
-s, --silent            # Mode silencieux
--no-json               # Ne pas générer de JSON
--no-html               # Ne pas générer de HTML
--email EMAIL           # Envoyer alerte si problème
--telegram TOKEN CHAT   # Alerte Telegram
```

### Exemples

```bash
# Monitoring avec alertes email
sudo ./scripts/vps-health-check.sh --email admin@example.com

# Monitoring silencieux (pour cron)
sudo ./scripts/vps-health-check.sh --silent

# Monitoring complet avec toutes les options
sudo ./scripts/vps-health-check.sh \
    --verbose \
    --email admin@example.com \
    --telegram "123456:ABC-DEF" "987654321"
```

### Métriques surveillées

#### Système
- **Uptime** : Durée de fonctionnement
- **Load Average** : Charge système (1m, 5m, 15m)

#### CPU
- **Nombre de cœurs**
- **Utilisation** : Pourcentage d'utilisation
- **Température** : Si lm-sensors installé

#### Mémoire
- **RAM** : Total, utilisé, libre, disponible, pourcentage
- **SWAP** : Total, utilisé, libre, pourcentage

#### Disque
- **Partitions** : Taille, utilisé, disponible, pourcentage
- **Montage** : Points de montage

#### Services
- **SSH** : Statut (actif/inactif)
- **Cron** : Statut
- **Fail2ban** : Statut (si installé)

#### Réseau
- **Connexions établies**
- **Ports en écoute**
- **Connexions TIME_WAIT**

#### Processus
- **Total** : Nombre de processus
- **Zombies** : Processus zombies détectés
- **Running** : Processus en cours d'exécution

### Seuils d'alerte

Par défaut (modifiable dans `/etc/vps-toolkit.conf`) :

```bash
CPU_WARNING=80          # 80% CPU = WARNING
CPU_CRITICAL=90         # 90% CPU = CRITICAL
RAM_WARNING=80          # 80% RAM = WARNING
RAM_CRITICAL=90         # 90% RAM = CRITICAL
DISK_WARNING=80         # 80% disque = WARNING
DISK_CRITICAL=90        # 90% disque = CRITICAL
```

### Sortie exemple

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏥 VPS Health Check Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▶ 💻 CPU
─────────────────────────────────────────────────────
  ℹ️ CPU Cores                           6
  ✅ CPU Usage                           2%
  [██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]   2%

▶ 🧠 Memory
─────────────────────────────────────────────────────
  ℹ️ RAM Total                           11 GB
  ✅ RAM Usage                           17%
  [████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  17%
```

---

## 🔒 vps-security-audit.sh

### Description

Audit complet de la sécurité du serveur avec système de scoring (0-100).

### Utilisation de base

```bash
# Audit simple
sudo ./scripts/vps-security-audit.sh

# Audit verbeux
sudo ./scripts/vps-security-audit.sh --verbose
```

### Options disponibles

```bash
-h, --help              # Afficher l'aide
-v, --verbose           # Mode verbeux
-s, --silent            # Mode silencieux
--no-json               # Ne pas générer de JSON
--no-html               # Ne pas générer de HTML
--email EMAIL           # Alerte si score < seuil
--telegram TOKEN CHAT   # Alerte Telegram
```

### Audits effectués

#### 1. Configuration SSH (/100 points)
- **PermitRootLogin** : Doit être "no" (20 pts)
- **PasswordAuthentication** : Doit être "no" (15 pts)
- **PubkeyAuthentication** : Doit être "yes" (10 pts)
- **PermitEmptyPasswords** : Doit être "no" (10 pts)
- **X11Forwarding** : Doit être "no" (10 pts)
- **MaxAuthTries** : ≤ 3 (10 pts)
- **Port SSH** : != 22 (15 pts)
- **ClientAliveInterval** : 1-300 (10 pts)

#### 2. Fail2ban (/100 points)
- Installé : 30 pts
- Actif : 40 pts
- Jails actives : 20 pts
- Configuration custom : 10 pts

#### 3. Firewall (/100 points)
- UFW installé : 20 pts
- UFW actif : 50 pts
- Règles configurées : 20 pts
- Iptables rules : 10 pts

#### 4. Mises à jour (/100 points)
- Score = 100 - (nombre_updates_sécu * 5)
- Pénalité si reboot requis : -20 pts

#### 5. Utilisateurs (/100 points)
- Aucun compte UID 0 suspect : 100 pts
- Comptes UID 0 détectés : 0 pts (CRITIQUE)

### Score final

Le score final est la **moyenne des 5 audits**.

**Interprétation :**
- **≥ 85** : Excellent 🟢
- **70-84** : Bon 🟡
- **50-69** : Warning ⚠️
- **< 50** : Critical 🔴

### Exemple de sortie

```
▶ 🎯 Score de Sécurité
─────────────────────────────────────────────────────
  53/100
  Statut: WARNING
  [██████████████████████████░░░░░░░░░░░░░░░░░░░░░░]  53%

▶ 🔑 Configuration SSH
─────────────────────────────────────────────────────
  ❌ PermitRootLogin                     yes (attendu: no|prohibit-password)
  ⚠️ PasswordAuthentication              yes (attendu: no)
  ✅ PubkeyAuthentication                yes (attendu: yes)
```

---

## 🔍 vps-ssh-analysis.sh

### Description

Analyse approfondie des tentatives d'intrusion SSH avec géolocalisation et détection de patterns d'attaque.

### Utilisation de base

```bash
# Analyse dernières 24h
sudo ./scripts/vps-ssh-analysis.sh

# Analyse 7 derniers jours
sudo ./scripts/vps-ssh-analysis.sh --period 7d

# Analyse complète (all-time)
sudo ./scripts/vps-ssh-analysis.sh --period all
```

### Options disponibles

```bash
-h, --help              # Afficher l'aide
-v, --verbose           # Mode verbeux
-s, --silent            # Mode silencieux
--period PERIOD         # Période: 24h, 7d, 30d, all
--top N                 # Nombre d'IPs dans le top (défaut: 20)
--no-geo                # Désactiver géolocalisation
--no-json               # Ne pas générer de JSON
--no-html               # Ne pas générer de HTML
--email EMAIL           # Alerte si activité suspecte
--telegram TOKEN CHAT   # Alerte Telegram
```

### Périodes disponibles

- **24h** : Dernières 24 heures (par défaut)
- **7d** : 7 derniers jours
- **30d** : 30 derniers jours
- **all** : Tous les logs (limité à 100k lignes)

### Analyses effectuées

#### Tentatives échouées
- Total des échecs
- Utilisateurs invalides
- Attaques root
- IPs uniques

#### Top Attackers
- **Top 20** (ou personnalisé) IPs
- **Géolocalisation** : Pays, ville, ISP
- **Statut fail2ban** : Banni ou non

#### Patterns d'attaque
- **Brute force** : Même IP, nombreuses tentatives
- **Port scans** : Connexions multiples courtes
- **Dictionary attacks** : Utilisateurs invalides variés
- **Root attacks** : Tentatives sur root

#### Connexions réussies
- Logins par mot de passe
- Logins par clé SSH
- IPs des connexions réussies

### Exemple d'utilisation

```bash
# Analyse rapide 24h
sudo ./scripts/vps-ssh-analysis.sh

# Analyse hebdomadaire avec top 50
sudo ./scripts/vps-ssh-analysis.sh --period 7d --top 50

# Analyse sans géolocalisation (plus rapide)
sudo ./scripts/vps-ssh-analysis.sh --period 24h --no-geo

# Analyse avec alerte email
sudo ./scripts/vps-ssh-analysis.sh \
    --period 24h \
    --email security@example.com
```

### Sortie exemple

```
▶ 🌍 Top 10 IPs Attaquantes
─────────────────────────────────────────────────────
  # | IP Address      | Tentatives | Pays  | Banni
  ─────────────────────────────────────────────────────────────
   1 | 134.199.200.147 |       5825 | US    | ❌
   2 | 186.96.145.241  |       4112 | MX    | ❌
   3 | 167.99.150.0    |       3382 | US    | ❌

▶ 🎯 Patterns d'Attaque Détectés
─────────────────────────────────────────────────────
  ⚠️ Brute force (sources)               116
  ⚠️ Port scans (sources)                88
  ℹ️ Dictionary attack (users)           3012
  ⚠️ Root attacks (sources)              128
```

### Seuils d'alerte

```bash
ALERT_FAILED_ATTEMPTS=100    # Alerte si > 100 échecs/24h
ALERT_UNIQUE_IPS=50          # Alerte si > 50 IPs uniques/24h
```

---

## 🚨 vps-intrusion-check.sh

### Description

Détection d'intrusion et vérification d'intégrité système.

### Utilisation de base

```bash
# Check standard
sudo ./scripts/vps-intrusion-check.sh

# Check sur 48h
sudo ./scripts/vps-intrusion-check.sh --hours 48
```

### Options disponibles

```bash
-h, --help              # Afficher l'aide
-v, --verbose           # Mode verbeux
-s, --silent            # Mode silencieux
--hours HOURS           # Période de vérification (défaut: 24h)
--no-json               # Ne pas générer de JSON
--no-html               # Ne pas générer de HTML
--email EMAIL           # Alerte si intrusion détectée
--telegram TOKEN CHAT   # Alerte Telegram
```

### Vérifications effectuées

#### 1. Sessions SSH actives
- Nombre de sessions
- Sessions root (SUSPECT)
- IPs de connexion

#### 2. Processus suspects
- **Miners** : xmrig, minerd, cgminer, ethminer
- **Backdoors** : Noms suspects
- **High-CPU** : Processus > 80% CPU

#### 3. Ports ouverts
- Ports en écoute
- Ports non-standard détectés
- Ports suspects (4444, 5555, 6666, etc.)

#### 4. Fichiers SUID
- Fichiers avec bit SUID
- **CRITIQUE** : SUID dans /tmp, /var/tmp
- Fichiers SUID non connus

#### 5. Modifications système
- Fichiers critiques modifiés (période configurable)
- `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`
- `/etc/ssh/sshd_config`, `/etc/crontab`
- Nouveaux utilisateurs créés

#### 6. Connexions réseau
- Connexions externes actives
- Ports suspects (backdoor/C2)

#### 7. Fichiers cachés
- Fichiers cachés dans `/tmp`
- Fichiers cachés dans `/var/tmp`
- Fichiers cachés dans `/dev/shm`

### Niveaux de sévérité

- **OK** : Aucun problème détecté ✅
- **SUSPICIOUS** : Éléments suspects mais pas critiques ⚠️
- **WARNING** : Avertissements à surveiller 🟡
- **CRITICAL** : Intrusion probable, action immédiate requise 🔴

### Exemple de sortie

```
▶ 🎯 Statut Global
─────────────────────────────────────────────────────
  ✅ OK
  Issues critiques: 0 | Avertissements: 0 | Suspects: 0

▶ ⚙️  Processus Suspects
─────────────────────────────────────────────────────
  ✅ Processus détectés                  0

▶ 🔐 Fichiers SUID
─────────────────────────────────────────────────────
  ℹ️ Fichiers SUID                       10
  ✅ SUID suspects                       0
```

---

## ⚙️ Configuration

### Fichier de configuration principal

Emplacement : `/etc/vps-toolkit.conf`

```bash
# Éditer la configuration
sudo nano /etc/vps-toolkit.conf
```

### Paramètres importants

```bash
# === Chemins ===
LOG_DIR="/var/log/vps-toolkit"
JSON_DIR="$LOG_DIR/json"
HTML_DIR="$LOG_DIR/html"

# === Seuils d'alerte ===
CPU_WARNING=80
CPU_CRITICAL=90
RAM_WARNING=80
RAM_CRITICAL=90
DISK_WARNING=80
DISK_CRITICAL=90

# === Alertes Email ===
ENABLE_EMAIL=false
EMAIL_TO="admin@example.com"
EMAIL_FROM="vps-security@$(hostname)"

# === Alertes Telegram ===
ENABLE_TELEGRAM=false
TELEGRAM_BOT_TOKEN="123456:ABC-DEF"
TELEGRAM_CHAT_ID="987654321"

# === Options ===
AUTO_CLEANUP=true           # Nettoyage auto des vieux logs
CLEANUP_DAYS=30             # Garder 30 jours
ENABLE_GEOLOCATION=true     # Géolocalisation IPs
VERBOSITY="normal"          # normal, verbose, silent
```

---

## 📊 Sorties et Rapports

### Terminal

Rapport coloré et formaté directement dans le terminal.

```bash
# Afficher un rapport
sudo ./scripts/vps-health-check.sh
```

### JSON

Données structurées pour parsing automatique.

**Emplacement :**
- `/var/log/vps-toolkit/json/health-check_YYYY-MM-DD_HH-MM-SS.json`
- `/var/log/vps-toolkit/json/health-check_latest.json` (lien symbolique)

**Utilisation :**

```bash
# Lire avec jq
cat /var/log/vps-toolkit/json/health-check_latest.json | jq '.'

# Extraire le status
cat /var/log/vps-toolkit/json/health-check_latest.json | jq '.summary.status'

# Extraire l'utilisation CPU
cat /var/log/vps-toolkit/json/health-check_latest.json | jq '.data.cpu.usage'
```

### HTML

Dashboard visuel avec graphiques (Bootstrap 5 + Chart.js).

**Emplacement :**
- `/var/log/vps-toolkit/html/health-check_YYYY-MM-DD_HH-MM-SS.html`
- `/var/log/vps-toolkit/html/health-check_latest.html` (lien symbolique)

**Visualisation :**

```bash
# Ouvrir dans le navigateur
firefox /var/log/vps-toolkit/html/health-check_latest.html

# Ou via serveur web
# Copier dans /var/www/html si Apache/Nginx configuré
```

---

## 🔔 Alertes

### Conditions d'alerte

| Script | Condition d'alerte |
|--------|-------------------|
| health-check | Status WARNING ou CRITICAL |
| security-audit | Score < 70/100 |
| ssh-analysis | > 100 tentatives ou > 50 IPs/24h |
| intrusion-check | Status CRITICAL |

### Format des alertes

#### Email

```
Sujet: [VPS Security] WARNING - Health Check

Corps:
🏥 ALERTE HEALTH CHECK - server.example.com

⚠️ Statut: WARNING
🔴 Problèmes critiques: 0
🟡 Avertissements: 2

💻 CPU: 85% (Seuil: 80%)
🧠 RAM: 88% (Seuil: 80%)

Consultez le rapport complet:
JSON: /var/log/vps-toolkit/json/health-check_latest.json
```

#### Telegram

```
🛡️ VPS SECURITY ALERT

📡 Server: server.example.com
⚠️ Status: WARNING

💻 CPU: 85% (Seuil: 80%)
🧠 RAM: 88% (Seuil: 80%)

🕐 2026-02-14 15:30:45
```

---

## ⏰ Automatisation

### Configuration cron recommandée

```bash
sudo crontab -e
```

Ajouter :

```cron
# Health Check - Toutes les 5 minutes
*/5 * * * * /path/to/vps-security-toolkit/scripts/vps-health-check.sh --silent 2>&1 | logger -t vps-health

# Security Audit - Quotidien à 2h
0 2 * * * /path/to/vps-security-toolkit/scripts/vps-security-audit.sh --silent 2>&1 | logger -t vps-security

# SSH Analysis - Toutes les 6h
0 */6 * * * /path/to/vps-security-toolkit/scripts/vps-ssh-analysis.sh --period 24h --silent 2>&1 | logger -t vps-ssh

# Intrusion Check - Toutes les 30 min
*/30 * * * * /path/to/vps-security-toolkit/scripts/vps-intrusion-check.sh --silent 2>&1 | logger -t vps-intrusion

# Nettoyage hebdomadaire
0 3 * * 0 find /var/log/vps-toolkit -name "*.json" -mtime +30 -delete
0 3 * * 0 find /var/log/vps-toolkit -name "*.html" -mtime +30 -delete
```

---

## 💡 Exemples Pratiques

### Scénario 1 : Monitoring quotidien simple

```bash
# Matin : Check rapide
sudo ./scripts/vps-health-check.sh
sudo ./scripts/vps-security-audit.sh

# Analyser les attaques de la nuit
sudo ./scripts/vps-ssh-analysis.sh --period 24h
```

### Scénario 2 : Détection intrusion après activité suspecte

```bash
# Check complet
sudo ./scripts/vps-intrusion-check.sh --verbose

# Si problème détecté, analyser SSH
sudo ./scripts/vps-ssh-analysis.sh --period 24h --verbose

# Vérifier les connexions récentes
sudo last -20
sudo lastb -20  # Failed logins
```

### Scénario 3 : Audit de sécurité complet

```bash
# 1. Security audit
sudo ./scripts/vps-security-audit.sh --verbose

# 2. Analyser historique SSH (7 jours)
sudo ./scripts/vps-ssh-analysis.sh --period 7d --top 50

# 3. Check intrusion
sudo ./scripts/vps-intrusion-check.sh --verbose

# 4. Exporter les rapports
mkdir ~/security-audit-$(date +%Y%m%d)
cp /var/log/vps-toolkit/json/*_latest.json ~/security-audit-$(date +%Y%m%d)/
cp /var/log/vps-toolkit/html/*_latest.html ~/security-audit-$(date +%Y%m%d)/
```

### Scénario 4 : Surveillance continue avec alertes

```bash
# Configurer les alertes dans /etc/vps-toolkit.conf
sudo nano /etc/vps-toolkit.conf

# Activer:
ENABLE_EMAIL=true
EMAIL_TO="admin@example.com"

# Setup cron pour monitoring continu
sudo crontab -e
# Ajouter les jobs recommandés

# Tester les alertes
sudo ./tests/test-email-alert.sh admin@example.com
```

---

## 📚 Ressources Additionnelles

- **Installation** : [INSTALL.md](INSTALL.md)
- **Contribution** : [CONTRIBUTING.md](CONTRIBUTING.md)
- **GitHub** : https://github.com/TheGlitch1/vps-security-toolkit

---

**Besoin d'aide ?** Ouvrez une [issue sur GitHub](https://github.com/TheGlitch1/vps-security-toolkit/issues) ! 🆘
