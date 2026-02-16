#!/bin/bash

# Script: vps-intrusion-check.sh
# Description: Détection d'intrusion et vérification d'intégrité système
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
LOG_FILE="$LOG_DIR/intrusion-check.log"
JSON_OUTPUT_FILE="$JSON_DIR/intrusion-check_${TIMESTAMP}.json"
JSON_LATEST="$JSON_DIR/intrusion-check_latest.json"
HTML_OUTPUT_FILE="$HTML_DIR/intrusion-check_${TIMESTAMP}.html"
HTML_LATEST="$HTML_DIR/intrusion-check_latest.html"

# Seuils et configurations
MAX_SUSPICIOUS_PROCS="${MAX_SUSPICIOUS_PROCS:-5}"
CHECK_LAST_HOURS="${CHECK_LAST_HOURS:-24}"
SUSPICIOUS_PROC_NAMES="${SUSPICIOUS_PROC_NAMES:-xmrig,minerd,cgminer,bfgminer,ethminer,nanopool,nicehash,stratum,cryptonight,monero}"

# Compteurs globaux
CRITICAL_COUNT=0
WARNING_COUNT=0
SUSPICIOUS_COUNT=0

# ============================================================================
# FONCTIONS DE DÉTECTION - SESSIONS SSH
# ============================================================================

check_active_sessions() {
    log_verbose "Vérification des sessions SSH actives..." >&2
    
    local sessions="["
    local first=true
    local session_count=0
    local suspicious=0
    
    # Récupérer les sessions actives
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        session_count=$((session_count + 1))
        
        local user=$(echo "$line" | awk '{print $1}')
        local pts=$(echo "$line" | awk '{print $2}')
        local from=$(echo "$line" | awk '{print $3}')
        local login_time=$(echo "$line" | awk '{print $4, $5, $6, $7}')
        
        # Détecter sessions suspectes
        local is_suspicious=false
        local reason=""
        
        # Session root
        if [[ "$user" == "root" ]]; then
            is_suspicious=true
            reason="Root login"
            suspicious=$((suspicious + 1))
        fi
        
        # IP non standard (pas d'IP locale)
        if [[ ! "$from" =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.) ]]; then
            # OK, connexion externe normale
            :
        fi
        
        [[ "$first" == "false" ]] && sessions+=","
        sessions+="{\"user\":\"$user\",\"terminal\":\"$pts\",\"from\":\"$from\",\"login_time\":\"$login_time\",\"suspicious\":$is_suspicious,\"reason\":\"$reason\"}"
        first=false
        
    done < <(who | grep -v "^$")
    
    sessions+="]"
    
    [[ $suspicious -gt 0 ]] && WARNING_COUNT=$((WARNING_COUNT + 1))
    
    echo "{\"total\":$session_count,\"suspicious\":$suspicious,\"sessions\":$sessions}"
}

# ============================================================================
# FONCTIONS DE DÉTECTION - PROCESSUS SUSPECTS
# ============================================================================

check_suspicious_processes() {
    log_verbose "Analyse des processus suspects..." >&2
    
    local suspicious_list="["
    local first=true
    local found=0
    
    # Convertir la liste de noms en array
    IFS=',' read -ra PROC_NAMES <<< "$SUSPICIOUS_PROC_NAMES"
    
    for proc_name in "${PROC_NAMES[@]}"; do
        local pids=$(pgrep -i "$proc_name" 2>/dev/null)
        
        if [[ -n "$pids" ]]; then
            for pid in $pids; do
                found=$((found + 1))
                
                local cmd=$(ps -p "$pid" -o cmd= 2>/dev/null | head -c 100)
                local user=$(ps -p "$pid" -o user= 2>/dev/null)
                local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | xargs)
                local mem=$(ps -p "$pid" -o %mem= 2>/dev/null | xargs)
                
                [[ "$first" == "false" ]] && suspicious_list+=","
                suspicious_list+="{\"pid\":$pid,\"name\":\"$proc_name\",\"user\":\"$user\",\"cpu\":\"$cpu\",\"mem\":\"$mem\",\"cmd\":\"$(json_escape "$cmd")\"}"
                first=false
            done
        fi
    done
    
    # Processus avec CPU > 80% (potentiel miner)
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        local pid=$(echo "$line" | awk '{print $1}')
        local cpu=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf $i" "; print ""}' | head -c 100)
        local user=$(ps -p "$pid" -o user= 2>/dev/null)
        
        # Vérifier si déjà dans la liste
        if ! echo "$suspicious_list" | grep -q "\"pid\":$pid"; then
            found=$((found + 1))
            
            [[ "$first" == "false" ]] && suspicious_list+=","
            suspicious_list+="{\"pid\":$pid,\"name\":\"high-cpu\",\"user\":\"$user\",\"cpu\":\"$cpu\",\"mem\":\"0\",\"cmd\":\"$(json_escape "$cmd")\"}"
            first=false
        fi
    done < <(ps aux | awk '$3 > 80 {print $2, $3, $0}' | tail -5)
    
    suspicious_list+="]"
    
    [[ $found -gt 0 ]] && CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    
    echo "{\"found\":$found,\"processes\":$suspicious_list}"
}

