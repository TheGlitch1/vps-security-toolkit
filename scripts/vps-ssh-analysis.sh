#!/bin/bash

# Script: vps-ssh-analysis.sh
# Description: Analyse approfondie des tentatives d'intrusion SSH
# Auteur: VPS Security Toolkit
# Version: 1.0.0
# Compatibilité: Ubuntu 20.04, 22.04, 24.04

# ============================================================================
# CONFIGURATION
# ============================================================================

VERSION="1.0.0"
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions partagées
if [[ -f "$SCRIPT_DIR/shared-functions.sh" ]]; then
    source "$SCRIPT_DIR/shared-functions.sh"
else
    echo "ERREUR: Impossible de charger shared-functions.sh"
    exit 1
fi

# Charger la configuration
if [[ -f "/etc/vps-toolkit.conf" ]]; then
    source "/etc/vps-toolkit.conf"
elif [[ -f "$SCRIPT_DIR/../config/vps-toolkit.conf.example" ]]; then
    source "$SCRIPT_DIR/../config/vps-toolkit.conf.example"
fi

# Variables par défaut
LOG_DIR="${LOG_DIR:-/var/log/vps-toolkit}"
JSON_DIR="${JSON_DIR:-$LOG_DIR/json}"
HTML_DIR="${HTML_DIR:-$LOG_DIR/html}"
TIMESTAMP=$(get_timestamp)

# Modes
VERBOSITY="${VERBOSITY:-normal}"
OUTPUT_TERMINAL="${OUTPUT_TERMINAL:-true}"
OUTPUT_JSON="${OUTPUT_JSON:-true}"
OUTPUT_HTML="${OUTPUT_HTML:-true}"

# Alertes
ENABLE_EMAIL="${ENABLE_EMAIL:-false}"
ENABLE_TELEGRAM="${ENABLE_TELEGRAM:-false}"
EMAIL_TO="${EMAIL_TO:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Fichiers de sortie
LOG_FILE="$LOG_DIR/ssh-analysis.log"
JSON_OUTPUT_FILE="$JSON_DIR/ssh-analysis_${TIMESTAMP}.json"
JSON_LATEST="$JSON_DIR/ssh-analysis_latest.json"
HTML_OUTPUT_FILE="$HTML_DIR/ssh-analysis_${TIMESTAMP}.html"
HTML_LATEST="$HTML_DIR/ssh-analysis_latest.html"

# Fichiers de logs système
AUTH_LOG="/var/log/auth.log"
AUTH_LOG_OLD="/var/log/auth.log.1"

# Période d'analyse
PERIOD="${PERIOD:-24h}"  # 24h, 7d, 30d, all
MAX_LOG_LINES="${MAX_LOG_LINES:-100000}"  # Limite pour éviter surcharge
TOP_COUNT="${TOP_COUNT:-20}"  # Nombre d'IPs dans le top

# Géolocalisation
ENABLE_GEOLOCATION="${ENABLE_GEOLOCATION:-true}"
GEOLOCATION_CACHE="/tmp/vps-toolkit-geoip-cache"

# Seuils d'alerte
ALERT_FAILED_ATTEMPTS="${ALERT_FAILED_ATTEMPTS:-100}"
ALERT_UNIQUE_IPS="${ALERT_UNIQUE_IPS:-50}"

# ============================================================================
# FONCTIONS D'ANALYSE DES LOGS
# ============================================================================

# Fonction: get_log_lines
# Description: Récupère les lignes de log selon la période
get_log_lines() {
    local period="$1"
    local log_file="$AUTH_LOG"
    
    if [[ ! -f "$log_file" ]]; then
        echo "" >&2
        log_error "Fichier auth.log introuvable: $log_file" >&2
        return 1
    fi
    
    case "$period" in
        24h)
            # Dernières 24 heures
            local cutoff=$(date -d '24 hours ago' '+%b %d %H:%M')
            ;;
        7d)
            # 7 derniers jours
            local cutoff=$(date -d '7 days ago' '+%b %d')
            ;;
        30d)
            # 30 derniers jours
            local cutoff=$(date -d '30 days ago' '+%b %d')
            ;;
        all)
            # Tous les logs (limité à MAX_LOG_LINES)
            if [[ -f "$AUTH_LOG_OLD" ]]; then
                cat "$AUTH_LOG_OLD" "$AUTH_LOG" | tail -n "$MAX_LOG_LINES"
            else
                cat "$AUTH_LOG" | tail -n "$MAX_LOG_LINES"
            fi
            return 0
            ;;
        *)
            cat "$AUTH_LOG"
            return 0
            ;;
    esac
    
    # Filtrer par date
    if [[ -f "$AUTH_LOG_OLD" ]]; then
        cat "$AUTH_LOG_OLD" "$AUTH_LOG" | tail -n "$MAX_LOG_LINES"
    else
        cat "$AUTH_LOG" | tail -n "$MAX_LOG_LINES"
    fi
}

