# VPS Security Toolkit - Tests

Ce dossier contient les scripts de test pour valider les différentes fonctionnalités du toolkit.

## Scripts de Test Disponibles

### 🧪 test-email-alert.sh
Test complet du système d'alertes email.

**Usage:**
```bash
sudo ./tests/test-email-alert.sh
```

**Ce qui est testé:**
- ✅ Fonction `send_email_alert()` de shared-functions.sh
- ✅ Format du template email
- ✅ Envoi via postfix
- ✅ Email avec alerte WARNING simulée

**Prérequis:**
- `mailutils` installé
- `postfix` configuré

---

### 📱 test-telegram-alert.sh
Test du système d'alertes Telegram (nécessite configuration préalable).

**Usage:**
```bash
./tests/test-telegram-alert.sh
```

**Ce qui est testé:**
- ✅ Fonction `send_telegram_alert()` de shared-functions.sh
- ✅ Connexion API Telegram
- ✅ Format Markdown du message
- ✅ Alerte WARNING simulée

**Prérequis:**
1. Créer un bot via @BotFather sur Telegram
2. Récupérer le Bot Token
3. Obtenir votre Chat ID

Le script vous guidera à travers le processus.

---

## Résultats des Tests

### ✅ Tests Email (14 février 2026)

**Status:** Réussi ✅

**Détails:**
- 📧 2 emails envoyés à `xxxxxx@outlook.com`
- ✅ Status: SENT (confirmé par logs postfix)
- 🚀 Relay: outlook-com.olc.protection.outlook.com
- ⏱️ Délai moyen: 2-4 secondes
- 📊 Code DSN: 2.6.0 (succès)

**Logs:**
```
/var/log/mail.log
```

---

### ⏳ Tests Telegram

**Status:** Prêt (non testé - nécessite Bot Token)

---

## Ajouter un Nouveau Test

Pour créer un nouveau script de test:

1. Créer le fichier dans `tests/`
2. Rendre exécutable: `chmod +x tests/votre-test.sh`
3. Sourcer les fonctions partagées:
   ```bash
   source $(dirname "$0")/../scripts/shared-functions.sh
   ```
4. Documenter dans ce README

---

## Tests Futurs à Développer

- [ ] test-health-check-full.sh - Test complet de vps-health-check.sh
- [ ] test-security-audit.sh - Test de vps-security-audit.sh
- [ ] test-ssh-analysis.sh - Test de vps-ssh-analysis.sh avec données simulées
- [ ] test-intrusion-check.sh - Test de vps-intrusion-check.sh
- [ ] test-all.sh - Suite de tests complète

---

**Note:** Les tests utilisent des données simulées pour déclencher des alertes sans impacter le système réel.
