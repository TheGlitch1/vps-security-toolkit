#!/bin/bash

# Script: setup.sh
# Description: Installation et configuration de VPS Security Toolkit
# Auteur: VPS Security Toolkit
# Version: 1.0.0
# Compatibilité: Ubuntu 20.04, 22.04, 24.04

set -e  # Exit on error

# ============================================================================
# COULEURS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# VARIABLES
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "1.0.0")

# Répertoires
LOG_DIR="/var/log/vps-toolkit"
CONFIG_DIR="/etc"
INSTALL_DIR="/opt/vps-security-toolkit"

# Options
INSTALL_OPTIONAL_DEPS=false
SETUP_CRON=false
DRY_RUN=false

# ============================================================================
# FONCTIONS
# ============================================================================

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}🛡️  VPS Security Toolkit - Installation${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Version: ${VERSION}${NC}"
    echo
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

log_step() {
    echo -e "\n${CYAN}▶${NC} ${BOLD}$1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root ou avec sudo"
        exit 1
    fi
}

check_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            log_success "Système détecté: Ubuntu ${VERSION_ID}"
            return 0
        fi
    fi
    log_warning "Ce script est optimisé pour Ubuntu. D'autres distributions peuvent ne pas être entièrement supportées."
    read -p "Continuer quand même? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
}

# ============================================================================
# VÉRIFICATION DES DÉPENDANCES
# ============================================================================

check_dependencies() {
    log_step "Vérification des dépendances..."
    
    local required_deps=("bash" "grep" "awk" "sed" "ps" "uptime" "free" "df")
    local optional_deps=("bc" "jq" "whois" "sensors" "mail" "curl" "fail2ban-client" "ufw")
    local missing_required=()
    local missing_optional=()
    
    # Vérifier les dépendances obligatoires
    for cmd in "${required_deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_required+=("$cmd")
            log_error "Dépendance obligatoire manquante: $cmd"
        else
            log_success "$cmd installé"
        fi
    done
    
    # Vérifier les dépendances optionnelles
    for cmd in "${optional_deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_optional+=("$cmd")
            log_warning "Dépendance optionnelle manquante: $cmd"
        else
            log_success "$cmd installé"
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_error "Dépendances obligatoires manquantes. Installation impossible."
        exit 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        echo
        log_warning "Certaines fonctionnalités ne seront pas disponibles sans les dépendances optionnelles."
        
        if [[ "$INSTALL_OPTIONAL_DEPS" == "true" ]]; then
            install_optional_dependencies
        else
            read -p "Voulez-vous installer les dépendances optionnelles? (Y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
                install_optional_dependencies
            fi
        fi
    fi
}