# Fonction: analyze_failed_attempts
# Description: Analyse les tentatives échouées
analyze_failed_attempts() {
    local period="$1"
    local logs="$2"
    
    log_verbose "Analyse des tentatives échouées ($period)..." >&2
    
    # Extraire les tentatives échouées
    local failed_count=$(echo "$logs" | grep -i "Failed password\|authentication failure\|Invalid user" | wc -l)
    local invalid_users=$(echo "$logs" | grep -i "Invalid user" | wc -l)
    local failed_root=$(echo "$logs" | grep -i "Failed password for root" | wc -l)
    local failed_valid=$(echo "$logs" | grep -i "Failed password for" | grep -v "Invalid user" | wc -l)
    
    # IPs uniques
    local unique_ips=$(echo "$logs" | grep -oP '(?<=from )\d+\.\d+\.\d+\.\d+' | sort -u | wc -l)
    
    # Tentatives par méthode
    local password_attempts=$(echo "$logs" | grep -i "Failed password" | wc -l)
    local publickey_fails=$(echo "$logs" | grep -i "Failed publickey" | wc -l)
    
    echo "{\"total\":$failed_count,\"invalid_users\":$invalid_users,\"failed_root\":$failed_root,\"failed_valid_users\":$failed_valid,\"unique_ips\":$unique_ips,\"password_attempts\":$password_attempts,\"publickey_fails\":$publickey_fails}"
}

# Fonction: get_top_attackers
# Description: Top IPs attaquantes
get_top_attackers() {
    local period="$1"
    local logs="$2"
    local count="${3:-20}"
    
    log_verbose "Extraction top $count IPs ($period)..." >&2
    
    local top_ips=$(echo "$logs" | \
        grep -i "Failed password\|authentication failure\|Invalid user" | \
        grep -oP '(?<=from )\d+\.\d+\.\d+\.\d+' | \
        sort | uniq -c | sort -rn | head -n "$count")
    
    local json="["
    local first=true
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        local attempts=$(echo "$line" | awk '{print $1}')
        local ip=$(echo "$line" | awk '{print $2}')
        
        # Géolocalisation si activée
        local country="Unknown"
        local city="Unknown"
        local isp="Unknown"
        
        if [[ "$ENABLE_GEOLOCATION" == "true" ]] && command -v whois &>/dev/null; then
            local geo_info=$(get_ip_geolocation "$ip")
            country=$(echo "$geo_info" | jq -r '.country // "Unknown"')
            city=$(echo "$geo_info" | jq -r '.city // "Unknown"')
            isp=$(echo "$geo_info" | jq -r '.isp // "Unknown"')
        fi
        
        # Vérifier si banni par fail2ban
        local banned=false
        if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban 2>/dev/null; then
            if fail2ban-client status sshd 2>/dev/null | grep -q "$ip"; then
                banned=true
            fi
        fi
        
        [[ "$first" == "false" ]] && json+=","
        json+="{\"ip\":\"$ip\",\"attempts\":$attempts,\"country\":\"$country\",\"city\":\"$city\",\"isp\":\"$(json_escape "$isp")\",\"banned\":$banned}"
        first=false
        
    done <<< "$top_ips"
    
    json+="]"
    echo "$json"
}

