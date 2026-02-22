#!/bin/bash

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VPS SECURITY TOOLKIT - CONFIGURATION EMAIL RELAY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script: setup-email-relay.sh
# Description: Configuration automatique d'un relay SMTP pour Postfix
# Author: VPS Security Toolkit
# Version: 1.0.0
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonctions d'affichage
print_header() {
    echo -e "${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Vérifier que le script est exécuté en root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

# Fonction de backup de configuration
backup_config() {
    local backup_dir="/etc/postfix/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [[ -f /etc/postfix/main.cf ]]; then
        cp /etc/postfix/main.cf "$backup_dir/"
        print_success "Backup de main.cf créé: $backup_dir/main.cf"
    fi
    
    if [[ -f /etc/postfix/sasl_passwd ]]; then
        cp /etc/postfix/sasl_passwd "$backup_dir/"
    fi
}

# Configuration Gmail
configure_gmail() {
    print_header "🔧 CONFIGURATION GMAIL SMTP"
    
    echo -e "${YELLOW}📧 Configuration Gmail SMTP${NC}"
    echo ""
    echo "Pour utiliser Gmail, vous devez:"
    echo "1. Activer la validation en 2 étapes sur votre compte Google"
    echo "2. Générer un mot de passe d'application:"
    echo "   → https://myaccount.google.com/apppasswords"
    echo ""
    
    read -p "Votre adresse Gmail: " gmail_address
    read -sp "Votre App Password Gmail (sera masqué): " gmail_password
    echo ""
    
    # Créer le fichier SASL
    cat > /etc/postfix/sasl_passwd <<EOF
[smtp.gmail.com]:587 ${gmail_address}:${gmail_password}
EOF
    
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    
    # Configurer Postfix
    postconf -e 'relayhost = [smtp.gmail.com]:587'
    postconf -e 'smtp_sasl_auth_enable = yes'
    postconf -e 'smtp_sasl_security_options = noanonymous'
    postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
    postconf -e 'smtp_tls_security_level = encrypt'
    postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt'
    
    # Configurer l'expéditeur générique
    cat > /etc/postfix/generic <<EOF
root@$(hostname) ${gmail_address}
$(whoami)@$(hostname) ${gmail_address}
@$(hostname) ${gmail_address}
EOF
    
    postconf -e 'smtp_generic_maps = hash:/etc/postfix/generic'
    postmap /etc/postfix/generic
    
    print_success "Gmail SMTP configuré avec succès"
}

# Configuration SendGrid
configure_sendgrid() {
    print_header "🔧 CONFIGURATION SENDGRID SMTP"
    
    echo -e "${YELLOW}📧 Configuration SendGrid SMTP${NC}"
    echo ""
    echo "Pour utiliser SendGrid:"
    echo "1. Créez un compte sur https://signup.sendgrid.com/"
    echo "2. Créez une API Key dans Settings > API Keys"
    echo "3. Donnez-lui les permissions 'Mail Send'"
    echo ""
    
    read -p "Votre email (expéditeur): " sender_email
    read -sp "Votre SendGrid API Key (sera masquée): " sendgrid_key
    echo ""
    
    # Créer le fichier SASL
    cat > /etc/postfix/sasl_passwd <<EOF
[smtp.sendgrid.net]:587 apikey:${sendgrid_key}
EOF
    
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    
    # Configurer Postfix
    postconf -e 'relayhost = [smtp.sendgrid.net]:587'
    postconf -e 'smtp_sasl_auth_enable = yes'
    postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
    postconf -e 'smtp_sasl_security_options = noanonymous'
    postconf -e 'smtp_tls_security_level = encrypt'
    postconf -e 'header_size_limit = 4096000'
    
    # Configurer l'expéditeur générique
    cat > /etc/postfix/generic <<EOF
root@$(hostname) ${sender_email}
$(whoami)@$(hostname) ${sender_email}
@$(hostname) ${sender_email}
EOF
    
    postconf -e 'smtp_generic_maps = hash:/etc/postfix/generic'
    postmap /etc/postfix/generic
    
    print_success "SendGrid SMTP configuré avec succès"
}

# Configuration Mailgun
configure_mailgun() {
    print_header "🔧 CONFIGURATION MAILGUN SMTP"
    
    echo -e "${YELLOW}📧 Configuration Mailgun SMTP${NC}"
    echo ""
    echo "Pour utiliser Mailgun:"
    echo "1. Créez un compte sur https://www.mailgun.com/"
    echo "2. Ajoutez et vérifiez votre domaine"
    echo "3. Récupérez vos credentials SMTP dans Domain Settings"
    echo ""
    
    read -p "Votre domaine Mailgun (ex: mg.example.com): " mailgun_domain
    read -p "Username SMTP (ex: postmaster@mg.example.com): " mailgun_user
    read -sp "Password SMTP (sera masqué): " mailgun_pass
    echo ""
    
    # Créer le fichier SASL
    cat > /etc/postfix/sasl_passwd <<EOF
[smtp.mailgun.org]:587 ${mailgun_user}:${mailgun_pass}
EOF
    
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    
    # Configurer Postfix
    postconf -e 'relayhost = [smtp.mailgun.org]:587'
    postconf -e 'smtp_sasl_auth_enable = yes'
    postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
    postconf -e 'smtp_sasl_security_options = noanonymous'
    postconf -e 'smtp_tls_security_level = encrypt'
    
    # Configurer l'expéditeur
    cat > /etc/postfix/generic <<EOF
root@$(hostname) ${mailgun_user}
$(whoami)@$(hostname) ${mailgun_user}
@$(hostname) ${mailgun_user}
EOF
    
    postconf -e 'smtp_generic_maps = hash:/etc/postfix/generic'
    postmap /etc/postfix/generic
    
    print_success "Mailgun SMTP configuré avec succès"
}

# Configuration Amazon SES
configure_ses() {
    print_header "🔧 CONFIGURATION AMAZON SES"
    
    echo -e "${YELLOW}📧 Configuration Amazon SES SMTP${NC}"
    echo ""
    echo "Pour utiliser Amazon SES:"
    echo "1. Créez des credentials SMTP dans AWS SES Console"
    echo "2. Vérifiez votre adresse email ou domaine"
    echo "3. Sortez du sandbox mode si nécessaire"
    echo ""
    
    read -p "Région AWS (ex: eu-west-1): " aws_region
    read -p "SMTP Username: " ses_user
    read -sp "SMTP Password (sera masqué): " ses_pass
    echo ""
    read -p "Email expéditeur vérifié: " sender_email
    
    # Créer le fichier SASL
    cat > /etc/postfix/sasl_passwd <<EOF
[email-smtp.${aws_region}.amazonaws.com]:587 ${ses_user}:${ses_pass}
EOF
    
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    
    # Configurer Postfix
    postconf -e "relayhost = [email-smtp.${aws_region}.amazonaws.com]:587"
    postconf -e 'smtp_sasl_auth_enable = yes'
    postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
    postconf -e 'smtp_sasl_security_options = noanonymous'
    postconf -e 'smtp_tls_security_level = encrypt'
    
    # Configurer l'expéditeur
    cat > /etc/postfix/generic <<EOF
root@$(hostname) ${sender_email}
$(whoami)@$(hostname) ${sender_email}
@$(hostname) ${sender_email}
EOF
    
    postconf -e 'smtp_generic_maps = hash:/etc/postfix/generic'
    postmap /etc/postfix/generic
    
    print_success "Amazon SES SMTP configuré avec succès"
}

# Installer les dépendances
install_dependencies() {
    print_header "📦 INSTALLATION DES DÉPENDANCES"
    
    apt-get update -qq
    apt-get install -y libsasl2-modules ca-certificates >/dev/null 2>&1
    
    update-ca-certificates >/dev/null 2>&1
    
    print_success "Dépendances installées"
}

# Test de configuration
test_configuration() {
    print_header "🧪 TEST DE CONFIGURATION"
    
    read -p "Adresse email de test (pour recevoir l'email): " test_email
    
    echo -e "${YELLOW}Envoi d'un email de test à ${test_email}...${NC}"
    
    # Redémarrer Postfix
    systemctl restart postfix
    
    # Envoyer un email de test
    echo "Test de configuration Postfix - $(date)" | mail -s "VPS Security Toolkit - Test Email" "$test_email"
    
    sleep 3
    
    # Vérifier les logs
    echo ""
    print_info "Vérification des logs..."
    echo ""
    
    tail -10 /var/log/mail.log | grep -E "status=sent|status=bounced|relay=" || \
    journalctl -u postfix --since "1 minute ago" --no-pager | tail -10
    
    echo ""
    print_info "Vérifiez votre boîte email (et le dossier spam) pour l'email de test"
    
    # Vérifier la queue
    echo ""
    local queue_status=$(mailq | head -1)
    if [[ "$queue_status" =~ "empty" ]]; then
        print_success "Queue Postfix vide (bon signe)"
    else
        print_warning "Il y a des emails en attente dans la queue:"
        mailq
    fi
}

# Menu principal
main_menu() {
    print_header "📧 CONFIGURATION EMAIL RELAY - VPS SECURITY TOOLKIT"
    
    echo -e "${BLUE}Sélectionnez votre fournisseur SMTP:${NC}"
    echo ""
    echo "1) Gmail SMTP         (Recommandé pour tests)"
    echo "2) SendGrid           (Recommandé pour production - 100 emails/jour gratuits)"
    echo "3) Mailgun            (5,000 emails/mois gratuits)"
    echo "4) Amazon SES         (62,000 emails/mois gratuits si EC2)"
    echo "5) Afficher la configuration actuelle"
    echo "6) Tester la configuration"
    echo "7) Restaurer configuration par défaut"
    echo "8) Quitter"
    echo ""
    
    read -p "Votre choix [1-8]: " choice
    
    case $choice in
        1)
            backup_config
            install_dependencies
            configure_gmail
            test_configuration
            ;;
        2)
            backup_config
            install_dependencies
            configure_sendgrid
            test_configuration
            ;;
        3)
            backup_config
            install_dependencies
            configure_mailgun
            test_configuration
            ;;
        4)
            backup_config
            install_dependencies
            configure_ses
            test_configuration
            ;;
        5)
            print_header "📋 CONFIGURATION ACTUELLE"
            postconf -n | grep -E "relay|sasl|tls|generic" | sed 's/^/  /'
            echo ""
            ;;
        6)
            test_configuration
            ;;
        7)
            print_header "♻️  RESTAURATION CONFIGURATION PAR DÉFAUT"
            postconf -e 'relayhost ='
            postconf -e 'smtp_sasl_auth_enable = no'
            postconf -e 'smtp_generic_maps ='
            rm -f /etc/postfix/sasl_passwd* /etc/postfix/generic*
            systemctl restart postfix
            print_success "Configuration restaurée"
            ;;
        8)
            print_info "Au revoir!"
            exit 0
            ;;
        *)
            print_error "Choix invalide"
            exit 1
            ;;
    esac
}

# Exécution
clear
main_menu

print_header "✅ CONFIGURATION TERMINÉE"

echo -e "${GREEN}"
echo "La configuration est maintenant en place."
echo ""
echo "Pour utiliser les alertes email avec VPS Security Toolkit:"
echo ""
echo "  sudo /path/to/vps-security-audit.sh --silent --email votre@email.com"
echo "  sudo /path/to/vps-health-check.sh --silent --email votre@email.com"
echo ""
echo -e "${CYAN}📖 Documentation complète: docs/EMAIL-SETUP.md${NC}"
echo ""