# ============================================================================
# FONCTIONS DE DÉTECTION - PORTS OUVERTS
# ============================================================================

check_listening_ports() {
    log_verbose "Vérification des ports ouverts..." >&2
    
    local ports="["
    local first=true
    local port_count=0
    local suspicious=0
    
    # Ports standards connus
    local known_ports="22 80 443 25 587 993 995 3306 5432 6379 27017"
    
    while IFS= read -r line; do
        if [[ -z "$line" || "$line" =~ ^Proto ]]; then
            continue
        fi
        
        port_count=$((port_count + 1))
        
        local proto=$(echo "$line" | awk '{print $1}')
        local local_addr=$(echo "$line" | awk '{print $4}')
        local port=$(echo "$local_addr" | rev | cut -d: -f1 | rev)
        local state=$(echo "$line" | awk '{print $6}')
        local program=$(echo "$line" | awk '{print $7}' | cut -d'/' -f2)
        
        # Détecter ports suspects
        local is_suspicious=false
        if [[ ! " $known_ports " =~ " $port " ]]; then
            # Port non standard, mais pas forcément suspect
            if [[ $port -gt 10000 || $port -lt 1024 ]]; then
                is_suspicious=true
                suspicious=$((suspicious + 1))
            fi
        fi
        
        [[ "$first" == "false" ]] && ports+=","
        ports+="{\"port\":\"$port\",\"protocol\":\"$proto\",\"address\":\"$local_addr\",\"state\":\"$state\",\"program\":\"$program\",\"suspicious\":$is_suspicious}"
        first=false
        
    done < <(ss -tulnp 2>/dev/null | grep LISTEN)
    
    ports+="]"
    
    [[ $suspicious -gt 3 ]] && WARNING_COUNT=$((WARNING_COUNT + 1))
    
    echo "{\"total\":$port_count,\"suspicious\":$suspicious,\"ports\":$ports}"
}

# ============================================================================
# FONCTIONS DE DÉTECTION - FICHIERS SUID
# ============================================================================

check_suid_files() {
    log_verbose "Recherche de fichiers SUID suspects..." >&2
    
    local suid_files="["
    local first=true
    local found=0
    local suspicious=0
    
    # Liste de fichiers SUID légitimes courants
    local known_suid="sudo su passwd ping mount umount fusermount chsh chfn gpasswd newgrp pkexec"
    
    # Chercher fichiers SUID dans des répertoires critiques
    local search_paths="/usr/bin /usr/sbin /bin /sbin /tmp /var/tmp /dev/shm"
    
    for path in $search_paths; do
        if [[ ! -d "$path" ]]; then
            continue
        fi
        
        while IFS= read -r file; do
            if [[ -z "$file" ]]; then
                continue
            fi
            
            found=$((found + 1))
            
            local basename=$(basename "$file")
            local owner=$(stat -c '%U' "$file" 2>/dev/null)
            local perms=$(stat -c '%a' "$file" 2>/dev/null)
            
            # Vérifier si suspect
            local is_suspicious=false
            
            # Fichier SUID dans /tmp, /var/tmp, /dev/shm = TRÈS SUSPECT
            if [[ "$path" =~ ^(/tmp|/var/tmp|/dev/shm) ]]; then
                is_suspicious=true
                suspicious=$((suspicious + 1))
                CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
            # Fichier SUID non connu
            elif [[ ! " $known_suid " =~ " $basename " ]]; then
                is_suspicious=true
                suspicious=$((suspicious + 1))
            fi
            
            [[ "$first" == "false" ]] && suid_files+=","
            suid_files+="{\"path\":\"$file\",\"owner\":\"$owner\",\"permissions\":\"$perms\",\"suspicious\":$is_suspicious}"
            first=false
            
            # Limiter à 50 fichiers pour éviter JSON trop gros
            [[ $found -ge 50 ]] && break 2
            
        done < <(find "$path" -maxdepth 2 -type f -perm -4000 2>/dev/null)
    done
    
    suid_files+="]"
    
    echo "{\"found\":$found,\"suspicious\":$suspicious,\"files\":$suid_files}"
}

