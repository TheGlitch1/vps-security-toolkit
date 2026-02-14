#!/bin/bash

# Fichier: shared-functions.sh
# Description: Fonctions communes partagées entre tous les scripts VPS Security Toolkit
# Auteur: VPS Security Toolkit
# Version: 1.0.0
# Compatibilité: Ubuntu 20.04, 22.04, 24.04

# Ce fichier doit être sourcé par les autres scripts:
# source "$(dirname "$0")/shared-functions.sh"

# ============================================================================
# COULEURS ET FORMATAGE
# ============================================================================

# Codes couleur ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Symboles Unicode
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_SIGN="⚠️"
INFO_SIGN="ℹ️"
ROCKET="🚀"
LOCK="🔒"
SHIELD="🛡️"
FIRE="🔥"
ALERT="🚨"
GRAPH="📊"
SEARCH="🔍"
WRENCH="🔧"

# Désactiver les couleurs si NO_COLOR est défini
if [[ -n "${NO_COLOR:-}" ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    BOLD=''
    NC=''
fi

# ============================================================================
# FONCTIONS DE LOGGING
# ============================================================================

# Fonction: log_info
# Description: Affiche un message d'information
# Usage: log_info "Message"
log_info() {
    [[ "$VERBOSITY" != "silent" ]] && echo -e "${BLUE}[INFO]${NC} $1"
}

# Fonction: log_success
# Description: Affiche un message de succès
# Usage: log_success "Message"
log_success() {
    [[ "$VERBOSITY" != "silent" ]] && echo -e "${GREEN}[OK]${NC} $1"
}

# Fonction: log_warning
# Description: Affiche un avertissement (toujours affiché sauf en silent)
# Usage: log_warning "Message"
log_warning() {
    [[ "$VERBOSITY" != "silent" ]] && echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Fonction: log_error
# Description: Affiche une erreur (toujours affiché)
# Usage: log_error "Message"
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Fonction: log_verbose
# Description: Affiche uniquement en mode verbose
# Usage: log_verbose "Message détaillé"
log_verbose() {
    [[ "$VERBOSITY" == "verbose" ]] && echo -e "${CYAN}[VERBOSE]${NC} $1"
}

# Fonction: log_debug
# Description: Affiche uniquement en mode debug
# Usage: log_debug "Message debug"
log_debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $1"
}

# ============================================================================
# FONCTIONS DE VÉRIFICATION SYSTÈME
# ============================================================================

# Fonction: check_root
# Description: Vérifie si le script est exécuté en tant que root
# Usage: check_root
# Exit: 1 si non-root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root ou avec sudo"
        exit 1
    fi
}

# Fonction: check_command
# Description: Vérifie si une commande existe
# Usage: check_command "command_name"
# Return: 0 si existe, 1 sinon
check_command() {
    command -v "$1" &> /dev/null
}

# Fonction: require_command
# Description: Vérifie si une commande existe, sinon affiche erreur et sort
# Usage: require_command "command_name"
require_command() {
    if ! check_command "$1"; then
        log_error "Commande requise non trouvée: $1"
        log_error "Installez-la avec: apt install <package>"
        exit 1
    fi
}

# Fonction: check_ubuntu
# Description: Vérifie si le système est Ubuntu
# Usage: check_ubuntu
# Return: 0 si Ubuntu, 1 sinon
check_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        [[ "$ID" == "ubuntu" ]] && return 0
    fi
    return 1
}

# ============================================================================
# FONCTIONS DE GESTION DES RÉPERTOIRES
# ============================================================================

# Fonction: create_directories
# Description: Crée les répertoires de logs nécessaires
# Usage: create_directories
create_directories() {
    local dirs=(
        "$LOG_DIR"
        "$JSON_DIR"
        "$HTML_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || {
                log_error "Impossible de créer le répertoire: $dir"
                return 1
            }
            log_verbose "Répertoire créé: $dir"
        fi
    done
    
    return 0
}