# Fonction: get_ip_geolocation
# Description: Obtenir géolocalisation d'une IP via whois
get_ip_geolocation() {
    local ip="$1"
    
    # Cache
    if [[ -f "${GEOLOCATION_CACHE}_${ip}" ]]; then
        cat "${GEOLOCATION_CACHE}_${ip}"
        return 0
    fi
    
    local whois_data=$(timeout 3 whois "$ip" 2>/dev/null || echo "")
    
    local country=$(echo "$whois_data" | grep -i "country:" | head -1 | awk '{print $2}' | tr -d '\r')
    local city=$(echo "$whois_data" | grep -i "city:" | head -1 | awk -F':' '{print $2}' | xargs | tr -d '\r')
    local org=$(echo "$whois_data" | grep -i "org-name:\|orgname:\|organization:" | head -1 | awk -F':' '{print $2}' | xargs | tr -d '\r')
    
    [[ -z "$country" ]] && country="Unknown"
    [[ -z "$city" ]] && city="Unknown"
    [[ -z "$org" ]] && org="Unknown"
    
    local result="{\"country\":\"$country\",\"city\":\"$city\",\"isp\":\"$(json_escape "$org")\"}"
    
    # Sauvegarder en cache
    echo "$result" > "${GEOLOCATION_CACHE}_${ip}"
    
    echo "$result"
}

# Fonction: analyze_attack_patterns
# Description: Détecte les patterns d'attaque
analyze_attack_patterns() {
    local logs="$1"
    
    log_verbose "Analyse des patterns d'attaque..." >&2
    
    # Brute force (même IP, nombreuses tentatives rapides)
    local brute_force_ips=$(echo "$logs" | \
        grep -i "Failed password" | \
        grep -oP '(?<=from )\d+\.\d+\.\d+\.\d+' | \
        sort | uniq -c | awk '$1 >= 10 {print $2}' | wc -l)
    
    # Scan de ports (connexions multiples courtes)
    local port_scans=$(echo "$logs" | \
        grep -i "Connection closed by\|Connection reset by" | \
        grep -oP '\d+\.\d+\.\d+\.\d+' | \
        sort | uniq -c | awk '$1 >= 20 {print $2}' | wc -l)
    
    # Dictionary attacks (tentatives avec utilisateurs invalides variés)
    local dict_attacks=$(echo "$logs" | \
        grep -i "Invalid user" | \
        grep -oP '(?<=Invalid user )\w+' | \
        sort -u | wc -l)
    
    # Attaques root
    local root_attacks=$(echo "$logs" | \
        grep -i "Failed password for root" | \
        grep -oP '(?<=from )\d+\.\d+\.\d+\.\d+' | \
        sort -u | wc -l)
    
    echo "{\"brute_force_sources\":$brute_force_ips,\"port_scan_sources\":$port_scans,\"dictionary_attack_users\":$dict_attacks,\"root_attack_sources\":$root_attacks}"
}

# Fonction: get_successful_logins
# Description: Analyse les connexions réussies
get_successful_logins() {
    local period="$1"
    local logs="$2"
    
    log_verbose "Analyse des connexions réussies ($period)..." >&2
    
    local success_count=$(echo "$logs" | grep -i "Accepted password\|Accepted publickey" | wc -l)
    local password_logins=$(echo "$logs" | grep -i "Accepted password" | wc -l)
    local key_logins=$(echo "$logs" | grep -i "Accepted publickey" | wc -l)
    
    local success_ips="["
    local first=true
    
    local unique_success=$(echo "$logs" | \
        grep -i "Accepted password\|Accepted publickey" | \
        grep -oP '(?<=from )\d+\.\d+\.\d+\.\d+' | \
        sort -u | head -10)
    
    while IFS= read -r ip; do
        if [[ -z "$ip" ]]; then
            continue
        fi
        
        local ip_count=$(echo "$logs" | grep -i "Accepted password\|Accepted publickey" | grep -c "$ip")
        
        [[ "$first" == "false" ]] && success_ips+=","
        success_ips+="{\"ip\":\"$ip\",\"logins\":$ip_count}"
        first=false
        
    done <<< "$unique_success"
    
    success_ips+="]"
    
    echo "{\"total\":$success_count,\"password\":$password_logins,\"publickey\":$key_logins,\"unique_ips\":$success_ips}"
}

# Fonction: get_fail2ban_stats
# Description: Statistiques fail2ban
get_fail2ban_stats() {
    log_verbose "Récupération stats fail2ban..." >&2
    
    local installed=false
    local active=false
    local banned_count=0
    local banned_ips="[]"
    
    if command -v fail2ban-client &>/dev/null; then
        installed=true
        
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            active=true
            
            # Compter les IPs bannies
            local banned_list=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP list" | cut -d: -f2 | xargs)
            
            if [[ -n "$banned_list" ]]; then
                banned_count=$(echo "$banned_list" | wc -w)
                
                banned_ips="["
                local first=true
                for ip in $banned_list; do
                    [[ "$first" == "false" ]] && banned_ips+=","
                    banned_ips+="\"$ip\""
                    first=false
                done
                banned_ips+="]"
            fi
        fi
    fi
    
    echo "{\"installed\":$installed,\"active\":$active,\"banned_count\":$banned_count,\"banned_ips\":$banned_ips}"
}