# ============================================================================
# FONCTIONS DE DÉTECTION - MODIFICATIONS SYSTÈME
# ============================================================================

check_system_modifications() {
    log_verbose "Vérification des modifications système récentes..." >&2
    
    local modifications="["
    local first=true
    local mod_count=0
    
    # Fichiers critiques à surveiller
    local critical_files="/etc/passwd /etc/shadow /etc/group /etc/sudoers /etc/ssh/sshd_config /etc/crontab"
    
    for file in $critical_files; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        # Dernière modification
        local mtime=$(stat -c %Y "$file" 2>/dev/null)
        local now=$(date +%s)
        local hours_ago=$(( (now - mtime) / 3600 ))
        
        local modified_recently=false
        if [[ $hours_ago -lt $CHECK_LAST_HOURS ]]; then
            modified_recently=true
            mod_count=$((mod_count + 1))
        fi
        
        local mod_time=$(stat -c '%y' "$file" 2>/dev/null | cut -d'.' -f1)
        
        [[ "$first" == "false" ]] && modifications+=","
        modifications+="{\"file\":\"$file\",\"modified\":\"$mod_time\",\"hours_ago\":$hours_ago,\"recent\":$modified_recently}"
        first=false
    done
    
    # Nouveaux utilisateurs (créés dans les dernières 24h)
    local new_users=0
    while IFS=: read -r username _ uid _ _ home shell; do
        if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
            # Vérifier date de création (approximation via fichier home)
            if [[ -d "$home" ]]; then
                local create_time=$(stat -c %Y "$home" 2>/dev/null || echo "0")
                local hours=$(( (now - create_time) / 3600 ))
                if [[ $hours -lt $CHECK_LAST_HOURS ]]; then
                    new_users=$((new_users + 1))
                fi
            fi
        fi
    done < /etc/passwd
    
    [[ $mod_count -gt 0 || $new_users -gt 0 ]] && WARNING_COUNT=$((WARNING_COUNT + 1))
    
    echo "{\"critical_files_modified\":$mod_count,\"new_users\":$new_users,\"files\":$modifications}"
}

# ============================================================================
# FONCTIONS DE DÉTECTION - CONNEXIONS RÉSEAU SUSPECTES
# ============================================================================

check_network_connections() {
    log_verbose "Analyse des connexions réseau actives..." >&2
    
    local connections="["
    local first=true
    local total=0
    local external=0
    local suspicious=0
    
    # Ports suspects communs pour backdoors/C2
    local suspicious_ports="4444 5555 6666 7777 8888 9999 31337"
    
    while IFS= read -r line; do
        if [[ -z "$line" || "$line" =~ ^Netid ]]; then
            continue
        fi
        
        total=$((total + 1))
        
        local state=$(echo "$line" | awk '{print $1}')
        local local_addr=$(echo "$line" | awk '{print $5}')
        local remote_addr=$(echo "$line" | awk '{print $6}')
        local process=$(echo "$line" | awk '{print $7}' | cut -d'"' -f2)
        
        # Extraire port distant
        local remote_port=$(echo "$remote_addr" | rev | cut -d: -f1 | rev)
        
        # Vérifier si connexion externe
        if [[ ! "$remote_addr" =~ ^(127\.|::1|0\.0\.0\.0) ]]; then
            external=$((external + 1))
            
            # Vérifier ports suspects
            local is_suspicious=false
            if [[ " $suspicious_ports " =~ " $remote_port " ]]; then
                is_suspicious=true
                suspicious=$((suspicious + 1))
                SUSPICIOUS_COUNT=$((SUSPICIOUS_COUNT + 1))
            fi
            
            [[ "$first" == "false" ]] && connections+=","
            connections+="{\"state\":\"$state\",\"local\":\"$local_addr\",\"remote\":\"$remote_addr\",\"process\":\"$process\",\"suspicious\":$is_suspicious}"
            first=false
        fi
        
        # Limiter à 20 connexions
        [[ $external -ge 20 ]] && break
        
    done < <(ss -tnp 2>/dev/null | grep ESTAB)
    
    connections+="]"
    
    [[ $suspicious -gt 0 ]] && CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    
    echo "{\"total\":$total,\"external\":$external,\"suspicious\":$suspicious,\"connections\":$connections}"
}

