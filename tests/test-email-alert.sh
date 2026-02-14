#!/bin/bash

# Script de test pour les alertes email
# Usage: ./test-email-alert.sh YOUR_EMAIL@example.com

# Vérifier que l'email est fourni
if [ -z "$1" ]; then
    echo "❌ Erreur: Veuillez fournir une adresse email"
    echo "Usage: sudo $0 YOUR_EMAIL@example.com"
    exit 1
fi

EMAIL_ADDRESS="$1"

cd /home/theglitch/tools/vps-security-toolkit

# Modifier temporairement le script pour forcer un WARNING
cat > /tmp/test-alert.json <<EOF
{
  "metadata": {
    "script": "vps-health-check",
    "version": "1.0.0",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "hostname": "$(hostname)",
    "duration_seconds": 3
  },
  "summary": {
    "status": "WARNING",
    "critical_issues": 0,
    "warnings": 2,
    "info": 0
  },
  "data": {
    "uptime": {"days":21,"hours":14,"minutes":20,"load_1":0.50,"load_5":0.45,"load_15":0.40},
    "cpu": {"count":6,"usage":85,"temperature":"N/A"},
    "memory": {"ram":{"total":11960,"used":10500,"free":1460,"available":1500,"percent":88},"swap":{"total":0,"used":0,"free":0,"percent":0}},
    "disks": [{"filesystem":"/dev/sda1","size":"387G","used":"350G","available":"37G","percent":90,"mountpoint":"/"}],
    "services": [{"name":"sshd","status":"active","active":true},{"name":"cron","status":"active","active":true},{"name":"fail2ban","status":"not_installed","active":false}],
    "network": {"established":10,"listening":16,"time_wait":0},
    "processes": {"total":189,"zombies":0,"running":2},
    "last_update": "2026-02-14 13:36:58"
  },
  "alerts": [
    {
      "level": "warning",
      "category": "cpu",
      "message": "CPU usage high",
      "value": 85,
      "threshold": 80
    },
    {
      "level": "warning",
      "category": "ram",
      "message": "RAM usage high",
      "value": 88,
      "threshold": 80
    }
  ]
}
EOF

echo "JSON de test créé avec WARNING (CPU 85%, RAM 88%)"

# Test direct de la fonction send_email_alert
cat > /tmp/test-email.sh <<'SCRIPT'
#!/bin/bash

# Charger les fonctions
source /home/theglitch/tools/vps-security-toolkit/scripts/shared-functions.sh

# Configuration
ENABLE_EMAIL=true
EMAIL_TO="$EMAIL_ADDRESS"
VERSION="1.0.0"
SCRIPT_NAME="vps-health-check-TEST"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Message d'alerte
ALERT_MESSAGE="🚨 ALERTE DE TEST - VPS Security Toolkit

⚠️ Statut: WARNING
🔴 Problèmes critiques: 0
🟡 Avertissements: 2

Détails:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💻 CPU: 85% (Seuil: 80%)
   ⚠️ Utilisation CPU élevée

🧠 RAM: 88% (Seuil: 80%)
   ⚠️ Utilisation mémoire élevée

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ceci est un TEST du système d'alerte email.
Le système fonctionne correctement.

📊 Rapport complet:
   JSON: /var/log/vps-toolkit/json/health-check_latest.json
   HTML: /var/log/vps-toolkit/html/health-check_latest.html
"

# Envoyer l'email
send_email_alert "WARNING - Test d'alerte" "$ALERT_MESSAGE"

if [ $? -eq 0 ]; then
    echo "✅ Email d'alerte envoyé avec succès à $EMAIL_ADDRESS"
else
    echo "❌ Échec de l'envoi de l'email"
fi
SCRIPT

chmod +x /tmp/test-email.sh
sudo /tmp/test-email.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 Email de test envoyé à: $EMAIL_ADDRESS"
echo "📫 Vérifiez votre boîte email (et le dossier spam)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