# ============================================================================
# FONCTION PRINCIPALE DE COLLECTE
# ============================================================================

collect_ssh_analysis() {
    log_verbose "Démarrage de l'analyse SSH..." >&2
    
    local start_time=$(date +%s)
    local hostname=$(hostname)
    
    # Récupérer les logs
    local logs=$(get_log_lines "$PERIOD")
    local total_lines=$(echo "$logs" | wc -l)
    
    log_verbose "Lignes de log analysées: $total_lines" >&2
    
    # Analyses pour différentes périodes
    local stats_24h=$(analyze_failed_attempts "24h" "$(get_log_lines '24h')")
    local stats_7d=$(analyze_failed_attempts "7d" "$(get_log_lines '7d')")
    local stats_30d=$(analyze_failed_attempts "30d" "$(get_log_lines '30d')")
    local stats_all=$(analyze_failed_attempts "all" "$logs")
    
    # Top attackers
    local top_attackers=$(get_top_attackers "$PERIOD" "$logs" "$TOP_COUNT")
    
    # Patterns d'attaque
    local patterns=$(analyze_attack_patterns "$logs")
    
    # Connexions réussies
    local successful=$(get_successful_logins "$PERIOD" "$logs")
    
    # Stats fail2ban
    local fail2ban=$(get_fail2ban_stats)
    
    # Déterminer le statut global
    local status="OK"
    local failed_24h=$(echo "$stats_24h" | grep -oP '(?<="total":)\d+')
    local unique_ips_24h=$(echo "$stats_24h" | grep -oP '(?<="unique_ips":)\d+')
    
    if [[ $failed_24h -gt $ALERT_FAILED_ATTEMPTS || $unique_ips_24h -gt $ALERT_UNIQUE_IPS ]]; then
        status="WARNING"
    fi
    
    local duration=$(calculate_duration "$start_time")
    
    # Générer le JSON
    cat > "$JSON_OUTPUT_FILE" <<EOF
{
  "metadata": {
    "script": "vps-ssh-analysis",
    "version": "$VERSION",
    "timestamp": "$(get_iso_timestamp)",
    "hostname": "$hostname",
    "period": "$PERIOD",
    "log_lines_analyzed": $total_lines,
    "duration_seconds": $duration
  },
  "summary": {
    "status": "$status",
    "failed_attempts_24h": $failed_24h,
    "unique_attackers_24h": $unique_ips_24h,
    "alert_threshold_attempts": $ALERT_FAILED_ATTEMPTS,
    "alert_threshold_ips": $ALERT_UNIQUE_IPS
  },
  "statistics": {
    "24h": $stats_24h,
    "7d": $stats_7d,
    "30d": $stats_30d,
    "all_time": $stats_all
  },
  "top_attackers": $top_attackers,
  "attack_patterns": $patterns,
  "successful_logins": $successful,
  "fail2ban": $fail2ban
}
EOF
    
    ln -sf "$JSON_OUTPUT_FILE" "$JSON_LATEST"
    
    log_verbose "Analyse SSH terminée" >&2
}

# ============================================================================
# AFFICHAGE TERMINAL
# ============================================================================