# ============================================================================
# FONCTIONS DE DÉTECTION - FICHIERS CACHÉS SUSPECTS
# ============================================================================

check_hidden_files() {
    log_verbose "Recherche de fichiers cachés suspects..." >&2
    
    local hidden_files="["
    local first=true
    local found=0
    
    # Chercher dans /tmp, /var/tmp, /dev/shm
    local suspicious_dirs="/tmp /var/tmp /dev/shm"
    
    for dir in $suspicious_dirs; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi
        
        while IFS= read -r file; do
            if [[ -z "$file" ]]; then
                continue
            fi
            
            found=$((found + 1))
            
            local size=$(stat -c %s "$file" 2>/dev/null)
            local mtime=$(stat -c '%y' "$file" 2>/dev/null | cut -d'.' -f1)
            
            [[ "$first" == "false" ]] && hidden_files+=","
            hidden_files+="{\"path\":\"$file\",\"size\":$size,\"modified\":\"$mtime\"}"
            first=false
            
            # Limiter à 20 fichiers
            [[ $found -ge 20 ]] && break 2
            
        done < <(find "$dir" -maxdepth 2 -name ".*" -type f 2>/dev/null)
    done
    
    hidden_files+="]"
    
    [[ $found -gt 5 ]] && SUSPICIOUS_COUNT=$((SUSPICIOUS_COUNT + 1))
    
    echo "{\"found\":$found,\"files\":$hidden_files}"
}

# ============================================================================
# FONCTION PRINCIPALE DE COLLECTE
# ============================================================================

collect_intrusion_data() {
    log_verbose "Démarrage de la vérification d'intrusion..." >&2
    
    local start_time=$(date +%s)
    local hostname=$(hostname)
    
    # Réinitialiser compteurs
    CRITICAL_COUNT=0
    WARNING_COUNT=0
    SUSPICIOUS_COUNT=0
    
    # Exécuter toutes les vérifications
    local sessions=$(check_active_sessions)
    local processes=$(check_suspicious_processes)
    local ports=$(check_listening_ports)
    local suid=$(check_suid_files)
    local modifications=$(check_system_modifications)
    local network=$(check_network_connections)
    local hidden=$(check_hidden_files)
    
    # Déterminer le statut global
    local status="OK"
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        status="CRITICAL"
    elif [[ $WARNING_COUNT -gt 0 ]]; then
        status="WARNING"
    elif [[ $SUSPICIOUS_COUNT -gt 0 ]]; then
        status="SUSPICIOUS"
    fi
    
    local duration=$(calculate_duration "$start_time")
    
    # Générer le JSON
    cat > "$JSON_OUTPUT_FILE" <<EOF
{
  "metadata": {
    "script": "vps-intrusion-check",
    "version": "$VERSION",
    "timestamp": "$(get_iso_timestamp)",
    "hostname": "$hostname",
    "duration_seconds": $duration
  },
  "summary": {
    "status": "$status",
    "critical_issues": $CRITICAL_COUNT,
    "warnings": $WARNING_COUNT,
    "suspicious_items": $SUSPICIOUS_COUNT
  },
  "checks": {
    "active_sessions": $sessions,
    "suspicious_processes": $processes,
    "listening_ports": $ports,
    "suid_files": $suid,
    "system_modifications": $modifications,
    "network_connections": $network,
    "hidden_files": $hidden
  }
}
EOF
    
    ln -sf "$JSON_OUTPUT_FILE" "$JSON_LATEST"
    
    log_verbose "Vérification d'intrusion terminée" >&2
}

# ============================================================================
# AFFICHAGE TERMINAL
# ============================================================================