# ============================================================================
# FONCTIONS D'ALERTES EMAIL
# ============================================================================

# Fonction: send_email_alert
# Description: Envoie une alerte par email
# Usage: send_email_alert "Subject" "Body"
send_email_alert() {
    if [[ "$ENABLE_EMAIL" != "true" || -z "$EMAIL_TO" ]]; then
        log_verbose "Email désactivé ou destinataire non configuré"
        return 0
    fi
    
    if ! check_command "mail"; then
        log_warning "Commande 'mail' non disponible. Installez mailutils."
        return 1
    fi
    
    local subject="$1"
    local body="$2"
    local hostname=$(hostname)
    
    # Template email complet
    local email_body="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️ VPS SECURITY TOOLKIT - ALERTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📡 Serveur: ${hostname}
🔧 Script: ${SCRIPT_NAME}
📅 Timestamp: ${TIMESTAMP}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${body}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Rapports disponibles:
- JSON: ${JSON_DIR}/
- HTML: ${HTML_DIR}/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Généré par VPS Security Toolkit v${VERSION}
"
    
    echo "$email_body" | mail -s "[VPS-ALERT] ${hostname} - ${subject}" "$EMAIL_TO" 2>/dev/null
    local status=$?
    
    if [[ $status -eq 0 ]]; then
        log_verbose "Email envoyé à: $EMAIL_TO"
        return 0
    else
        log_warning "Échec d'envoi de l'email"
        return 1
    fi
}

# ============================================================================
# FONCTIONS D'ALERTES TELEGRAM
# ============================================================================