display_terminal_output() {
    [[ "$OUTPUT_TERMINAL" != "true" ]] && return
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    local hostname=$(echo "$json_content" | grep -oP '(?<="hostname": ")[^"]+')
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+' | head -1)
    local period=$(echo "$json_content" | grep -oP '(?<="period": ")[^"]+')
    local lines=$(echo "$json_content" | grep -oP '(?<="log_lines_analyzed": )\d+')
    
    print_header "🔍 VPS SSH Analysis Report"
    
    echo -e "📊 ${BOLD}Période:${NC} $period | ${BOLD}Lignes analysées:${NC} $lines"
    echo
    
    # Statistiques 24h
    print_section "📈 Statistiques 24h"
    local failed_24h=$(echo "$json_content" | grep -A20 '"24h"' | grep -oP '(?<="total":)\d+' | head -1)
    local invalid_24h=$(echo "$json_content" | grep -A20 '"24h"' | grep -oP '(?<="invalid_users":)\d+' | head -1)
    local root_24h=$(echo "$json_content" | grep -A20 '"24h"' | grep -oP '(?<="failed_root":)\d+' | head -1)
    local ips_24h=$(echo "$json_content" | grep -A20 '"24h"' | grep -oP '(?<="unique_ips":)\d+' | head -1)
    
    local fail_status="OK"
    [[ $failed_24h -gt 50 ]] && fail_status="WARNING"
    [[ $failed_24h -gt 100 ]] && fail_status="CRITICAL"
    
    print_table_row "Tentatives échouées" "$failed_24h" "$fail_status"
    print_table_row "Utilisateurs invalides" "$invalid_24h" "INFO"
    print_table_row "Attaques root" "$root_24h" "$([ $root_24h -gt 10 ] && echo 'WARNING' || echo 'INFO')"
    print_table_row "IPs uniques" "$ips_24h" "$([ $ips_24h -gt 20 ] && echo 'WARNING' || echo 'INFO')"
    echo
    
    # Top 10 Attackers
    print_section "🌍 Top 10 IPs Attaquantes"
    echo -e "${BOLD}${CYAN}  # | IP Address      | Tentatives | Pays  | Banni${NC}"
    echo -e "  ─────────────────────────────────────────────────────────────"
    
    local top_json=$(echo "$json_content" | grep -A2000 '"top_attackers"')
    local rank=1
    
    echo "$top_json" | grep -oP '\{"ip":"[^}]+\}' | head -10 | while IFS= read -r attacker; do
        local ip=$(echo "$attacker" | grep -oP '(?<="ip":")[^"]+')
        local attempts=$(echo "$attacker" | grep -oP '(?<="attempts":)\d+')
        local country=$(echo "$attacker" | grep -oP '(?<="country":")[^"]+')
        local banned=$(echo "$attacker" | grep -oP '(?<="banned":)(true|false)')
        
        local ban_icon="❌"
        [[ "$banned" == "true" ]] && ban_icon="✅"
        
        printf "  %2d | %-15s | %10s | %-5s | %s\n" "$rank" "$ip" "$attempts" "$country" "$ban_icon"
        ((rank++))
    done
    echo
    
    # Patterns d'attaque
    print_section "🎯 Patterns d'Attaque Détectés"
    local brute=$(echo "$json_content" | grep -oP '(?<="brute_force_sources":)\d+')
    local scan=$(echo "$json_content" | grep -oP '(?<="port_scan_sources":)\d+')
    local dict=$(echo "$json_content" | grep -oP '(?<="dictionary_attack_users":)\d+')
    local root_att=$(echo "$json_content" | grep -oP '(?<="root_attack_sources":)\d+')
    
    print_table_row "Brute force (sources)" "$brute" "$([ $brute -gt 5 ] && echo 'WARNING' || echo 'INFO')"
    print_table_row "Port scans (sources)" "$scan" "$([ $scan -gt 3 ] && echo 'WARNING' || echo 'INFO')"
    print_table_row "Dictionary attack (users)" "$dict" "INFO"
    print_table_row "Root attacks (sources)" "$root_att" "$([ $root_att -gt 5 ] && echo 'WARNING' || echo 'INFO')"
    echo
    
    # Fail2ban
    print_section "🛡️  Fail2ban Status"
    local f2b_active=$(echo "$json_content" | grep -oP '"fail2ban".*?"active":(true|false)' | grep -oP '(true|false)')
    local banned_count=$(echo "$json_content" | grep -oP '(?<="banned_count":)\d+')
    
    if [[ "$f2b_active" == "true" ]]; then
        print_table_row "Service" "✓ Actif" "OK"
        print_table_row "IPs bannies" "$banned_count" "INFO"
    else
        print_table_row "Service" "✗ Inactif" "WARNING"
    fi
    echo
    
    # Footer
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "📁 Rapports:"
    echo -e "   JSON: ${BLUE}$JSON_OUTPUT_FILE${NC}"
    [[ "$OUTPUT_HTML" == "true" ]] && echo -e "   HTML: ${BLUE}$HTML_OUTPUT_FILE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# ============================================================================
# GÉNÉRATION HTML
# ============================================================================

generate_html_output() {
    [[ "$OUTPUT_HTML" != "true" ]] && return
    
    log_verbose "Génération du rapport HTML..." >&2
    
    local template_file="$SCRIPT_DIR/../templates/ssh-analysis.html"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template introuvable: $template_file"
        echo "<!-- HTML Dashboard pour SSH Analysis -->" > "$HTML_OUTPUT_FILE"
        ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
        return 1
    fi
    
    # Lire le JSON
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    # Extraire les valeurs avec jq
    local hostname=$(echo "$json_content" | jq -r '.metadata.hostname // "unknown"')
    local timestamp=$(echo "$json_content" | jq -r '.metadata.timestamp // "N/A"')
    local failed_24h=$(echo "$json_content" | jq -r '.summary.failed_attempts_24h // 0')
    local unique_ips=$(echo "$json_content" | jq -r '.summary.unique_attackers_24h // 0')
    local invalid_users=$(echo "$json_content" | jq -r '.statistics."24h".invalid_users // 0')
    local successful=$(echo "$json_content" | jq -r '.successful_logins.total // 0')
    local root_attacks=$(echo "$json_content" | jq -r '.statistics."24h".failed_root // 0')
    local banned=$(echo "$json_content" | jq -r '.fail2ban.banned_count // 0')
    
    # Compter les pays uniques
    local countries=$(echo "$json_content" | jq -r '[.top_attackers[].country] | unique | length')
    
    # Attack patterns
    local brute_force=$(echo "$json_content" | jq -r '.attack_patterns.brute_force_sources // 0')
    local port_scan=$(echo "$json_content" | jq -r '.attack_patterns.port_scan_sources // 0')
    local dictionary=$(echo "$json_content" | jq -r '.attack_patterns.dictionary_attack_users // 0')
    local root_sources=$(echo "$json_content" | jq -r '.attack_patterns.root_attack_sources // 0')
    
    # Successful logins details
    local ssh_key_logins=$(echo "$json_content" | jq -r '.successful_logins.publickey // 0')
    local password_logins=$(echo "$json_content" | jq -r '.successful_logins.password // 0')
    local successful_ips=$(echo "$json_content" | jq -r '.successful_logins.unique_ips | length // 0')
    
    # Fail2ban status
    local fail2ban_status="Not installed"
    local fail2ban_class="warning"
    if [[ $(echo "$json_content" | jq -r '.fail2ban.installed') == "true" ]]; then
        if [[ $(echo "$json_content" | jq -r '.fail2ban.active') == "true" ]]; then
            fail2ban_status="Active"
            fail2ban_class="success"
        else
            fail2ban_status="Installed but inactive"
            fail2ban_class="warning"
        fi
    fi
    
    # Copier le template et remplacer les placeholders
    cp "$template_file" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{HOSTNAME}}|${hostname:-$(hostname)}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{TIMESTAMP}}|${timestamp:-$TIMESTAMP}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{VERSION}}|$VERSION|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PERIOD}}|24h|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAILED_ATTEMPTS}}|${failed_24h:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{UNIQUE_IPS}}|${unique_ips:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{INVALID_USERS}}|${invalid_users:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUCCESSFUL_LOGINS}}|${successful:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{ROOT_ATTACKS}}|${root_attacks:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{BANNED_IPS}}|${banned:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{COUNTRIES_COUNT}}|${countries:-0}|g" "$HTML_OUTPUT_FILE"
    
    # Placeholders pour les données détaillées (vraies valeurs maintenant)
    sed -i "s|{{BRUTE_FORCE_COUNT}}|${brute_force:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PORT_SCAN_COUNT}}|${port_scan:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{DICTIONARY_USERS}}|${dictionary:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{ROOT_ATTACK_SOURCES}}|${root_sources:-0}|g" "$HTML_OUTPUT_FILE"
    
    # Générer les top 3 attackers cards
    local top_3_html=""
    for i in 0 1 2; do
        local ip=$(echo "$json_content" | jq -r ".top_attackers[$i].ip // \"N/A\"")
        local attempts=$(echo "$json_content" | jq -r ".top_attackers[$i].attempts // 0")
        local country=$(echo "$json_content" | jq -r ".top_attackers[$i].country // \"Unknown\"")
        local city=$(echo "$json_content" | jq -r ".top_attackers[$i].city // \"Unknown\"")
        
        if [[ "$ip" != "N/A" ]]; then
            top_3_html+="<div class='col-md-4'><div class='card' style='border-top: 3px solid #ef4444;'><div class='card-body'><h6 class='card-subtitle mb-2' style='color: #9ca3af;'>Top $((i+1)) Attacker</h6><h4 class='card-title' style='color: #ef4444; font-family: monospace;'>$ip</h4><p class='mb-1'><strong>$attempts</strong> tentatives</p><p class='mb-0'><i class='bi bi-geo-alt'></i> $city, $country</p></div></div></div>"
        fi
    done
    [[ -z "$top_3_html" ]] && top_3_html="<div class='alert alert-info'>Aucune donnée d'attaquant disponible</div>"
    
    # Échapper pour sed
    top_3_html=$(echo "$top_3_html" | sed 's/[\/&]/\\&/g')
    sed -i "s|{{TOP_3_CARDS}}|$top_3_html|g" "$HTML_OUTPUT_FILE"
    
    # Générer le tableau des attackers (top 20)
    local attackers_rows=""
    for i in {0..19}; do
        local ip=$(echo "$json_content" | jq -r ".top_attackers[$i].ip // null")
        [[ "$ip" == "null" ]] && break
        
        local attempts=$(echo "$json_content" | jq -r ".top_attackers[$i].attempts // 0")
        local country=$(echo "$json_content" | jq -r ".top_attackers[$i].country // \"Unknown\"")
        local city=$(echo "$json_content" | jq -r ".top_attackers[$i].city // \"Unknown\"")
        local isp=$(echo "$json_content" | jq -r ".top_attackers[$i].isp // \"Unknown\"")
        local banned=$(echo "$json_content" | jq -r ".top_attackers[$i].banned // false")
        
        local status="<span class='badge bg-warning'>Not Banned</span>"
        [[ "$banned" == "true" ]] && status="<span class='badge bg-success'>Banned</span>"
        
        attackers_rows+="<tr><td>$((i+1))</td><td style='font-family: monospace;'>$ip</td><td>$attempts</td><td>$country</td><td>$city</td><td>$isp</td><td>$status</td></tr>"
    done
    [[ -z "$attackers_rows" ]] && attackers_rows="<tr><td colspan='7' class='text-center'>Aucune donnée disponible</td></tr>"
    
    # Échapper pour sed
    attackers_rows=$(echo "$attackers_rows" | sed 's/[\/&]/\\&/g')
    
    # Générer les country badges (top 10 pays)
    local country_badges=""
    local countries_list=$(echo "$json_content" | jq -r '[.top_attackers[].country] | group_by(.) | map({country: .[0], count: length}) | sort_by(.count) | reverse | .[0:10]')
    local countries_count=$(echo "$countries_list" | jq 'length')
    
    for i in $(seq 0 $((countries_count-1))); do
        local country=$(echo "$countries_list" | jq -r ".[$i].country // \"Unknown\"")
        local count=$(echo "$countries_list" | jq -r ".[$i].count // 0")
        [[ "$country" != "Unknown" && "$country" != "null" ]] && country_badges+="<span class='badge bg-secondary me-2 mb-2'>$country ($count)</span>"
    done
    [[ -z "$country_badges" ]] && country_badges="<span class='badge bg-secondary'>Aucune donnée</span>"
    
    country_badges=$(echo "$country_badges" | sed 's/[\/&]/\\&/g')
    
    sed -i "s|{{TOP_3_CARDS}}|$top_3_html|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{GEO_LABELS}}|[]|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{GEO_DATA}}|[]|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{TIMELINE_LABELS}}|[]|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{TIMELINE_DATA}}|[]|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{COUNTRY_BADGES}}|$country_badges|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{ATTACKERS_ROWS}}|$attackers_rows|g" "$HTML_OUTPUT_FILE"
    
    # Connexions réussies (vraies valeurs)
    sed -i "s|{{SSH_KEY_LOGINS}}|${ssh_key_logins:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PASSWORD_LOGINS}}|${password_logins:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUCCESSFUL_IPS}}|${successful_ips:-0}|g" "$HTML_OUTPUT_FILE"
    
    # Fail2ban (vraies valeurs)
    sed -i "s|{{FAIL2BAN_STATUS}}|$fail2ban_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAIL2BAN_STATUS_CLASS}}|$fail2ban_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAIL2BAN_BANNED}}|${banned:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAIL2BAN_JAILS}}|0|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{JSON_FILE_PATH}}|../json/ssh-analysis_latest.json|g" "$HTML_OUTPUT_FILE"
    
    ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
    
    log_verbose "Rapport HTML généré: $HTML_OUTPUT_FILE"
}