display_terminal_output() {
    [[ "$OUTPUT_TERMINAL" != "true" ]] && return
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+' | head -1)
    local critical=$(echo "$json_content" | grep -oP '(?<="critical_issues": )\d+')
    local warnings=$(echo "$json_content" | grep -oP '(?<="warnings": )\d+')
    local suspicious=$(echo "$json_content" | grep -oP '(?<="suspicious_items": )\d+')
    
    print_header "🚨 VPS Intrusion Check Report"
    
    # Statut global
    print_section "🎯 Statut Global"
    local status_icon="✅"
    local status_color="${GREEN}"
    [[ "$status" == "SUSPICIOUS" ]] && status_icon="⚠️" && status_color="${YELLOW}"
    [[ "$status" == "WARNING" ]] && status_icon="⚠️" && status_color="${YELLOW}"
    [[ "$status" == "CRITICAL" ]] && status_icon="❌" && status_color="${RED}"
    
    echo -e "  ${BOLD}${status_color}${status_icon} ${status}${NC}"
    echo -e "  Issues critiques: ${RED}${critical}${NC} | Avertissements: ${YELLOW}${warnings}${NC} | Suspects: ${YELLOW}${suspicious}${NC}"
    echo
    
    # Sessions actives
    print_section "👥 Sessions SSH Actives"
    local sess_total=$(echo "$json_content" | grep -A5 '"active_sessions"' | grep -oP '(?<="total":)\d+' | head -1)
    local sess_susp=$(echo "$json_content" | grep -A5 '"active_sessions"' | grep -oP '(?<="suspicious":)\d+' | head -1)
    
    print_table_row "Sessions actives" "$sess_total" "INFO"
    print_table_row "Sessions suspectes" "$sess_susp" "$([ $sess_susp -gt 0 ] && echo 'WARNING' || echo 'OK')"
    echo
    
    # Processus suspects
    print_section "⚙️  Processus Suspects"
    local proc_found=$(echo "$json_content" | grep -A5 '"suspicious_processes"' | grep -oP '(?<="found":)\d+' | head -1)
    
    if [[ $proc_found -gt 0 ]]; then
        print_table_row "Processus détectés" "$proc_found" "CRITICAL"
        
        echo "$json_content" | grep -oP '\{"pid":[^}]+\}' | head -5 | while read -r proc; do
            local pid=$(echo "$proc" | grep -oP '(?<="pid":)\d+')
            local name=$(echo "$proc" | grep -oP '(?<="name":")[^"]+')
            local user=$(echo "$proc" | grep -oP '(?<="user":")[^"]+')
            echo -e "  ${RED}⚠️${NC} PID $pid: ${BOLD}$name${NC} (user: $user)"
        done
    else
        print_table_row "Processus détectés" "0" "OK"
    fi
    echo
    
    # Ports ouverts
    print_section "🔌 Ports Ouverts"
    local ports_total=$(echo "$json_content" | grep -A5 '"listening_ports"' | grep -oP '(?<="total":)\d+' | head -1)
    local ports_susp=$(echo "$json_content" | grep -A5 '"listening_ports"' | grep -oP '(?<="suspicious":)\d+' | head -1)
    
    print_table_row "Ports en écoute" "$ports_total" "INFO"
    print_table_row "Ports suspects" "$ports_susp" "$([ $ports_susp -gt 3 ] && echo 'WARNING' || echo 'INFO')"
    echo
    
    # Fichiers SUID
    print_section "🔐 Fichiers SUID"
    local suid_found=$(echo "$json_content" | grep -A5 '"suid_files"' | grep -oP '(?<="found":)\d+' | head -1)
    local suid_susp=$(echo "$json_content" | grep -A5 '"suid_files"' | grep -oP '(?<="suspicious":)\d+' | head -1)
    
    print_table_row "Fichiers SUID" "$suid_found" "INFO"
    print_table_row "SUID suspects" "$suid_susp" "$([ $suid_susp -gt 0 ] && echo 'CRITICAL' || echo 'OK')"
    
    if [[ $suid_susp -gt 0 ]]; then
        echo "$json_content" | grep -oP '\{"path":"[^}]+,"suspicious":true\}' | head -3 | while read -r suid; do
            local path=$(echo "$suid" | grep -oP '(?<="path":")[^"]+')
            echo -e "  ${RED}⚠️${NC} ${BOLD}$path${NC}"
        done
    fi
    echo
    
    # Modifications système
    print_section "📝 Modifications Système (${CHECK_LAST_HOURS}h)"
    local mod_files=$(echo "$json_content" | grep -A5 '"system_modifications"' | grep -oP '(?<="critical_files_modified":)\d+' | head -1)
    local new_users=$(echo "$json_content" | grep -A5 '"system_modifications"' | grep -oP '(?<="new_users":)\d+' | head -1)
    
    print_table_row "Fichiers critiques modifiés" "$mod_files" "$([ $mod_files -gt 0 ] && echo 'WARNING' || echo 'OK')"
    print_table_row "Nouveaux utilisateurs" "$new_users" "$([ $new_users -gt 0 ] && echo 'WARNING' || echo 'OK')"
    echo
    
    # Connexions réseau
    print_section "🌐 Connexions Réseau"
    local net_external=$(echo "$json_content" | grep -A5 '"network_connections"' | grep -oP '(?<="external":)\d+' | head -1)
    local net_susp=$(echo "$json_content" | grep -A5 '"network_connections"' | grep -oP '(?<="suspicious":)\d+' | head -1)
    
    print_table_row "Connexions externes" "$net_external" "INFO"
    print_table_row "Connexions suspectes" "$net_susp" "$([ $net_susp -gt 0 ] && echo 'CRITICAL' || echo 'OK')"
    echo
    
    # Fichiers cachés
    print_section "🕵️  Fichiers Cachés"
    local hidden_found=$(echo "$json_content" | grep -A5 '"hidden_files"' | grep -oP '(?<="found":)\d+' | head -1)
    
    print_table_row "Fichiers cachés trouvés" "$hidden_found" "$([ $hidden_found -gt 10 ] && echo 'WARNING' || echo 'INFO')"
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
    
    local template_file="$SCRIPT_DIR/../templates/intrusion-check.html"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template introuvable: $template_file"
        echo "<!-- HTML Dashboard pour Intrusion Check -->" > "$HTML_OUTPUT_FILE"
        ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
        return 1
    fi
    
    # Lire le JSON
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    # Extraire les valeurs avec grep (JSON sur une ligne, avec espaces)
    local hostname=$(echo "$json_content" | grep -oP '"hostname":\s*"[^"]+' | grep -oP '"[^"]+$' | tr -d '"' | head -1)
    local timestamp=$(echo "$json_content" | grep -oP '"timestamp":\s*"[^"]+' | grep -oP '"[^"]+$' | tr -d '"' | head -1)
    local status=$(echo "$json_content" | grep -oP '"status":\s*"[^"]+' | grep -oP '"[^"]+$' | tr -d '"' | head -1)
    local critical=$(echo "$json_content" | grep -oP '"critical_issues":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local warnings=$(echo "$json_content" | grep -oP '"warnings":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local suspicious=$(echo "$json_content" | grep -oP '"suspicious_items":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    
    # Extraire les détails des checks
    local sessions_total=$(echo "$json_content" | grep -oP 'active_sessions.*?"total":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local sessions_suspicious=$(echo "$json_content" | grep -oP 'active_sessions.*?"suspicious":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    
    local processes_found=$(echo "$json_content" | grep -oP 'suspicious_processes.*?"found":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    
    local ports_total=$(echo "$json_content" | grep -oP 'listening_ports.*?"total":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local ports_suspicious=$(echo "$json_content" | grep -oP 'listening_ports.*?"suspicious":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    
    local suid_total=$(echo "$json_content" | grep -oP 'suid_files.*?"found":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local suid_suspicious=$(echo "$json_content" | grep -oP 'suid_files.*?"suspicious":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    
    local connections_total=$(echo "$json_content" | grep -oP 'network_connections.*?"total":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local connections_external=$(echo "$json_content" | grep -oP 'network_connections.*?"external":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local connections_suspicious=$(echo "$json_content" | grep -oP 'network_connections.*?"suspicious":\s*[0-9]+' | grep -oP '[0-9]+' | tail -1)
    
    local modifications_count=$(echo "$json_content" | grep -oP '"critical_files_modified":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    local hidden_files=$(echo "$json_content" | grep -oP 'hidden_files.*?"found":\s*[0-9]+' | grep -oP '[0-9]+' | head -1)
    
    # Déterminer la classe de statut
    local status_class="ok"
    [[ "$status" == "SUSPICIOUS" ]] && status_class="suspicious"
    [[ "$status" == "WARNING" ]] && status_class="warning"
    [[ "$status" == "CRITICAL" ]] && status_class="critical"
    
    # Copier le template et remplacer les placeholders
    cp "$template_file" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{HOSTNAME}}|${hostname:-$(hostname)}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{TIMESTAMP}}|${timestamp:-$TIMESTAMP}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{VERSION}}|$VERSION|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{STATUS}}|${status:-OK}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{STATUS_CLASS}}|$status_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{CRITICAL_COUNT}}|${critical:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{WARNING_COUNT}}|${warnings:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUSPICIOUS_COUNT}}|${suspicious:-0}|g" "$HTML_OUTPUT_FILE"
    
    # Placeholders pour les checks détaillés (à implémenter plus tard)
    sed -i "s|{{SESSIONS_CHECK}}|<div class='check-item'>Voir le JSON pour les détails</div>|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PROCESSES_CHECK}}|<div class='check-item'>Voir le JSON pour les détails</div>|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{CONNECTIONS_CHECK}}|<div class='check-item'>Voir le JSON pour les détails</div>|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FILES_CHECK}}|<div class='check-item'>Voir le JSON pour les détails</div>|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{LOGS_CHECK}}|<div class='check-item'>Voir le JSON pour les détails</div>|g" "$HTML_OUTPUT_FILE"
    
    # Valeurs réelles des checks
    sed -i "s|{{ACTIVE_SESSIONS}}|${sessions_total:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUSPICIOUS_PROCESSES}}|${processes_found:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{UNUSUAL_CONNECTIONS}}|${connections_suspicious:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{MODIFIED_FILES}}|${modifications_count:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUID_FILES}}|${suid_total:-0}|g" "$HTML_OUTPUT_FILE"
    
    # Détails réseau
    sed -i "s|{{CONNECTIONS_TOTAL}}|${connections_total:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{CONNECTIONS_EXTERNAL}}|${connections_external:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{CONNECTIONS_SUSPICIOUS}}|${connections_suspicious:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{CONNECTIONS_DETAILS}}||g" "$HTML_OUTPUT_FILE"
    
    local network_status="OK"
    local network_class="ok"
    [[ $connections_suspicious -gt 0 ]] && network_status="SUSPICIOUS" && network_class="warning"
    sed -i "s|{{NETWORK_STATUS}}|$network_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{NETWORK_STATUS_CLASS}}|$network_class|g" "$HTML_OUTPUT_FILE"
    
    # Processus suspects
    sed -i "s|{{BACKDOORS_COUNT}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{MINERS_COUNT}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{HIGH_CPU_COUNT}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUSPICIOUS_PROCS_LIST}}||g" "$HTML_OUTPUT_FILE"
    
    local process_status="OK"
    local process_class="ok"
    [[ $processes_found -gt 0 ]] && process_status="SUSPICIOUS" && process_class="warning"
    sed -i "s|{{PROCESS_STATUS}}|$process_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PROCESS_STATUS_CLASS}}|$process_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PROCESSES_STATUS}}|$process_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PROCESSES_STATUS_CLASS}}|$process_class|g" "$HTML_OUTPUT_FILE"
    
    # Fichiers cachés
    sed -i "s|{{HIDDEN_COUNT}}|${hidden_files:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{HIDDEN_TMP}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{HIDDEN_VAR_TMP}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{HIDDEN_SHM}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{HIDDEN_FILES_LIST}}||g" "$HTML_OUTPUT_FILE"
    
    local hidden_status="OK"
    local hidden_class="ok"
    [[ $hidden_files -gt 0 ]] && hidden_status="SUSPICIOUS" && hidden_class="warning"
    sed -i "s|{{HIDDEN_STATUS}}|$hidden_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{HIDDEN_STATUS_CLASS}}|$hidden_class|g" "$HTML_OUTPUT_FILE"
    
    # Modifications système
    sed -i "s|{{MODIFICATIONS_COUNT}}|${modifications_count:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{MODIFICATIONS_TIMELINE}}||g" "$HTML_OUTPUT_FILE"
    
    local modif_status="OK"
    local modif_class="ok"
    [[ $modifications_count -gt 0 ]] && modif_status="WARNING" && modif_class="warning"
    sed -i "s|{{MODIFICATIONS_STATUS}}|$modif_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{MODIFICATIONS_STATUS_CLASS}}|$modif_class|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{HOURS}}|24|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{ROOTKITS_FOUND}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUSPICIOUS_BINARIES}}|0|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{TIMELINE_ITEMS}}||g" "$HTML_OUTPUT_FILE"
    
    # Statut global dynamique
    local status_icon="bi-check-circle-fill"
    local status_text="Système sain"
    if [[ "$status" == "WARNING" ]]; then
        status_icon="bi-exclamation-triangle-fill"
        status_text="Attention requise"
    elif [[ "$status" == "CRITICAL" ]]; then
        status_icon="bi-x-circle-fill"
        status_text="Intrusion détectée!"
    fi
    sed -i "s|{{STATUS_ICON}}|$status_icon|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{STATUS_TEXT}}|$status_text|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{RECOMMENDATIONS}}||g" "$HTML_OUTPUT_FILE"
    
    # Sessions
    sed -i "s|{{SESSIONS_COUNT}}|${sessions_total:-0}|g" "$HTML_OUTPUT_FILE"
    local sessions_status="OK"
    local sessions_class="ok"
    [[ $sessions_suspicious -gt 0 ]] && sessions_status="SUSPICIOUS" && sessions_class="warning"
    sed -i "s|{{SESSIONS_STATUS}}|$sessions_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SESSIONS_STATUS_CLASS}}|$sessions_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SESSIONS_LIST}}||g" "$HTML_OUTPUT_FILE"
    
    # Processus suspect details
    sed -i "s|{{PROCESSES_SUSPECT}}|${processes_found:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PROCESSES_DETAILS}}||g" "$HTML_OUTPUT_FILE"
    
    # Ports
    sed -i "s|{{PORTS_TOTAL}}|${ports_total:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PORTS_UNUSUAL}}|${ports_suspicious:-0}|g" "$HTML_OUTPUT_FILE"
    local ports_status="OK"
    local ports_class="ok"
    [[ $ports_suspicious -gt 0 ]] && ports_status="SUSPICIOUS" && ports_class="warning"
    sed -i "s|{{PORTS_STATUS}}|$ports_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PORTS_STATUS_CLASS}}|$ports_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{PORTS_ROWS}}||g" "$HTML_OUTPUT_FILE"
    
    # SUID files
    sed -i "s|{{SUID_TOTAL}}|${suid_total:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUID_SUSPICIOUS}}|${suid_suspicious:-0}|g" "$HTML_OUTPUT_FILE"
    local suid_status="OK"
    local suid_class="ok"
    [[ $suid_suspicious -gt 0 ]] && suid_status="WARNING" && suid_class="warning"
    sed -i "s|{{SUID_STATUS}}|$suid_status|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SUID_STATUS_CLASS}}|$suid_class|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{JSON_FILE_PATH}}|../json/intrusion-check_latest.json|g" "$HTML_OUTPUT_FILE"
    
    ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
    
    log_verbose "Rapport HTML généré: $HTML_OUTPUT_FILE"
}

# ============================================================================
# GESTION DES ALERTES
# ============================================================================

send_alerts() {
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+' | head -1)
    local critical=$(echo "$json_content" | grep -oP '(?<="critical_issues": )\d+')
    
    if [[ "$status" == "CRITICAL" || $critical -gt 0 ]]; then
        local hostname=$(hostname)
        local alert_message="🚨 *ALERTE INTRUSION* - ${hostname}

⚠️ Statut: *${status}*
🔴 Issues critiques: *${critical}*

Détection potentielle d'intrusion ou compromission système.
Vérifiez immédiatement le rapport complet !"
        
        [[ "$ENABLE_EMAIL" == "true" ]] && send_email_alert "Intrusion Check - ALERTE CRITIQUE" "$alert_message"
        [[ "$ENABLE_TELEGRAM" == "true" ]] && send_telegram_alert "$alert_message"
    elif [[ "$status" == "WARNING" ]]; then
        log_verbose "Avertissements détectés, mais pas critique" >&2
    else
        log_verbose "Aucune intrusion détectée, système sain" >&2
    fi
}

# ============================================================================
# AIDE
# ============================================================================

show_help() {
    cat <<EOF
Usage: sudo $SCRIPT_NAME [OPTIONS]

Détection d'intrusion et vérification d'intégrité système

OPTIONS:
    -h, --help              Afficher cette aide
    -v, --verbose           Mode verbeux
    -s, --silent            Mode silencieux
    --hours HOURS           Période de vérification (défaut: 24h)
    --no-json               Ne pas générer de JSON
    --no-html               Ne pas générer de HTML
    --email EMAIL           Envoyer alerte si intrusion détectée
    --telegram TOKEN CHAT   Envoyer alerte Telegram

VÉRIFICATIONS:
    ✓ Sessions SSH actives suspectes
    ✓ Processus suspects (miners, backdoors)
    ✓ Ports ouverts inhabituels
    ✓ Fichiers SUID suspects
    ✓ Modifications système récentes
    ✓ Connexions réseau suspectes
    ✓ Fichiers cachés dans /tmp et /var/tmp

EXEMPLES:
    sudo ./$SCRIPT_NAME
    sudo ./$SCRIPT_NAME --verbose --hours 48
    sudo ./$SCRIPT_NAME --email admin@example.com

SORTIES:
    Terminal: Rapport détaillé avec statut de chaque vérification
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
        --hours) CHECK_LAST_HOURS="$2"; shift 2 ;;
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
    
    collect_intrusion_data
    display_terminal_output
    generate_html_output
    send_alerts
    
    local duration=$(calculate_duration "$start_time")
    log_verbose "Vérification terminée en ${duration}s" >&2
    
    echo "[$(date)] Intrusion check completed - Status: $(grep '"status"' "$JSON_OUTPUT_FILE" | head -1 | awk -F':' '{print $2}' | tr -d ' ,"')" >> "$LOG_FILE"
}

main
exit 0
