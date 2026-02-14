#!/bin/bash

# Script: vps-health-check.sh
# Description: Vérification complète de la santé du VPS (CPU, RAM, disque, services)
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

# Variables par défaut (si non définies dans config)
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

# Seuils
CPU_WARNING="${CPU_WARNING:-80}"
CPU_CRITICAL="${CPU_CRITICAL:-90}"
RAM_WARNING="${RAM_WARNING:-80}"
RAM_CRITICAL="${RAM_CRITICAL:-90}"
SWAP_WARNING="${SWAP_WARNING:-50}"
SWAP_CRITICAL="${SWAP_CRITICAL:-80}"
DISK_WARNING="${DISK_WARNING:-80}"
DISK_CRITICAL="${DISK_CRITICAL:-90}"

# Fichiers de sortie
LOG_FILE="$LOG_DIR/health-check.log"
JSON_OUTPUT_FILE="$JSON_DIR/health-check_${TIMESTAMP}.json"
JSON_LATEST="$JSON_DIR/health-check_latest.json"
HTML_OUTPUT_FILE="$HTML_DIR/health-check_${TIMESTAMP}.html"
HTML_LATEST="$HTML_DIR/health-check_latest.html"

# ============================================================================
# FONCTIONS SPÉCIFIQUES
# ============================================================================

# Fonction: get_uptime_info
# Description: Récupère les informations d'uptime et load average
get_uptime_info() {
    local uptime_raw=$(uptime)
    local uptime_days=$(echo "$uptime_raw" | grep -oP '\d+(?= days)' || echo "0")
    local uptime_hours=$(echo "$uptime_raw" | grep -oP '\d+:\d+' | head -1 | cut -d: -f1)
    local uptime_minutes=$(echo "$uptime_raw" | grep -oP '\d+:\d+' | head -1 | cut -d: -f2)
    
    # Load average
    local load_1=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | xargs)
    local load_5=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $2}' | xargs)
    local load_15=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $3}' | xargs)
    
    echo "{\"days\":$uptime_days,\"hours\":${uptime_hours:-0},\"minutes\":${uptime_minutes:-0},\"load_1\":${load_1},\"load_5\":${load_5},\"load_15\":${load_15}}"
}

# Fonction: get_cpu_info
# Description: Récupère les informations CPU
get_cpu_info() {
    local cpu_count=$(nproc)
    
    # Utilisation CPU (moyenne sur 1 seconde)
    local cpu_usage=$(top -bn2 -d 0.5 | grep '^%Cpu' | tail -1 | awk '{print 100-$8}' | cut -d. -f1)
    
    # Température CPU (si disponible)
    local cpu_temp="N/A"
    if command -v sensors &> /dev/null; then
        cpu_temp=$(sensors 2>/dev/null | grep -i 'Core 0\|Package id 0' | awk '{print $3}' | head -1 | tr -d '+°C' || echo "N/A")
    fi
    
    echo "{\"count\":$cpu_count,\"usage\":${cpu_usage:-0},\"temperature\":\"$cpu_temp\"}"
}

# Fonction: get_memory_info
# Description: Récupère les informations mémoire
get_memory_info() {
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    local mem_used=$(free -m | awk '/^Mem:/{print $3}')
    local mem_free=$(free -m | awk '/^Mem:/{print $4}')
    local mem_available=$(free -m | awk '/^Mem:/{print $7}')
    local mem_percent=$(calculate_percentage "$mem_used" "$mem_total")
    
    # SWAP
    local swap_total=$(free -m | awk '/^Swap:/{print $2}')
    local swap_used=$(free -m | awk '/^Swap:/{print $3}')
    local swap_free=$(free -m | awk '/^Swap:/{print $4}')
    local swap_percent=0
    [[ $swap_total -gt 0 ]] && swap_percent=$(calculate_percentage "$swap_used" "$swap_total")
    
    echo "{\"ram\":{\"total\":$mem_total,\"used\":$mem_used,\"free\":$mem_free,\"available\":$mem_available,\"percent\":$mem_percent},\"swap\":{\"total\":$swap_total,\"used\":$swap_used,\"free\":$swap_free,\"percent\":$swap_percent}}"
}

