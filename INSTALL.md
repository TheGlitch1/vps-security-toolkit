# 📦 Guide d'Installation

> Installation complète de VPS Security Toolkit sur Ubuntu

## 📋 Prérequis

### Système d'exploitation
- **Ubuntu 20.04 LTS** (Focal Fossa)
- **Ubuntu 22.04 LTS** (Jammy Jellyfish)  
- **Ubuntu 24.04 LTS** (Noble Numbat) ✅ Recommandé

### Droits d'accès
- Accès **root** ou **sudo**
- Connexion SSH active

### Espace disque
- Minimum : **100 MB** pour les scripts
- Recommandé : **500 MB** pour les logs et rapports

---

## 🚀 Installation Rapide (Recommandée)

### Méthode 1 : Installation automatique

```bash
# Cloner le repository
git clone https://github.com/TheGlitch1/vps-security-toolkit.git
cd vps-security-toolkit

# Lancer l'installation automatique
sudo ./setup.sh
```

Le script d'installation va :
- ✅ Vérifier la compatibilité Ubuntu
- ✅ Installer les dépendances requises
- ✅ Proposer les dépendances optionnelles
- ✅ Créer les répertoires nécessaires
- ✅ Configurer les permissions
- ✅ Copier les fichiers de configuration
- ✅ Proposer la configuration des cron jobs

---

## 🔧 Installation Manuelle

### Étape 1 : Télécharger le projet

```bash
# Via Git
git clone https://github.com/TheGlitch1/vps-security-toolkit.git
cd vps-security-toolkit

# OU via wget
wget https://github.com/TheGlitch1/vps-security-toolkit/archive/refs/heads/master.zip
unzip master.zip
cd vps-security-toolkit-master
```

### Étape 2 : Installer les dépendances

#### Dépendances obligatoires

```bash
sudo apt update
sudo apt install -y bash coreutils grep awk sed
```

#### Dépendances recommandées

```bash
# Pour les calculs et parsing JSON
sudo apt install -y bc jq

# Pour les alertes email
sudo apt install -y mailutils postfix

# Pour la géolocalisation IP
sudo apt install -y whois

# Pour la surveillance température
sudo apt install -y lm-sensors

# Pour Telegram (API REST)
sudo apt install -y curl
```

#### Dépendances de sécurité (optionnelles)

```bash
# Fail2ban pour bannir les attaquants
sudo apt install -y fail2ban

# UFW pour le firewall
sudo apt install -y ufw
```

### Étape 3 : Créer les répertoires

```bash
sudo mkdir -p /var/log/vps-toolkit/{json,html}
sudo chmod 755 /var/log/vps-toolkit
sudo chmod 755 /var/log/vps-toolkit/json
sudo chmod 755 /var/log/vps-toolkit/html
```

### Étape 4 : Copier la configuration

```bash
sudo cp config/vps-toolkit.conf.example /etc/vps-toolkit.conf
sudo chmod 600 /etc/vps-toolkit.conf
sudo nano /etc/vps-toolkit.conf  # Éditer selon vos besoins
```

### Étape 5 : Rendre les scripts exécutables

```bash
chmod +x scripts/*.sh
chmod +x setup.sh
```

### Étape 6 : Tester l'installation

```bash
# Test du health check
sudo ./scripts/vps-health-check.sh

# Test du security audit
sudo ./scripts/vps-security-audit.sh

# Vérifier les sorties JSON
ls -lh /var/log/vps-toolkit/json/
```

---

## ⚙️ Configuration Post-Installation

### Configuration des alertes Email

#### 1. Configurer Postfix

```bash
sudo dpkg-reconfigure postfix
```

Choisir :
- Type : **Internet Site**
- Nom du système : votre hostname (ex: `vmi2983905.contaboserver.net`)

#### 2. Tester l'envoi d'email

```bash
echo "Test email" | mail -s "VPS Test" votre-email@example.com
```

#### 3. Activer dans la configuration

Éditer `/etc/vps-toolkit.conf` :

```bash
ENABLE_EMAIL=true
EMAIL_TO="votre-email@example.com"
EMAIL_FROM="vps-security@$(hostname)"
```

### Configuration des alertes Telegram

#### 1. Créer un bot Telegram

