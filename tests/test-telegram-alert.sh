#!/bin/bash

# Script de test pour Telegram Alert
# Pour utiliser ce script, vous devez d'abord créer un bot Telegram

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Configuration Telegram Bot - Guide Rapide"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ÉTAPE 1: Créer un bot Telegram"
echo "  1. Ouvrez Telegram et recherchez @BotFather"
echo "  2. Envoyez la commande: /newbot"
echo "  3. Donnez un nom à votre bot (ex: VPS Security Monitor)"
echo "  4. Donnez un username (doit finir par 'bot', ex: vps_security_bot)"
echo "  5. BotFather vous donnera un TOKEN"
echo ""
echo "ÉTAPE 2: Récupérer votre Chat ID"
echo "  1. Démarrez une conversation avec votre bot"
echo "  2. Envoyez un message (n'importe lequel)"
echo "  3. Visitez: https://api.telegram.org/bot<VOTRE_TOKEN>/getUpdates"
echo "  4. Cherchez \"chat\":{\"id\":123456789"
echo "  5. Notez ce numéro (c'est votre CHAT_ID)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Demander les credentials
read -p "Avez-vous un Bot Token Telegram? (y/N): " has_token

if [[ "$has_token" =~ ^[Yy]$ ]]; then
    read -p "Entrez votre Bot Token: " bot_token
    read -p "Entrez votre Chat ID: " chat_id
    
    if [[ -n "$bot_token" && -n "$chat_id" ]]; then
        echo ""
        echo "Test d'envoi d'un message Telegram..."
        
        # Charger les fonctions
        source /home/theglitch/tools/vps-security-toolkit/scripts/shared-functions.sh
        
        # Configuration
        ENABLE_TELEGRAM=true
        TELEGRAM_BOT_TOKEN="$bot_token"
        TELEGRAM_CHAT_ID="$chat_id"
        VERSION="1.0.0"
        SCRIPT_NAME="vps-health-check-TEST"
        TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        
        # Message de test
        TEST_MESSAGE="🛡️ *VPS SECURITY TOOLKIT TEST*

📡 Server: \`$(hostname)\`
🔧 Script: \`vps-health-check\`
📅 Time: \`$(date)\`

━━━━━━━━━━━━━━━━━━━

🚨 *ALERTE DE TEST*

⚠️ Statut: *WARNING*
🔴 Problèmes critiques: 0
🟡 Avertissements: 2

💻 CPU: 85% (Seuil: 80%)
🧠 RAM: 88% (Seuil: 80%)

━━━━━━━━━━━━━━━━━━━

✅ Le système d'alerte Telegram fonctionne !

_VPS Security Toolkit v1.0.0_"
        
        # Envoyer via la fonction
        send_telegram_alert "$TEST_MESSAGE"
        
        if [ $? -eq 0 ]; then
            echo "✅ Message Telegram envoyé avec succès !"
            echo "📱 Vérifiez votre application Telegram"
        else
            echo "❌ Échec de l'envoi du message Telegram"
            echo "Vérifiez:"
            echo "  - Le token est correct"
            echo "  - Le chat ID est correct"
            echo "  - Vous avez démarré une conversation avec le bot"
        fi
    fi
else
    echo ""
    echo "Pour tester Telegram plus tard, suivez les étapes ci-dessus"
    echo "puis exécutez:"
    echo ""
    echo "  sudo ./scripts/vps-health-check.sh \\"
    echo "    --telegram \"VOTRE_BOT_TOKEN\" \"VOTRE_CHAT_ID\""
    echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