# Fonction: get_disk_info
# Description: Récupère les informations disque
get_disk_info() {
    local disk_info="["
    local first=true
    
    # Lister toutes les partitions montées (sauf tmpfs, devtmpfs, etc.)
    while IFS= read -r line; do
        local filesystem=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local available=$(echo "$line" | awk '{print $4}')
        local percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mountpoint=$(echo "$line" | awk '{print $6}')
        
        [[ "$first" == "false" ]] && disk_info+=","
        disk_info+="{\"filesystem\":\"$filesystem\",\"size\":\"$size\",\"used\":\"$used\",\"available\":\"$available\",\"percent\":$percent,\"mountpoint\":\"$mountpoint\"}"
        first=false
    done < <(df -h | grep -E '^/dev/' | grep -v '/boot')
    
    disk_info+="]"
    echo "$disk_info"
}

# Fonction: get_service_status
# Description: Vérifie le statut des services critiques
get_service_status() {
    local services=("sshd" "cron" "fail2ban")
    local service_info="["
    local first=true
    
    for service in "${services[@]}"; do
        local status="unknown"
        local is_active=false
        local service_name="$service"
        
        # Sur Ubuntu, SSH peut s'appeler 'ssh' au lieu de 'sshd'
        if [[ "$service" == "sshd" ]]; then
            if systemctl list-unit-files | grep -q "^ssh.service"; then
                service_name="ssh"
            fi
        fi
        
        # Vérifier si le service existe
        if systemctl list-unit-files 2>/dev/null | grep -q "^${service_name}.service\|^${service_name}$"; then
            if systemctl is-active --quiet "$service_name" 2>/dev/null; then
                status="active"
                is_active=true
            else
                status="inactive"
            fi
        else
            # Service non trouvé
            if [[ "$service" == "fail2ban" ]]; then
                # Vérifier si fail2ban est installé mais pas en tant que service systemd
                if command -v fail2ban-client &>/dev/null; then
                    status="inactive"
                else
                    status="not_installed"
                fi
            else
                status="not_found"
            fi
        fi
        
        [[ "$first" == "false" ]] && service_info+=","
        service_info+="{\"name\":\"$service\",\"status\":\"$status\",\"active\":$is_active}"
        first=false
    done
    
    service_info+="]"
    echo "$service_info"
}

# Fonction: get_network_info
# Description: Récupère les informations réseau
get_network_info() {
    # Compter les connexions ESTABLISHED
    local established=$(ss -tunH state established 2>/dev/null | wc -l)
    
    # Compter les connexions LISTEN
    local listening=$(ss -tunlH 2>/dev/null | wc -l)
    
    # Compter les connexions TIME_WAIT
    local time_wait=$(ss -tunH state time-wait 2>/dev/null | wc -l)
    
    echo "{\"established\":$established,\"listening\":$listening,\"time_wait\":$time_wait}"
}

# Fonction: get_process_info
# Description: Récupère les informations sur les processus
get_process_info() {
    local total_processes=$(ps aux | wc -l)
    local zombie_processes=$(ps aux | awk '{print $8}' | grep -c 'Z' || echo "0")
    local running_processes=$(ps aux | awk '{print $8}' | grep -c 'R' || echo "0")
    
    echo "{\"total\":$total_processes,\"zombies\":$zombie_processes,\"running\":$running_processes}"
}

# Fonction: get_last_update
# Description: Récupère la date de dernière mise à jour système
get_last_update() {
    local last_update="Unknown"
    
    if [[ -f /var/log/apt/history.log ]]; then
        last_update=$(grep -i "Start-Date" /var/log/apt/history.log | tail -1 | awk -F: '{print $2":"$3":"$4}' | xargs || echo "Unknown")
    fi
    
    echo "\"$last_update\""
}