# Fonction: send_telegram_alert
# Description: Envoie une alerte via Telegram
# Usage: send_telegram_alert "Message"
send_telegram_alert() {
    if [[ "$ENABLE_TELEGRAM" != "true" || -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        log_verbose "Telegram désactivé ou non configuré"
        return 0
    fi
    
    if ! check_command "curl"; then
        log_warning "Commande 'curl' non disponible. Installez curl."
        return 1
    fi
    
    local message="$1"
    local hostname=$(hostname)
    
    # Template Telegram avec Markdown
    local telegram_message="🛡️ *VPS SECURITY ALERT*

📡 Server: \`${hostname}\`
🔧 Script: \`${SCRIPT_NAME}\`
📅 Time: \`${TIMESTAMP}\`

━━━━━━━━━━━━━━━━━━━

${message}

━━━━━━━━━━━━━━━━━━━
_VPS Security Toolkit v${VERSION}_"
    
    # Échapper les caractères spéciaux pour Markdown
    telegram_message=$(echo "$telegram_message" | sed 's/\./\\./g' | sed 's/\-/\\-/g')
    
    local response=$(curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${telegram_message}" \
        -d parse_mode="MarkdownV2" 2>&1)
    
    if echo "$response" | grep -q '"ok":true'; then
        log_verbose "Message Telegram envoyé avec succès"
        return 0
    else
        log_warning "Échec d'envoi du message Telegram"
        log_debug "Response: $response"
        return 1
    fi
}

# ============================================================================
# FONCTIONS DE FORMATAGE
# ============================================================================

# Fonction: print_header
# Description: Affiche un en-tête formaté
# Usage: print_header "Titre"
print_header() {
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local title="$1"
    local width=80
    
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}$title${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# Fonction: print_section
# Description: Affiche un titre de section
# Usage: print_section "Section"
print_section() {
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local title="$1"
    echo
    echo -e "${BLUE}▶ ${BOLD}${title}${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────${NC}"
}

# Fonction: print_table_row
# Description: Affiche une ligne de tableau formatée
# Usage: print_table_row "Label" "Value" "Status"
# Status: OK, WARNING, CRITICAL, INFO
print_table_row() {
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local label="$1"
    local value="$2"
    local status="${3:-INFO}"
    local color="${NC}"
    local symbol="  "
    
    case "$status" in
        "OK"|"SUCCESS")
            color="${GREEN}"
            symbol="${CHECK_MARK} "
            ;;
        "WARNING"|"WARN")
            color="${YELLOW}"
            symbol="${WARNING_SIGN} "
            ;;
        "CRITICAL"|"ERROR"|"FAIL")
            color="${RED}"
            symbol="${CROSS_MARK} "
            ;;
        "INFO")
            color="${BLUE}"
            symbol="${INFO_SIGN} "
            ;;
    esac
    
    printf "  ${symbol}%-35s ${color}%-40s${NC}\n" "$label" "$value"
}

# Fonction: print_progress_bar
# Description: Affiche une barre de progression ASCII
# Usage: print_progress_bar 75 100
print_progress_bar() {
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local color="${GREEN}"
    [[ $percentage -ge 80 ]] && color="${YELLOW}"
    [[ $percentage -ge 90 ]] && color="${RED}"
    
    printf "  ["
    printf "${color}%${filled}s${NC}" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${color}%3d%%${NC}\n" "$percentage"
}

# ============================================================================
# FONCTIONS DE CALCUL
# ============================================================================

# Fonction: calculate_percentage
# Description: Calcule un pourcentage
# Usage: calculate_percentage used total
# Output: Pourcentage arrondi (ex: 75)
calculate_percentage() {
    local used=$1
    local total=$2
    
    if [[ $total -eq 0 ]]; then
        echo "0"
        return
    fi
    
    if check_command "bc"; then
        echo "scale=0; ($used * 100) / $total" | bc
    else
        echo $(( (used * 100) / total ))
    fi
}

# ============================================================================
# FONCTIONS JSON
# ============================================================================

# Fonction: json_escape
# Description: Échappe les caractères spéciaux pour JSON
# Usage: json_escape "string"
json_escape() {
    local string="$1"
    # Échapper les backslashes, guillemets, et caractères de contrôle
    echo "$string" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/\\t/g' | sed 's/\n/\\n/g'
}

# Fonction: init_json_output
# Description: Initialise la structure JSON de base
# Usage: init_json_output
init_json_output() {
    local hostname=$(hostname)
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$JSON_OUTPUT_FILE" <<EOF
{
  "metadata": {
    "script": "${SCRIPT_NAME}",
    "version": "${VERSION}",
    "timestamp": "${start_time}",
    "hostname": "${hostname}",
    "duration_seconds": 0
  },
  "summary": {
    "status": "OK",
    "critical_issues": 0,
    "warnings": 0,
    "info": 0
  },
  "data": {},
  "alerts": []
}
EOF
}

# ============================================================================
# FONCTIONS HTML
# ============================================================================

# Fonction: generate_html_header
# Description: Génère l'en-tête HTML avec Bootstrap et DataTables
# Usage: generate_html_header "Title"
generate_html_header() {
    local title="$1"
    local hostname=$(hostname)
    
    cat <<EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="300">
    <title>${title} - ${hostname}</title>
    
    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- DataTables CSS -->
    <link href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    
    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
    
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    
    <style>
        :root {
            --color-success: #28a745;
            --color-warning: #ffc107;
            --color-danger: #dc3545;
            --color-info: #17a2b8;
        }
        body {
            background-color: #f8f9fa;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .dashboard-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem 0;
            margin-bottom: 2rem;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .card {
            border: none;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 1.5rem;
            transition: transform 0.2s;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
        }
        .metric-card {
            text-align: center;
            padding: 1.5rem;
        }
        .metric-value {
            font-size: 2.5rem;
            font-weight: bold;
            margin: 0.5rem 0;
        }
        .metric-label {
            color: #6c757d;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .status-badge {
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-weight: bold;
            font-size: 0.9rem;
        }
        .status-ok { background-color: var(--color-success); color: white; }
        .status-warning { background-color: var(--color-warning); color: #000; }
        .status-critical { background-color: var(--color-danger); color: white; }
        .status-info { background-color: var(--color-info); color: white; }
        
        .progress-custom {
            height: 25px;
            border-radius: 10px;
            background-color: #e9ecef;
        }
        .table-custom {
            background: white;
            border-radius: 10px;
            overflow: hidden;
        }
        footer {
            margin-top: 3rem;
            padding: 2rem 0;
            background-color: #343a40;
            color: white;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="dashboard-header">
        <div class="container">
            <h1><i class="fas fa-shield-alt"></i> ${title}</h1>
            <p class="mb-0"><i class="fas fa-server"></i> ${hostname} | <i class="fas fa-clock"></i> ${TIMESTAMP}</p>
        </div>
    </div>
    
    <div class="container">
EOF
}

# Fonction: generate_html_footer
# Description: Génère le pied de page HTML
# Usage: generate_html_footer
generate_html_footer() {
    cat <<EOF
    </div>
    
    <footer>
        <div class="container">
            <p class="mb-0">🛡️ VPS Security Toolkit v${VERSION}</p>
            <small>Généré le ${TIMESTAMP}</small>
        </div>
    </footer>
    
    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    
    <!-- jQuery -->
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    
    <!-- DataTables JS -->
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
    
    <script>
        // Initialize DataTables
        \$(document).ready(function() {
            \$('.data-table').DataTable({
                pageLength: 25,
                order: [[0, 'desc']],
                language: {
                    url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/fr-FR.json'
                }
            });
        });
    </script>
</body>
</html>
EOF
}

# ============================================================================
# FONCTIONS DE TEMPS
# ============================================================================

# Fonction: get_timestamp
# Description: Retourne un timestamp formaté
# Usage: get_timestamp
get_timestamp() {
    date +"%Y-%m-%d_%H-%M-%S"
}

# Fonction: get_iso_timestamp
# Description: Retourne un timestamp ISO 8601
# Usage: get_iso_timestamp
get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Fonction: calculate_duration
# Description: Calcule la durée en secondes
# Usage: calculate_duration start_time
calculate_duration() {
    local start_time=$1
    local end_time=$(date +%s)
    echo $((end_time - start_time))
}

# ============================================================================
# FONCTIONS DE NETTOYAGE
# ============================================================================

# Fonction: cleanup_old_logs
# Description: Nettoie les anciens fichiers de logs
# Usage: cleanup_old_logs
cleanup_old_logs() {
    log_verbose "Nettoyage des anciens logs..."
    
    # Supprimer les JSON > 30 jours
    find "$JSON_DIR" -name "*.json" -mtime +30 -delete 2>/dev/null
    
    # Supprimer les HTML > 7 jours
    find "$HTML_DIR" -name "*.html" ! -name "*_latest.html" -mtime +7 -delete 2>/dev/null
    
    # Compresser les logs texte > 7 jours
    find "$LOG_DIR" -name "*.log" -mtime +7 ! -name "*.gz" -exec gzip {} \; 2>/dev/null
    
    # Supprimer les logs compressés > 90 jours
    find "$LOG_DIR" -name "*.log.gz" -mtime +90 -delete 2>/dev/null
    
    log_verbose "Nettoyage terminé"
}

# ============================================================================
# FONCTIONS D'AIDE
# ============================================================================

# Fonction: get_file_size
# Description: Retourne la taille d'un fichier en octets
# Usage: get_file_size "/path/to/file"
get_file_size() {
    local file="$1"
    [[ -f "$file" ]] && stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
}

# Fonction: human_readable_size
# Description: Convertit une taille en format lisible
# Usage: human_readable_size 1024000
human_readable_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $size -gt 1024 && $unit -lt 4 ]]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "${size}${units[$unit]}"
}

# ============================================================================
# INITIALISATION
# ============================================================================

log_verbose "Fonctions partagées chargées (v${VERSION:-1.0.0})"