install_optional_dependencies() {
    log_step "Installation des dépendances optionnelles..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] apt update && apt install -y bc jq whois lm-sensors mailutils curl fail2ban ufw"
        return
    fi
    
    apt update
    
    # Installer les paquets optionnels
    local packages=(
        "bc"           # Calculs mathématiques
        "jq"           # Parsing JSON
        "whois"        # Géolocalisation IP
        "lm-sensors"   # Température CPU
        "mailutils"    # Alertes email
        "curl"         # Alertes Telegram
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installation de $package..."
            apt install -y "$package" || log_warning "Échec de l'installation de $package"
        else
            log_success "$package déjà installé"
        fi
    done
    
    # fail2ban et ufw peuvent nécessiter une configuration
    if ! dpkg -l | grep -q "^ii  fail2ban "; then
        read -p "Installer fail2ban (recommandé pour la sécurité)? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            apt install -y fail2ban
            systemctl enable fail2ban
            systemctl start fail2ban
            log_success "fail2ban installé et activé"
        fi
    fi
    
    if ! dpkg -l | grep -q "^ii  ufw "; then
        read -p "Installer ufw (firewall)? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            apt install -y ufw
            log_success "ufw installé (configuration manuelle requise)"
            log_warning "N'oubliez pas de configurer ufw avant de l'activer pour éviter de vous bloquer!"
        fi
    fi
}

# ============================================================================
# CRÉATION DES RÉPERTOIRES
# ============================================================================

create_directories() {
    log_step "Création des répertoires..."
    
    local dirs=(
        "$LOG_DIR"
        "$LOG_DIR/json"
        "$LOG_DIR/html"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] mkdir -p $dir"
        else
            if [[ ! -d "$dir" ]]; then
                mkdir -p "$dir"
                chmod 755 "$dir"
                log_success "Répertoire créé: $dir"
            else
                log_info "Répertoire déjà existant: $dir"
            fi
        fi
    done
}

# ============================================================================
# INSTALLATION DES SCRIPTS
# ============================================================================

install_scripts() {
    log_step "Installation des scripts..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] cp -r $SCRIPT_DIR $INSTALL_DIR"
        return
    fi
    
    # Si on est déjà dans /opt, pas besoin de copier
    if [[ "$SCRIPT_DIR" == "$INSTALL_DIR" ]]; then
        log_info "Scripts déjà dans $INSTALL_DIR"
    else
        if [[ -d "$INSTALL_DIR" ]]; then
            log_warning "Le répertoire $INSTALL_DIR existe déjà"
            read -p "Écraser l'installation existante? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation annulée"
                return
            fi
            rm -rf "$INSTALL_DIR"
        fi
        
        cp -r "$SCRIPT_DIR" "$INSTALL_DIR"
        log_success "Scripts copiés vers $INSTALL_DIR"
    fi
    
    # Rendre les scripts exécutables
    chmod +x "$INSTALL_DIR"/scripts/*.sh
    chmod +x "$INSTALL_DIR"/setup.sh
    log_success "Scripts rendus exécutables"
}

# ============================================================================
# CONFIGURATION
# ============================================================================

install_config() {
    log_step "Installation de la configuration..."
    
    local config_source="$INSTALL_DIR/config/vps-toolkit.conf.example"
    local config_dest="/etc/vps-toolkit.conf"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] cp $config_source $config_dest"
        return
    fi
    
    if [[ -f "$config_dest" ]]; then
        log_warning "Configuration existante détectée: $config_dest"
        read -p "Écraser la configuration existante? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Configuration conservée"
            return
        fi
    fi
    
    if [[ -f "$config_source" ]]; then
        cp "$config_source" "$config_dest"
        chmod 644 "$config_dest"
        log_success "Configuration installée: $config_dest"
        log_warning "N'oubliez pas de personnaliser /etc/vps-toolkit.conf (email, Telegram, etc.)"
    else
        log_warning "Fichier de configuration exemple non trouvé"
    fi
}

# ============================================================================
# CONFIGURATION CRON
# ============================================================================

setup_cron() {
    log_step "Configuration des tâches cron..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] cp config/vps-toolkit.cron /etc/cron.d/vps-toolkit"
        return
    fi
    
    local cron_source="$INSTALL_DIR/config/vps-toolkit.cron"
    local cron_dest="/etc/cron.d/vps-toolkit"
    
    if [[ ! -f "$cron_source" ]]; then
        log_warning "Fichier cron non trouvé: $cron_source"
        return
    fi
    
    # Copier le fichier cron
    cp "$cron_source" "$cron_dest"
    chmod 644 "$cron_dest"
    
    # Remplacer TOOLKIT_DIR dans le fichier cron
    sed -i "s|TOOLKIT_DIR=.*|TOOLKIT_DIR=$INSTALL_DIR|" "$cron_dest"
    
    log_success "Tâches cron installées: $cron_dest"
    log_warning "Les tâches cron sont configurées mais vous devez personnaliser les adresses email"
    log_info "Éditez $cron_dest pour modifier les horaires et destinations d'alertes"
    
    # Redémarrer cron
    systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null
    log_success "Service cron redémarré"
}

# ============================================================================
# TEST DE L'INSTALLATION
# ============================================================================

test_installation() {
    log_step "Test de l'installation..."
    
    echo
    log_info "Exécution d'un test rapide..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] $INSTALL_DIR/scripts/vps-health-check.sh --help"
        return
    fi
    
    # Tester que les scripts sont exécutables
    if [[ -x "$INSTALL_DIR/scripts/vps-health-check.sh" ]]; then
        log_success "vps-health-check.sh est exécutable"
    else
        log_error "vps-health-check.sh n'est pas exécutable"
    fi
    
    echo
    read -p "Voulez-vous exécuter un health check de test? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        echo
        "$INSTALL_DIR/scripts/vps-health-check.sh" || log_error "Échec du test"
    fi
}

# ============================================================================
# AFFICHAGE DES PROCHAINES ÉTAPES
# ============================================================================

show_next_steps() {
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}✓ Installation terminée avec succès!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BOLD}📋 Prochaines étapes:${NC}"
    echo
    echo -e "${CYAN}1. Personnaliser la configuration:${NC}"
    echo -e "   sudo nano /etc/vps-toolkit.conf"
    echo -e "   ${YELLOW}→ Configurez les adresses email et tokens Telegram${NC}"
    echo
    echo -e "${CYAN}2. Tester les scripts manuellement:${NC}"
    echo -e "   sudo $INSTALL_DIR/scripts/vps-health-check.sh"
    echo -e "   sudo $INSTALL_DIR/scripts/vps-security-audit.sh"
    echo -e "   sudo $INSTALL_DIR/scripts/vps-ssh-analysis.sh"
    echo -e "   sudo $INSTALL_DIR/scripts/vps-intrusion-check.sh"
    echo
    echo -e "${CYAN}3. Personnaliser les tâches cron (optionnel):${NC}"
    echo -e "   sudo nano /etc/cron.d/vps-toolkit"
    echo
    echo -e "${CYAN}4. Consulter les rapports:${NC}"
    echo -e "   JSON: /var/log/vps-toolkit/json/"
    echo -e "   HTML: /var/log/vps-toolkit/html/"
    echo
    echo -e "${CYAN}5. Lire la documentation complète:${NC}"
    echo -e "   $INSTALL_DIR/README.md"
    echo -e "   $INSTALL_DIR/docs/"
    echo
    echo -e "${BOLD}📚 Commandes utiles:${NC}"
    echo -e "   Voir les logs:        ${BLUE}tail -f /var/log/vps-toolkit/cron.log${NC}"
    echo -e "   Vérifier les crons:   ${BLUE}sudo crontab -l${NC}"
    echo -e "   Aide d'un script:     ${BLUE}sudo $INSTALL_DIR/scripts/vps-health-check.sh --help${NC}"
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}🛡️  Votre VPS est maintenant équipé pour la surveillance de sécurité!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# ============================================================================
# AIDE
# ============================================================================

show_help() {
    cat <<EOF
Usage: sudo ./setup.sh [OPTIONS]

Installation et configuration de VPS Security Toolkit

OPTIONS:
    -h, --help              Afficher cette aide
    -d, --dry-run           Mode simulation (aucune modification)
    -o, --optional-deps     Installer automatiquement les dépendances optionnelles
    -c, --cron              Configurer automatiquement les tâches cron
    -y, --yes               Répondre oui à toutes les questions
    
EXEMPLES:
    # Installation interactive (recommandé)
    sudo ./setup.sh
    
    # Installation complète automatique
    sudo ./setup.sh --optional-deps --cron --yes
    
    # Simulation
    sudo ./setup.sh --dry-run

DÉPENDANCES REQUISES:
    bash, grep, awk, sed, ps, uptime, free, df

DÉPENDANCES OPTIONNELLES:
    bc, jq, whois, sensors, mail, curl, fail2ban, ufw

Pour plus d'informations, consultez README.md
EOF
}

# ============================================================================
# GESTION DES ARGUMENTS
# ============================================================================

AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            log_info "Mode DRY RUN activé (aucune modification ne sera effectuée)"
            shift
            ;;
        -o|--optional-deps)
            INSTALL_OPTIONAL_DEPS=true
            shift
            ;;
        -c|--cron)
            SETUP_CRON=true
            shift
            ;;
        -y|--yes)
            AUTO_YES=true
            INSTALL_OPTIONAL_DEPS=true
            SETUP_CRON=true
            shift
            ;;
        *)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_header
    
    check_root
    check_ubuntu
    check_dependencies
    create_directories
    install_scripts
    install_config
    
    if [[ "$SETUP_CRON" == "true" ]] || [[ "$AUTO_YES" == "true" ]]; then
        setup_cron
    else
        echo
        read -p "Configurer les tâches cron automatiques? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            setup_cron
        fi
    fi
    
    test_installation
    show_next_steps
}

# Exécuter le script principal
main

exit 0