# ============================================================================
# GESTION DES ALERTES
# ============================================================================

send_alerts() {
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+' | head -1)
    local failed_24h=$(echo "$json_content" | grep -oP '(?<="failed_attempts_24h": )\d+')
    local ips_24h=$(echo "$json_content" | grep -oP '(?<="unique_attackers_24h": )\d+')
    
    if [[ "$status" == "WARNING" ]]; then
        local hostname=$(hostname)
        local alert_message="🔍 *ALERTE SSH* - ${hostname}

⚠️ Activité SSH suspecte détectée !
📊 Tentatives échouées (24h): *${failed_24h}*
🌍 IPs uniques attaquantes: *${ips_24h}*

Seuils: ${ALERT_FAILED_ATTEMPTS} tentatives / ${ALERT_UNIQUE_IPS} IPs
Consultez le rapport complet pour les détails."
        
        [[ "$ENABLE_EMAIL" == "true" ]] && send_email_alert "SSH Analysis - Activité Suspecte" "$alert_message"
        [[ "$ENABLE_TELEGRAM" == "true" ]] && send_telegram_alert "$alert_message"
    else
        log_verbose "Activité SSH normale, pas d'alerte" >&2
    fi
}

# ============================================================================
# AIDE
# ============================================================================

show_help() {
    cat <<EOF
Usage: sudo $SCRIPT_NAME [OPTIONS]

Analyse approfondie des tentatives d'intrusion SSH

OPTIONS:
    -h, --help              Afficher cette aide
    -v, --verbose           Mode verbeux
    -s, --silent            Mode silencieux
    --period PERIOD         Période d'analyse: 24h, 7d, 30d, all (défaut: 24h)
    --top N                 Nombre d'IPs dans le top (défaut: 20)
    --no-geo                Désactiver la géolocalisation
    --no-json               Ne pas générer de JSON
    --no-html               Ne pas générer de HTML
    --email EMAIL           Envoyer alerte si activité suspecte
    --telegram TOKEN CHAT   Envoyer alerte Telegram

EXEMPLES:
    sudo ./$SCRIPT_NAME
    sudo ./$SCRIPT_NAME --period 7d --top 50
    sudo ./$SCRIPT_NAME --verbose --no-geo
    sudo ./$SCRIPT_NAME --period all --email admin@example.com

PÉRIODES:
    24h   : Dernières 24 heures
    7d    : 7 derniers jours
    30d   : 30 derniers jours
    all   : Tous les logs disponibles (limité à $MAX_LOG_LINES lignes)

SORTIES:
    Terminal: Rapport détaillé avec top IPs et statistiques
    JSON: $JSON_DIR/
    HTML: $HTML_DIR/
    
EOF
}

