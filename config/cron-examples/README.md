# 📚 Exemples Cron - VPS Security Toolkit

Ce répertoire contient des exemples de configuration cron pour automatiser l'exécution des scripts de monitoring et sécurité.

## 📁 Fichiers Disponibles

### `crontab-examples.txt`
Fichier complet avec **tous les exemples** possibles :
- Configurations minimale, équilibrée, intensive, légère
- Exemples spécifiques pour chaque script
- Configurations par profil de serveur (web, DB, dev, backup)
- Notes et explications détaillées

**Utilisation :** Consultez ce fichier pour trouver l'exemple qui correspond à vos besoins, puis copiez les lignes appropriées dans votre crontab.

### `production.cron`
Configuration **recommandée pour production** :
- Health Check toutes les 5 minutes
- Security Audit quotidien avec alerte email
- SSH Analysis toutes les 6 heures
- Intrusion Check toutes les 30 minutes
- Nettoyage automatique hebdomadaire

**Utilisation :** Idéal pour la majorité des serveurs en production.

### `critical.cron`
Configuration **intensive pour serveurs critiques** :
- Health Check toutes les 2 minutes
- Security Audit 2 fois par jour
- SSH Analysis toutes les 3 heures
- Intrusion Check toutes les 15 minutes
- Alertes Telegram et email
- Archivage mensuel automatique

**Utilisation :** Pour serveurs haute disponibilité, serveurs exposés, ou environnements sensibles.

### `lightweight.cron`
Configuration **légère pour VPS limités** :
- Health Check toutes les 30 minutes
- Security Audit quotidien
- SSH Analysis quotidien (sans géolocalisation)
- Intrusion Check 3 fois par jour
- Rétention logs réduite (15 jours)

**Utilisation :** Pour VPS à ressources limitées (RAM < 2GB, CPU < 2 cores).

---

## 🚀 Installation Rapide

### Méthode 1 : Crontab utilisateur root

```bash
# Éditer le crontab root
sudo crontab -e

# Copier les lignes du fichier choisi (par exemple production.cron)
# Modifier les chemins et emails
# Sauvegarder et quitter
```

### Méthode 2 : Fichier système cron.d (Recommandée)

```bash
# Copier le fichier cron dans /etc/cron.d/
sudo cp production.cron /etc/cron.d/vps-security-toolkit

# Éditer pour personnaliser les chemins et emails
sudo nano /etc/cron.d/vps-security-toolkit

# Redémarrer cron
sudo systemctl restart cron
```

---

## ⚙️ Personnalisation

### Variables à modifier

Dans chaque fichier `.cron`, modifiez ces variables :

```bash
VPS_TOOLKIT_PATH=/path/to/vps-security-toolkit  # ← Chemin réel du projet
ADMIN_EMAIL=admin@example.com                    # ← Votre email
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...             # ← Token Telegram (optionnel)
TELEGRAM_CHAT_ID=987654321                       # ← Chat ID Telegram (optionnel)
```

### Ajuster les fréquences

Syntaxe cron : `minute heure jour mois jour_semaine commande`

**Exemples :**
- `*/5 * * * *` - Toutes les 5 minutes
- `0 * * * *` - Toutes les heures à :00
- `0 */6 * * *` - Toutes les 6 heures
- `0 2 * * *` - Tous les jours à 2h00
- `0 3 * * 0` - Tous les dimanches à 3h00

---

## 🧪 Test des Cron Jobs

### Tester manuellement

Avant d'activer les cron jobs, testez les commandes :

```bash
# Test Health Check
sudo /path/to/vps-security-toolkit/scripts/vps-health-check.sh --silent

# Test Security Audit avec email
sudo /path/to/vps-security-toolkit/scripts/vps-security-audit.sh --silent --email votre@email.com

# Vérifier que les outputs sont créés
ls -lh /var/log/vps-toolkit/json/
```

### Vérifier l'exécution des crons

```bash
# Voir les cron jobs actifs
sudo crontab -l

# OU si installé dans /etc/cron.d/
cat /etc/cron.d/vps-security-toolkit

# Vérifier les logs d'exécution
sudo grep -i cron /var/log/syslog
sudo grep -i vps /var/log/syslog | tail -20
```