1. Ouvrez Telegram et cherchez **@BotFather**
2. Envoyez `/newbot`
3. Suivez les instructions pour créer votre bot
4. Copiez le **Bot Token** (format: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

#### 2. Récupérer votre Chat ID

1. Démarrez une conversation avec votre bot
2. Envoyez un message (n'importe lequel)
3. Visitez : `https://api.telegram.org/bot<VOTRE_TOKEN>/getUpdates`
4. Cherchez `"chat":{"id":123456789`
5. Notez ce numéro

#### 3. Configurer

Éditer `/etc/vps-toolkit.conf` :

```bash
ENABLE_TELEGRAM=true
TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
TELEGRAM_CHAT_ID="123456789"
```

#### 4. Tester

```bash
sudo ./tests/test-telegram-alert.sh
```

---

## 📅 Configuration des Tâches Automatiques (Cron)

### Installation des cron jobs

```bash
# Méthode automatique
sudo ./setup.sh --setup-cron

# OU méthode manuelle
sudo crontab -e
```

### Exemples de configuration cron

Ajouter dans le crontab :

```cron
# Health Check - Toutes les 5 minutes
*/5 * * * * /chemin/vers/vps-security-toolkit/scripts/vps-health-check.sh > /dev/null 2>&1

# Security Audit - Tous les jours à 2h00
0 2 * * * /chemin/vers/vps-security-toolkit/scripts/vps-security-audit.sh > /dev/null 2>&1

# SSH Analysis - Toutes les heures
0 * * * * /chemin/vers/vps-security-toolkit/scripts/vps-ssh-analysis.sh --period 24h > /dev/null 2>&1

# Intrusion Check - Toutes les 30 minutes
*/30 * * * * /chemin/vers/vps-security-toolkit/scripts/vps-intrusion-check.sh > /dev/null 2>&1

# Nettoyage des vieux logs - Une fois par semaine
0 3 * * 0 find /var/log/vps-toolkit -name "*.json" -mtime +30 -delete
```

**Recommandations :**
- Health Check : **Fréquent** (5-15 min)
- Security Audit : **Quotidien** (1x/jour)
- SSH Analysis : **Régulier** (1-4x/jour)
- Intrusion Check : **Fréquent** (30-60 min)

---

## 🧪 Vérification de l'Installation

### Test complet

```bash
# Test 1: Health Check
sudo ./scripts/vps-health-check.sh --verbose
echo "✓ Health check OK"

# Test 2: Security Audit
sudo ./scripts/vps-security-audit.sh --verbose
echo "✓ Security audit OK"

# Test 3: SSH Analysis
sudo ./scripts/vps-ssh-analysis.sh --period 24h --verbose
echo "✓ SSH analysis OK"

# Test 4: Intrusion Check
sudo ./scripts/vps-intrusion-check.sh --verbose
echo "✓ Intrusion check OK"

# Test 5: Vérifier les sorties JSON
ls -lh /var/log/vps-toolkit/json/*.json && echo "✓ JSON files OK"

# Test 6: Alertes email (optionnel)
sudo ./tests/test-email-alert.sh votre-email@example.com
```

### Vérifier les logs

```bash
# Logs du système
tail -f /var/log/vps-toolkit/*.log

# Rapports JSON
cat /var/log/vps-toolkit/json/health-check_latest.json | jq '.'

# Rapports HTML
firefox /var/log/vps-toolkit/html/health-check_latest.html
```

---

## 🔒 Sécurisation

### Permissions recommandées

```bash
# Configuration (contient des tokens/emails)
sudo chmod 600 /etc/vps-toolkit.conf
sudo chown root:root /etc/vps-toolkit.conf

# Scripts (exécutables root uniquement)
sudo chmod 750 scripts/*.sh
sudo chown root:root scripts/*.sh

# Logs (lecture restreinte)
sudo chmod 750 /var/log/vps-toolkit
sudo chown root:root /var/log/vps-toolkit
```

### Fichiers sensibles à protéger

- `/etc/vps-toolkit.conf` - Contient les tokens Telegram et emails
- `/var/log/vps-toolkit/` - Peut contenir des IPs et informations système
- Scripts - Ne doivent être modifiables que par root

---

## ❌ Désinstallation

```bash
# Supprimer les cron jobs
sudo crontab -e
# Supprimer les lignes vps-security-toolkit

# Supprimer les fichiers
sudo rm -rf /var/log/vps-toolkit
sudo rm /etc/vps-toolkit.conf
cd ~ && rm -rf vps-security-toolkit

# Désinstaller les dépendances (optionnel)
sudo apt remove mailutils postfix jq bc whois lm-sensors
sudo apt autoremove
```

---

## 🆘 Dépannage

### Problème : "Command not found"

```bash
# Vérifier que les scripts sont exécutables
chmod +x scripts/*.sh

# Vérifier le PATH ou utiliser le chemin absolu
/chemin/complet/vers/scripts/vps-health-check.sh
```

### Problème : "Permission denied"

```bash
# Utiliser sudo
sudo ./scripts/vps-health-check.sh
```

### Problème : Emails ne sont pas envoyés

```bash
# Vérifier postfix
sudo systemctl status postfix

# Tester l'envoi direct
echo "Test" | mail -s "Test" votre-email@example.com

# Vérifier les logs
sudo tail -f /var/log/mail.log
```

### Problème : JSON invalide

```bash
# Vérifier avec jq
cat /var/log/vps-toolkit/json/health-check_latest.json | jq '.'

# Si erreur, relancer le script en verbose
sudo ./scripts/vps-health-check.sh --verbose
```

### Problème : Géolocalisation ne fonctionne pas

```bash
# Installer whois
sudo apt install whois

# Tester manuellement
whois 8.8.8.8 | grep -i country
```

---

## 📚 Ressources

- **Documentation** : [README.md](README.md)
- **Guide d'utilisation** : [USAGE.md](USAGE.md)
- **Contribution** : [CONTRIBUTING.md](CONTRIBUTING.md)
- **GitHub** : https://github.com/TheGlitch1/vps-security-toolkit
- **Issues** : https://github.com/TheGlitch1/vps-security-toolkit/issues

---

## 💡 Conseils

1. **Testez** chaque script avant de l'ajouter au cron
2. **Configurez** les seuils d'alerte selon vos besoins
3. **Surveillez** régulièrement les rapports JSON/HTML
4. **Nettoyez** les vieux logs (automatisation recommandée)
5. **Sécurisez** le fichier de configuration avec chmod 600

---

**Installation réussie ?** 🎉 Consultez [USAGE.md](USAGE.md) pour apprendre à utiliser les scripts !