# ============================================================================
# FONCTION PRINCIPALE DE COLLECTE
# ============================================================================

collect_health_data() {
    log_verbose "Collecte des données de santé du système..."
    
    local start_time=$(date +%s)
    local hostname=$(hostname)
    
    # Collecter toutes les informations
    local uptime_data=$(get_uptime_info)
    local cpu_data=$(get_cpu_info)
    local memory_data=$(get_memory_info)
    local disk_data=$(get_disk_info)
    local service_data=$(get_service_status)
    local network_data=$(get_network_info)
    local process_data=$(get_process_info)
    local last_update=$(get_last_update)
    
    # Calculer le statut global et compter les alertes
    local status="OK"
    local critical_count=0
    local warning_count=0
    local alerts="["
    local first_alert=true
    
    # Extraire les valeurs pour les vérifications
    local cpu_usage=$(echo "$cpu_data" | grep -oP '(?<="usage":)\d+')
    local ram_percent=$(echo "$memory_data" | grep -oP '(?<="percent":)\d+' | head -1)
    local swap_percent=$(echo "$memory_data" | grep -oP '(?<="percent":)\d+' | tail -1)
    
    # Vérifier CPU
    if [[ $cpu_usage -ge $CPU_CRITICAL ]]; then
        status="CRITICAL"
        critical_count=$((critical_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"critical\",\"category\":\"cpu\",\"message\":\"CPU usage critical\",\"value\":$cpu_usage,\"threshold\":$CPU_CRITICAL}"
        first_alert=false
    elif [[ $cpu_usage -ge $CPU_WARNING ]]; then
        [[ "$status" == "OK" ]] && status="WARNING"
        warning_count=$((warning_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"warning\",\"category\":\"cpu\",\"message\":\"CPU usage high\",\"value\":$cpu_usage,\"threshold\":$CPU_WARNING}"
        first_alert=false
    fi
    
    # Vérifier RAM
    if [[ $ram_percent -ge $RAM_CRITICAL ]]; then
        status="CRITICAL"
        critical_count=$((critical_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"critical\",\"category\":\"ram\",\"message\":\"RAM usage critical\",\"value\":$ram_percent,\"threshold\":$RAM_CRITICAL}"
        first_alert=false
    elif [[ $ram_percent -ge $RAM_WARNING ]]; then
        [[ "$status" == "OK" ]] && status="WARNING"
        warning_count=$((warning_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"warning\",\"category\":\"ram\",\"message\":\"RAM usage high\",\"value\":$ram_percent,\"threshold\":$RAM_WARNING}"
        first_alert=false
    fi
    
    # Vérifier SWAP
    if [[ $swap_percent -ge $SWAP_CRITICAL ]]; then
        status="CRITICAL"
        critical_count=$((critical_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"critical\",\"category\":\"swap\",\"message\":\"SWAP usage critical\",\"value\":$swap_percent,\"threshold\":$SWAP_CRITICAL}"
        first_alert=false
    elif [[ $swap_percent -ge $SWAP_WARNING ]]; then
        [[ "$status" == "OK" ]] && status="WARNING"
        warning_count=$((warning_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"warning\",\"category\":\"swap\",\"message\":\"SWAP usage high\",\"value\":$swap_percent,\"threshold\":$SWAP_WARNING}"
        first_alert=false
    fi
    
    # Vérifier disques
    while read -r percent mountpoint; do
        if [[ $percent -ge $DISK_CRITICAL ]]; then
            status="CRITICAL"
            critical_count=$((critical_count + 1))
            [[ "$first_alert" == "false" ]] && alerts+=","
            alerts+="{\"level\":\"critical\",\"category\":\"disk\",\"message\":\"Disk usage critical on $mountpoint\",\"value\":$percent,\"threshold\":$DISK_CRITICAL}"
            first_alert=false
        elif [[ $percent -ge $DISK_WARNING ]]; then
            [[ "$status" == "OK" ]] && status="WARNING"
            warning_count=$((warning_count + 1))
            [[ "$first_alert" == "false" ]] && alerts+=","
            alerts+="{\"level\":\"warning\",\"category\":\"disk\",\"message\":\"Disk usage high on $mountpoint\",\"value\":$percent,\"threshold\":$DISK_WARNING}"
            first_alert=false
        fi
    done < <(df -h | grep -E '^/dev/' | awk '{print $5" "$6}' | tr -d '%')
    
    # Vérifier processus zombies
    local zombie_count=$(echo "$process_data" | grep -oP '(?<="zombies":)\d+')
    if [[ $zombie_count -gt 0 ]]; then
        [[ "$status" == "OK" ]] && status="WARNING"
        warning_count=$((warning_count + 1))
        [[ "$first_alert" == "false" ]] && alerts+=","
        alerts+="{\"level\":\"warning\",\"category\":\"processes\",\"message\":\"Zombie processes detected\",\"value\":$zombie_count,\"threshold\":0}"
        first_alert=false
    fi
    
    alerts+="]"
    
    local duration=$(calculate_duration "$start_time")
    
    # Générer le JSON complet
    cat > "$JSON_OUTPUT_FILE" <<EOF
{
  "metadata": {
    "script": "vps-health-check",
    "version": "$VERSION",
    "timestamp": "$(get_iso_timestamp)",
    "hostname": "$hostname",
    "duration_seconds": $duration
  },
  "summary": {
    "status": "$status",
    "critical_issues": $critical_count,
    "warnings": $warning_count,
    "info": 0
  },
  "data": {
    "uptime": $uptime_data,
    "cpu": $cpu_data,
    "memory": $memory_data,
    "disks": $disk_data,
    "services": $service_data,
    "network": $network_data,
    "processes": $process_data,
    "last_update": $last_update
  },
  "alerts": $alerts
}
EOF
    
    # Créer un lien symbolique vers latest
    ln -sf "$JSON_OUTPUT_FILE" "$JSON_LATEST"
    
    log_verbose "Données collectées et JSON généré: $JSON_OUTPUT_FILE"
}

# ============================================================================
# AFFICHAGE TERMINAL
# ============================================================================

display_terminal_output() {
    [[ "$OUTPUT_TERMINAL" != "true" ]] && return
    [[ "$VERBOSITY" == "silent" ]] && return
    
    log_verbose "Génération de la sortie terminal..."
    
    # Lire le JSON
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    # Extraire les données
    local hostname=$(echo "$json_content" | grep -oP '(?<="hostname": ")[^"]+')
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+')
    local cpu_usage=$(echo "$json_content" | grep -oP '(?<="usage":)\d+' | head -1)
    local ram_percent=$(echo "$json_content" | grep -oP '"ram".*?"percent":\d+' | grep -oP '\d+$')
    local swap_percent=$(echo "$json_content" | grep -oP '"swap".*?"percent":\d+' | grep -oP '\d+$')
    
    print_header "🏥 VPS Health Check Report"
    
    # Statut global
    print_section "📊 Statut Global"
    local status_display="$status"
    local status_color="${GREEN}"
    [[ "$status" == "WARNING" ]] && status_color="${YELLOW}"
    [[ "$status" == "CRITICAL" ]] && status_color="${RED}"
    echo -e "  Serveur: ${BOLD}$hostname${NC}"
    echo -e "  Statut: ${status_color}${BOLD}$status${NC}"
    echo
    
    # Uptime et Load
    print_section "⏱️  Uptime & Load Average"
    local uptime_days=$(echo "$json_content" | grep -oP '(?<="days":)\d+')
    local load_1=$(echo "$json_content" | grep -oP '(?<="load_1":)[0-9.]+')
    echo -e "  Uptime: ${BOLD}${uptime_days} jours${NC}"
    echo -e "  Load Average: ${BOLD}${load_1}${NC} (1min)"
    echo
    
    # CPU
    print_section "💻 CPU"
    local cpu_count=$(echo "$json_content" | grep -oP '(?<="count":)\d+' | head -1)
    local cpu_temp=$(echo "$json_content" | grep -oP '(?<="temperature":")[^"]+')
    print_table_row "Nombre de cœurs" "$cpu_count" "INFO"
    print_table_row "Utilisation" "${cpu_usage}%" "$(get_status_from_value $cpu_usage $CPU_WARNING $CPU_CRITICAL)"
    if [[ "$cpu_temp" != "N/A" ]]; then
        print_table_row "Température" "${cpu_temp}°C" "INFO"
    else
        print_table_row "Température" "Non disponible" "INFO"
    fi
    print_progress_bar "$cpu_usage" "100"
    echo
    
    # Mémoire
    print_section "🧠 Mémoire"
    local ram_used=$(echo "$json_content" | grep -oP '"ram".*?"used":\d+' | grep -oP '\d+$')
    local ram_total=$(echo "$json_content" | grep -oP '"ram".*?"total":\d+' | grep -oP '\d+$')
    print_table_row "RAM utilisée" "${ram_used}MB / ${ram_total}MB (${ram_percent}%)" "$(get_status_from_value $ram_percent $RAM_WARNING $RAM_CRITICAL)"
    print_progress_bar "$ram_percent" "100"
    
    if [[ $swap_percent -gt 0 ]]; then
        local swap_used=$(echo "$json_content" | grep -oP '"swap".*?"used":\d+' | grep -oP '\d+$')
        local swap_total=$(echo "$json_content" | grep -oP '"swap".*?"total":\d+' | grep -oP '\d+$')
        print_table_row "SWAP utilisé" "${swap_used}MB / ${swap_total}MB (${swap_percent}%)" "$(get_status_from_value $swap_percent $SWAP_WARNING $SWAP_CRITICAL)"
        print_progress_bar "$swap_percent" "100"
    fi
    echo
    
    # Disques
    print_section "💾 Espace Disque"
    # Parser les disques du JSON
    local disk_count=$(echo "$json_content" | grep -o '"filesystem"' | wc -l)
    if [[ $disk_count -gt 0 ]]; then
        # Extraire chaque disque (méthode plus robuste)
        local disk_data=$(echo "$json_content" | grep -A5 '"disks":' | grep -oP '\{"filesystem":[^}]+\}')
        
        while IFS= read -r disk_line; do
            if [[ -n "$disk_line" ]]; then
                local filesystem=$(echo "$disk_line" | grep -oP '(?<="filesystem":")[^"]+' || echo "N/A")
                local mountpoint=$(echo "$disk_line" | grep -oP '(?<="mountpoint":")[^"]+' || echo "N/A")
                local percent=$(echo "$disk_line" | grep -oP '(?<="percent":)\d+' || echo "0")
                local used=$(echo "$disk_line" | grep -oP '(?<="used":")[^"]+' || echo "N/A")
                local size=$(echo "$disk_line" | grep -oP '(?<="size":")[^"]+' || echo "N/A")
                
                print_table_row "$mountpoint" "${used} / ${size} (${percent}%)" "$(get_status_from_value $percent $DISK_WARNING $DISK_CRITICAL)"
                print_progress_bar "$percent" "100"
            fi
        done < <(echo "$json_content" | grep -oP '\{"filesystem":"[^}]+\}')
    else
        print_table_row "Aucun disque" "N/A" "INFO"
    fi
    echo
    
    # Services
    print_section "🔧 Services Critiques"
    # Parser les services du JSON
    local service_data=$(echo "$json_content" | grep -A10 '"services":')
    
    while IFS= read -r service_line; do
        if [[ -n "$service_line" ]]; then
            local service_name=$(echo "$service_line" | grep -oP '(?<="name":")[^"]+' || echo "unknown")
            local service_status=$(echo "$service_line" | grep -oP '(?<="status":")[^"]+' || echo "unknown")
            local display_status="$service_status"
            local status_type="INFO"
            
            if [[ "$service_status" == "active" ]]; then
                display_status="✓ Active"
                status_type="OK"
            elif [[ "$service_status" == "inactive" ]]; then
                display_status="✗ Inactive"
                status_type="CRITICAL"
            elif [[ "$service_status" == "not_installed" ]]; then
                display_status="⚠ Non installé"
                status_type="WARNING"
            elif [[ "$service_status" == "not_found" ]]; then
                display_status="✗ Non trouvé"
                status_type="CRITICAL"
            fi
            
            print_table_row "$service_name" "$display_status" "$status_type"
        fi
    done < <(echo "$json_content" | grep -oP '\{"name":"[^}]+\}')
    echo
    
    # Réseau
    print_section "🌐 Connexions Réseau"
    local established=$(echo "$json_content" | grep -oP '(?<="established":)\d+')
    local listening=$(echo "$json_content" | grep -oP '(?<="listening":)\d+')
    print_table_row "Connexions établies" "$established" "INFO"
    print_table_row "Ports en écoute" "$listening" "INFO"
    echo
    
    # Processus
    print_section "⚙️  Processus"
    local total_proc=$(echo "$json_content" | grep -oP '"processes".*?"total":\d+' | grep -oP '\d+$')
    local zombie_proc=$(echo "$json_content" | grep -oP '"processes".*?"zombies":\d+' | grep -oP '\d+$')
    print_table_row "Total processus" "$total_proc" "INFO"
    print_table_row "Processus zombies" "$zombie_proc" "$(get_status_from_value $zombie_proc 1 5)"
    echo
    
    # Footer
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "📁 Rapports:"
    echo -e "   JSON: ${BLUE}$JSON_OUTPUT_FILE${NC}"
    [[ "$OUTPUT_HTML" == "true" ]] && echo -e "   HTML: ${BLUE}$HTML_OUTPUT_FILE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# Fonction helper pour déterminer le statut
get_status_from_value() {
    local value=$1
    local warning=$2
    local critical=$3
    
    if [[ $value -ge $critical ]]; then
        echo "CRITICAL"
    elif [[ $value -ge $warning ]]; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# ============================================================================
# GÉNÉRATION HTML
# ============================================================================

generate_html_output() {
    [[ "$OUTPUT_HTML" != "true" ]] && return
    
    log_verbose "Génération du rapport HTML..."
    
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    local hostname=$(echo "$json_content" | grep -oP '(?<="hostname": ")[^"]+')
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+')
    
    # Déterminer la couleur du statut
    local status_class="success"
    [[ "$status" == "WARNING" ]] && status_class="warning"
    [[ "$status" == "CRITICAL" ]] && status_class="danger"
    
    # Générer le HTML
    {
        generate_html_header "Health Check - $hostname"
        
        cat <<'HTMLBODY'
        <!-- Status Overview -->
        <div class="row mb-4">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-body text-center">
                        <h2 class="mb-3">Statut Global</h2>
                        <h1><span class="status-badge status-STATUS_CLASS">STATUS_VALUE</span></h1>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Metrics Cards -->
        <div class="row mb-4">
            <div class="col-md-3">
                <div class="card metric-card bg-primary text-white">
                    <div class="metric-label">CPU Usage</div>
                    <div class="metric-value">CPU_VALUE%</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card metric-card bg-info text-white">
                    <div class="metric-label">RAM Usage</div>
                    <div class="metric-value">RAM_VALUE%</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card metric-card bg-warning text-dark">
                    <div class="metric-label">Disk Usage</div>
                    <div class="metric-value">DISK_VALUE%</div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card metric-card bg-success text-white">
                    <div class="metric-label">Uptime</div>
                    <div class="metric-value">UPTIME_VALUE days</div>
                </div>
            </div>
        </div>
        
        <!-- Detailed Information -->
        <div class="row">
            <div class="col-md-6 mb-4">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <h5 class="mb-0"><i class="fas fa-microchip"></i> CPU & Memory</h5>
                    </div>
                    <div class="card-body">
                        <table class="table table-sm">
                            <tr><th>CPU Cores</th><td>CPU_COUNT</td></tr>
                            <tr><th>CPU Usage</th><td><div class="progress progress-custom"><div class="progress-bar CPU_PROGRESS_COLOR" style="width: CPU_VALUE%">CPU_VALUE%</div></div></td></tr>
                            <tr><th>RAM Used</th><td>RAM_USED MB / RAM_TOTAL MB</td></tr>
                            <tr><th>RAM Usage</th><td><div class="progress progress-custom"><div class="progress-bar RAM_PROGRESS_COLOR" style="width: RAM_VALUE%">RAM_VALUE%</div></div></td></tr>
                            <tr><th>SWAP Used</th><td>SWAP_USED MB / SWAP_TOTAL MB</td></tr>
                        </table>
                    </div>
                </div>
            </div>
            
            <div class="col-md-6 mb-4">
                <div class="card">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0"><i class="fas fa-server"></i> System Info</h5>
                    </div>
                    <div class="card-body">
                        <table class="table table-sm">
                            <tr><th>Hostname</th><td>HOSTNAME_VALUE</td></tr>
                            <tr><th>Uptime</th><td>UPTIME_VALUE days</td></tr>
                            <tr><th>Load Average</th><td>LOAD_VALUE</td></tr>
                            <tr><th>Total Processes</th><td>PROCESS_TOTAL</td></tr>
                            <tr><th>Zombie Processes</th><td>ZOMBIE_COUNT</td></tr>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Services Status -->
        <div class="row mb-4">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-header bg-info text-white">
                        <h5 class="mb-0"><i class="fas fa-cogs"></i> Services Status</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-custom">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Service</th>
                                        <th>Status</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    SERVICES_ROWS
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Disk Usage -->
        <div class="row mb-4">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-header bg-warning text-dark">
                        <h5 class="mb-0"><i class="fas fa-hdd"></i> Disk Usage</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-custom">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Mount Point</th>
                                        <th>Filesystem</th>
                                        <th>Size</th>
                                        <th>Used</th>
                                        <th>Available</th>
                                        <th>Usage</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    DISKS_ROWS
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
HTMLBODY
        
        # Remplacer les placeholders
        sed -i "s/STATUS_CLASS/$status_class/g" "$HTML_OUTPUT_FILE"
        sed -i "s/STATUS_VALUE/$status/g" "$HTML_OUTPUT_FILE"
        
        # Extraire et remplacer les valeurs
        local cpu_value=$(echo "$json_content" | grep -oP '(?<="usage":)\d+' | head -1)
        local ram_value=$(echo "$json_content" | grep -oP '"ram".*?"percent":\d+' | grep -oP '\d+$')
        local uptime_days=$(echo "$json_content" | grep -oP '(?<="days":)\d+')
        
        sed -i "s/CPU_VALUE/$cpu_value/g" "$HTML_OUTPUT_FILE"
        sed -i "s/RAM_VALUE/$ram_value/g" "$HTML_OUTPUT_FILE"
        sed -i "s/UPTIME_VALUE/$uptime_days/g" "$HTML_OUTPUT_FILE"
        
        # TODO: Compléter avec toutes les autres valeurs dynamiques
        
        generate_html_footer
        
    } > "$HTML_OUTPUT_FILE"
    
    ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
    
    log_verbose "HTML généré: $HTML_OUTPUT_FILE"
}

# ============================================================================
# GESTION DES ALERTES
# ============================================================================

send_alerts() {
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+')
    local critical_count=$(echo "$json_content" | grep -oP '(?<="critical_issues": )\d+')
    local warning_count=$(echo "$json_content" | grep -oP '(?<="warnings": )\d+')
    
    # N'envoyer des alertes que si WARNING ou CRITICAL
    if [[ "$status" == "OK" ]]; then
        log_verbose "Statut OK, pas d'alerte à envoyer"
        return
    fi
    
    local hostname=$(hostname)
    local alert_message="⚠️ *${status}* sur ${hostname}

🔴 Problèmes critiques: ${critical_count}
🟡 Avertissements: ${warning_count}

Consultez le rapport complet pour plus de détails."
    
    # Envoyer email
    if [[ "$ENABLE_EMAIL" == "true" ]]; then
        send_email_alert "Health Check ${status}" "$alert_message"
    fi
    
    # Envoyer Telegram
    if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
        send_telegram_alert "$alert_message"
    fi
}

# ============================================================================
# AIDE
# ============================================================================

show_help() {
    cat <<EOF
Usage: sudo $SCRIPT_NAME [OPTIONS]

Vérification complète de la santé du VPS (CPU, RAM, disque, services)

OPTIONS:
    -h, --help              Afficher cette aide
    -v, --verbose           Mode verbeux (plus de détails)
    -s, --silent            Mode silencieux (pas de sortie terminal)
    --no-json               Ne pas générer de fichier JSON
    --no-html               Ne pas générer de rapport HTML
    --email EMAIL           Envoyer une alerte par email
    --telegram TOKEN CHAT   Envoyer une alerte Telegram

EXEMPLES:
    # Exécution basique
    sudo ./$SCRIPT_NAME
    
    # Mode verbose avec alertes
    sudo ./$SCRIPT_NAME --verbose --email admin@example.com
    
    # Mode silencieux, JSON uniquement
    sudo ./$SCRIPT_NAME --silent --no-html

SORTIES:
    Terminal:  Rapport formaté avec codes couleur
    JSON:      $JSON_DIR/
    HTML:      $HTML_DIR/
    Logs:      $LOG_FILE

Pour plus d'informations, consultez la documentation.
EOF
}

# ============================================================================
# GESTION DES ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSITY="verbose"
            shift
            ;;
        -s|--silent)
            VERBOSITY="silent"
            shift
            ;;
        --no-json)
            OUTPUT_JSON=false
            shift
            ;;
        --no-html)
            OUTPUT_HTML=false
            shift
            ;;
        --email)
            ENABLE_EMAIL=true
            EMAIL_TO="$2"
            shift 2
            ;;
        --telegram)
            ENABLE_TELEGRAM=true
            TELEGRAM_BOT_TOKEN="$2"
            TELEGRAM_CHAT_ID="$3"
            shift 3
            ;;
        -h|--help)
            show_help
            exit 0
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
    local start_time=$(date +%s)
    
    # Vérifications préliminaires
    check_root
    create_directories
    
    # Nettoyage automatique si activé
    [[ "${AUTO_CLEANUP:-true}" == "true" ]] && cleanup_old_logs
    
    # Collecte des données
    collect_health_data
    
    # Générer les sorties
    display_terminal_output
    generate_html_output
    
    # Envoyer les alertes si nécessaire
    send_alerts
    
    # Durée totale
    local duration=$(calculate_duration "$start_time")
    log_verbose "Exécution terminée en ${duration}s"
    
    # Log dans le fichier
    echo "[$(date)] Health check completed - Status: $(grep '"status"' "$JSON_OUTPUT_FILE" | head -1 | awk -F'"' '{print $4}')" >> "$LOG_FILE"
}

# Exécuter le script
main

exit 0