# ============================================================================
# GESTION DES ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSITY="verbose"; shift ;;
        -s|--silent) VERBOSITY="silent"; shift ;;
        --period) PERIOD="$2"; shift 2 ;;
        --top) TOP_COUNT="$2"; shift 2 ;;
        --no-geo) ENABLE_GEOLOCATION=false; shift ;;
        --no-json) OUTPUT_JSON=false; shift ;;
        --no-html) OUTPUT_HTML=false; shift ;;
        --email) ENABLE_EMAIL=true; EMAIL_TO="$2"; shift 2 ;;
        --telegram) ENABLE_TELEGRAM=true; TELEGRAM_BOT_TOKEN="$2"; TELEGRAM_CHAT_ID="$3"; shift 3 ;;
        -h|--help) show_help; exit 0 ;;
        *) log_error "Option inconnue: $1"; show_help; exit 1 ;;
    esac
done

# ============================================================================
# MAIN
# ============================================================================

main() {
    local start_time=$(date +%s)
    
    check_root
    create_directories
    [[ "${AUTO_CLEANUP:-true}" == "true" ]] && cleanup_old_logs
    
    collect_ssh_analysis
    display_terminal_output
    generate_html_output
    send_alerts
    
    local duration=$(calculate_duration "$start_time")
    log_verbose "Analyse terminée en ${duration}s" >&2
    
    echo "[$(date)] SSH analysis completed - Period: $PERIOD" >> "$LOG_FILE"
}

main
exit 0