### Debug

Si les cron jobs ne s'exécutent pas :

```bash
# Vérifier que cron est actif
sudo systemctl status cron

# Vérifier les permissions
ls -la /etc/cron.d/vps-security-toolkit
# Doit être : -rw-r--r-- root root

# Vérifier les chemins dans le fichier cron
which bash  # /bin/bash
which logger  # /usr/bin/logger

# Tester la commande complète
sudo -u root /path/to/vps-security-toolkit/scripts/vps-health-check.sh --silent
```

---

## 📊 Recommandations par Type de Serveur

### Serveur Web Public
```
Health Check: */5 (toutes les 5 min)
Security Audit: 0 2 * * * (quotidien)
SSH Analysis: 0 */4 * * * (toutes les 4h)
Intrusion Check: */15 (toutes les 15 min)
```

### Serveur Base de Données
```
Health Check: */10 (toutes les 10 min)
Security Audit: 0 2 * * * (quotidien)
SSH Analysis: 0 */6 * * * (toutes les 6h)
Intrusion Check: */30 (toutes les 30 min)
```

### Serveur Dev/Test
```
Health Check: 0 * * * * (toutes les heures)
Security Audit: 0 2 * * * (quotidien)
SSH Analysis: 0 3 * * * (quotidien)
Intrusion Check: 0 6,18 * * * (2x par jour)
```

### Serveur Backup
```
Health Check: 0 */6 * * * (toutes les 6h)
Security Audit: 0 2 * * * (quotidien)
SSH Analysis: 0 3 * * * (quotidien)
Intrusion Check: 0 2 * * * (quotidien)
```

---

## 🔔 Configuration des Alertes

### Alertes Email uniquement

```cron
*/5 * * * * root /path/to/scripts/vps-health-check.sh --silent --email admin@example.com
```

### Alertes Telegram uniquement

```cron
*/5 * * * * root /path/to/scripts/vps-health-check.sh --silent --telegram "TOKEN" "CHAT_ID"
```

### Alertes multiples (Email + Telegram)

```cron
*/5 * * * * root /path/to/scripts/vps-health-check.sh --silent --email admin@example.com --telegram "TOKEN" "CHAT_ID"
```

### Alertes conditionnelles

```cron
# Alerte seulement en cas d'erreur
*/5 * * * * root /path/to/scripts/vps-health-check.sh --silent || echo "Health check failed" | mail -s "ALERT" admin@example.com
```

---

## 🧹 Gestion des Logs

### Nettoyage automatique

```cron
# Supprimer les fichiers de plus de 30 jours
0 3 * * 0 root find /var/log/vps-toolkit/json -name "*.json" -mtime +30 -delete

# Supprimer les fichiers de plus de 15 jours
0 3 * * 0 root find /var/log/vps-toolkit/html -name "*.html" -mtime +15 -delete
```

### Compression

```cron
# Compresser les fichiers de plus de 7 jours
0 4 * * 0 root find /var/log/vps-toolkit -name "*.json" -mtime +7 -exec gzip {} \;
```

### Archivage

```cron
# Archiver tous les logs le 1er du mois
0 5 1 * * root tar -czf /backup/vps-toolkit-$(date +\%Y-\%m).tar.gz /var/log/vps-toolkit/
```

---

## 💡 Conseils

1. **Commencez léger** : Utilisez `lightweight.cron` puis augmentez selon les besoins
2. **Testez d'abord** : Exécutez manuellement avant d'automatiser
3. **Surveillez** : Vérifiez les logs pendant les premiers jours
4. **Ajustez** : Adaptez les fréquences selon vos ressources
5. **Nettoyez** : Configurez le nettoyage automatique des vieux logs
6. **Sauvegardez** : Archivez régulièrement les rapports importants

---

## 📞 Support

Questions ? Consultez :
- [INSTALL.md](../../INSTALL.md) - Guide d'installation
- [USAGE.md](../../USAGE.md) - Guide d'utilisation
- [GitHub Issues](https://github.com/TheGlitch1/vps-security-toolkit/issues)

---

**Bon monitoring !** 🚀
