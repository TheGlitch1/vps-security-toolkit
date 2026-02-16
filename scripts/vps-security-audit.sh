#!/bin/bash

# Script: vps-security-audit.sh
# Description: Audit complet de la configuration de sécurité du VPS
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

# Score minimum acceptable
SECURITY_SCORE_MINIMUM="${SECURITY_SCORE_MINIMUM:-70}"
ALERT_ON_LOW_SCORE="${ALERT_ON_LOW_SCORE:-true}"

# Fichiers de sortie
LOG_FILE="$LOG_DIR/security-audit.log"
JSON_OUTPUT_FILE="$JSON_DIR/security-audit_${TIMESTAMP}.json"
JSON_LATEST="$JSON_DIR/security-audit_latest.json"
HTML_OUTPUT_FILE="$HTML_DIR/security-audit_${TIMESTAMP}.html"
HTML_LATEST="$HTML_DIR/security-audit_latest.html"

# Fichiers de configuration SSH
SSHD_CONFIG="/etc/ssh/sshd_config"

# Score global
TOTAL_SCORE=0
MAX_SCORE=0

# ============================================================================
# FONCTIONS D'AUDIT SSH
# ============================================================================

# Fonction: get_ssh_config_value
# Description: Extrait une valeur de configuration SSH
get_ssh_config_value() {
    local param="$1"
    local default="${2:-}"
    
    if [[ ! -f "$SSHD_CONFIG" ]]; then
        echo "$default"
        return 1
    fi
    
    # Chercher la ligne non commentée
    local value=$(grep -i "^[[:space:]]*${param}" "$SSHD_CONFIG" | tail -1 | awk '{print $2}')
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Fonction: audit_ssh_config
# Description: Audit complet de la configuration SSH
audit_ssh_config() {
    log_verbose "Audit de la configuration SSH..." >&2
    
    local ssh_checks="["
    local first=true
    local score=0
    local max=100
    
    # PermitRootLogin
    local permit_root=$(get_ssh_config_value "PermitRootLogin" "yes")
    local root_status="fail"
    local root_score=0
    if [[ "$permit_root" == "no" || "$permit_root" == "prohibit-password" ]]; then
        root_status="pass"
        root_score=20
    fi
    score=$((score + root_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"PermitRootLogin\",\"value\":\"$permit_root\",\"expected\":\"no|prohibit-password\",\"status\":\"$root_status\",\"score\":$root_score,\"max\":20}"
    first=false
    
    # PasswordAuthentication
    local password_auth=$(get_ssh_config_value "PasswordAuthentication" "yes")
    local pass_status="warning"
    local pass_score=10
    if [[ "$password_auth" == "no" ]]; then
        pass_status="pass"
        pass_score=15
    fi
    score=$((score + pass_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"PasswordAuthentication\",\"value\":\"$password_auth\",\"expected\":\"no\",\"status\":\"$pass_status\",\"score\":$pass_score,\"max\":15}"
    first=false
    
    # PubkeyAuthentication
    local pubkey_auth=$(get_ssh_config_value "PubkeyAuthentication" "yes")
    local pubkey_status="pass"
    local pubkey_score=10
    if [[ "$pubkey_auth" != "yes" ]]; then
        pubkey_status="fail"
        pubkey_score=0
    fi
    score=$((score + pubkey_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"PubkeyAuthentication\",\"value\":\"$pubkey_auth\",\"expected\":\"yes\",\"status\":\"$pubkey_status\",\"score\":$pubkey_score,\"max\":10}"
    first=false
    
    # PermitEmptyPasswords
    local empty_pass=$(get_ssh_config_value "PermitEmptyPasswords" "no")
    local empty_status="pass"
    local empty_score=10
    if [[ "$empty_pass" != "no" ]]; then
        empty_status="fail"
        empty_score=0
    fi
    score=$((score + empty_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"PermitEmptyPasswords\",\"value\":\"$empty_pass\",\"expected\":\"no\",\"status\":\"$empty_status\",\"score\":$empty_score,\"max\":10}"
    first=false
    
    # X11Forwarding
    local x11=$(get_ssh_config_value "X11Forwarding" "yes")
    local x11_status="warning"
    local x11_score=5
    if [[ "$x11" == "no" ]]; then
        x11_status="pass"
        x11_score=10
    fi
    score=$((score + x11_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"X11Forwarding\",\"value\":\"$x11\",\"expected\":\"no\",\"status\":\"$x11_status\",\"score\":$x11_score,\"max\":10}"
    first=false
    
    # MaxAuthTries
    local max_auth=$(get_ssh_config_value "MaxAuthTries" "6")
    local auth_status="warning"
    local auth_score=5
    if [[ "$max_auth" =~ ^[0-9]+$ ]] && [[ "$max_auth" -le 3 ]]; then
        auth_status="pass"
        auth_score=10
    fi
    score=$((score + auth_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"MaxAuthTries\",\"value\":\"$max_auth\",\"expected\":\"<=3\",\"status\":\"$auth_status\",\"score\":$auth_score,\"max\":10}"
    first=false
    
    # Port SSH
    local ssh_port=$(get_ssh_config_value "Port" "22")
    local port_status="warning"
    local port_score=10
    if [[ "$ssh_port" != "22" ]]; then
        port_status="pass"
        port_score=15
    fi
    score=$((score + port_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"Port\",\"value\":\"$ssh_port\",\"expected\":\"!= 22\",\"status\":\"$port_status\",\"score\":$port_score,\"max\":15}"
    first=false
    
    # ClientAliveInterval
    local client_alive=$(get_ssh_config_value "ClientAliveInterval" "0")
    local alive_status="warning"
    local alive_score=5
    if [[ "$client_alive" =~ ^[0-9]+$ ]] && [[ "$client_alive" -gt 0 ]] && [[ "$client_alive" -le 300 ]]; then
        alive_status="pass"
        alive_score=10
    fi
    score=$((score + alive_score))
    
    [[ "$first" == "false" ]] && ssh_checks+=","
    ssh_checks+="{\"parameter\":\"ClientAliveInterval\",\"value\":\"$client_alive\",\"expected\":\"1-300\",\"status\":\"$alive_status\",\"score\":$alive_score,\"max\":10}"
    first=false
    
    ssh_checks+="]"
    
    TOTAL_SCORE=$((TOTAL_SCORE + score))
    MAX_SCORE=$((MAX_SCORE + max))
    
    echo "{\"checks\":$ssh_checks,\"score\":$score,\"max\":$max}"
}

# ============================================================================
# FONCTIONS D'AUDIT FAIL2BAN
# ============================================================================

audit_fail2ban() {
    log_verbose "Audit de fail2ban..." >&2
    
    local score=0
    local max=100
    local installed=false
    local active=false
    local jails_count=0
    local jail_config=false
    
    # Vérifier installation
    if command -v fail2ban-client &>/dev/null; then
        installed=true
        score=$((score + 30))
        
        # Vérifier si actif
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            active=true
            score=$((score + 40))
            
            # Compter les jails
            jails_count=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | wc -l)
            if [[ $jails_count -gt 0 ]]; then
                score=$((score + 20))
            fi
        fi
        
        # Vérifier jail.local
        if [[ -f /etc/fail2ban/jail.local ]]; then
            jail_config=true
            score=$((score + 10))
        fi
    fi
    
    TOTAL_SCORE=$((TOTAL_SCORE + score))
    MAX_SCORE=$((MAX_SCORE + max))
    
    echo "{\"installed\":$installed,\"active\":$active,\"jails_count\":$jails_count,\"has_custom_config\":$jail_config,\"score\":$score,\"max\":$max}"
}

# ============================================================================
# FONCTIONS D'AUDIT FIREWALL
# ============================================================================

audit_firewall() {
    log_verbose "Audit du firewall..." >&2
    
    local score=0
    local max=100
    local ufw_installed=false
    local ufw_active=false
    local ufw_rules=0
    local iptables_rules=0
    
    # UFW
    if command -v ufw &>/dev/null; then
        ufw_installed=true
        score=$((score + 20))
        
        if ufw status | grep -q "Status: active"; then
            ufw_active=true
            score=$((score + 50))
            
            ufw_rules=$(ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")
            if [[ $ufw_rules -gt 0 ]]; then
                score=$((score + 20))
            fi
        fi
    fi
    
    # iptables
    iptables_rules=$(iptables -L | grep -c "^Chain" || echo "0")
    if [[ $iptables_rules -gt 3 ]]; then
        score=$((score + 10))
    fi
    
    TOTAL_SCORE=$((TOTAL_SCORE + score))
    MAX_SCORE=$((MAX_SCORE + max))
    
    echo "{\"ufw\":{\"installed\":$ufw_installed,\"active\":$ufw_active,\"rules\":$ufw_rules},\"iptables_chains\":$iptables_rules,\"score\":$score,\"max\":$max}"
}

# ============================================================================
# FONCTIONS D'AUDIT UPDATES
# ============================================================================

audit_updates() {
    log_verbose "Audit des mises à jour..." >&2
    
    local score=100
    local max=100
    local security_updates=0
    local all_updates=0
    local reboot_required=false
    local kernel_current=""
    local kernel_latest=""
    
    # Vérifier les mises à jour disponibles
    if command -v apt &>/dev/null; then
        apt update -qq &>/dev/null
        security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
        all_updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
        
        # Pénalité pour les mises à jour de sécurité en attente
        if [[ $security_updates -gt 0 ]]; then
            score=$((score - security_updates * 5))
            [[ $score -lt 0 ]] && score=0
        fi
        
        # Vérifier si un redémarrage est requis
        if [[ -f /var/run/reboot-required ]]; then
            reboot_required=true
            score=$((score - 20))
            [[ $score -lt 0 ]] && score=0
        fi
    fi
    
    # Kernel version
    kernel_current=$(uname -r)
    
    TOTAL_SCORE=$((TOTAL_SCORE + score))
    MAX_SCORE=$((MAX_SCORE + max))
    
    echo "{\"security_updates\":$security_updates,\"total_updates\":$all_updates,\"reboot_required\":$reboot_required,\"kernel_current\":\"$kernel_current\",\"score\":$score,\"max\":$max}"
}

# ============================================================================
# FONCTIONS D'AUDIT UTILISATEURS
# ============================================================================

audit_users() {
    log_verbose "Audit des comptes utilisateurs..." >&2
    
    local score=100
    local max=100
    local users_with_shell=0
    local users_with_uid0=0
    local users_no_password=0
    local user_list="["
    local first=true
    
    # Analyser /etc/passwd
    while IFS=: read -r username _ uid _ _ home shell; do
        # Compter utilisateurs avec shell actif
        if [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" && "$shell" != "/usr/bin/false" ]]; then
            users_with_shell=$((users_with_shell + 1))
            
            # Vérifier UID 0
            if [[ "$uid" == "0" && "$username" != "root" ]]; then
                users_with_uid0=$((users_with_uid0 + 1))
                score=$((score - 50))
            fi
            
            # Vérifier mot de passe
            local pass_status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
            local has_password=true
            if [[ "$pass_status" == "NP" || "$pass_status" == "L" ]]; then
                has_password=false
                if [[ "$username" != "root" ]]; then
                    users_no_password=$((users_no_password + 1))
                fi
            fi
            
            # Dernière connexion
            local last_login=$(last -1 "$username" 2>/dev/null | head -1 | awk '{print $4, $5, $6, $7}' || echo "Never")
            
            [[ "$first" == "false" ]] && user_list+=","
            user_list+="{\"username\":\"$username\",\"uid\":$uid,\"shell\":\"$shell\",\"home\":\"$home\",\"has_password\":$has_password,\"last_login\":\"$last_login\"}"
            first=false
        fi
    done < /etc/passwd
    
    user_list+="]"
    
    # Pénalité pour comptes suspects
    if [[ $users_with_uid0 -gt 0 ]]; then
        score=0
    fi
    
    [[ $score -lt 0 ]] && score=0
    
    TOTAL_SCORE=$((TOTAL_SCORE + score))
    MAX_SCORE=$((MAX_SCORE + max))
    
    echo "{\"users_with_shell\":$users_with_shell,\"users_with_uid0\":$users_with_uid0,\"users_no_password\":$users_no_password,\"users\":$user_list,\"score\":$score,\"max\":$max}"
}

# ============================================================================
# FONCTION PRINCIPALE DE COLLECTE
# ============================================================================

collect_audit_data() {
    log_verbose "Collecte des données d'audit de sécurité..."
    
    local start_time=$(date +%s)
    local hostname=$(hostname)
    
    # Réinitialiser les scores
    TOTAL_SCORE=0
    MAX_SCORE=0
    
    # Audits
    local ssh_audit=$(audit_ssh_config)
    local fail2ban_audit=$(audit_fail2ban)
    local firewall_audit=$(audit_firewall)
    local updates_audit=$(audit_updates)
    local users_audit=$(audit_users)
    
    # Calculer le score final en pourcentage (moyenne des 5 audits)
    local ssh_score=$(echo "$ssh_audit" | grep -oP '(?<="score":)\d+' | tail -1)
    local f2b_score=$(echo "$fail2ban_audit" | grep -oP '(?<="score":)\d+' | tail -1)
    local fw_score=$(echo "$firewall_audit" | grep -oP '(?<="score":)\d+' | tail -1)
    local upd_score=$(echo "$updates_audit" | grep -oP '(?<="score":)\d+' | tail -1)
    local usr_score=$(echo "$users_audit" | grep -oP '(?<="score":)\d+' | tail -1)
    
    local final_score=$(( (ssh_score + f2b_score + fw_score + upd_score + usr_score) / 5 ))
    
    # Déterminer le statut global
    local status="EXCELLENT"
    local critical_count=0
    local warning_count=0
    
    if [[ $final_score -lt 50 ]]; then
        status="CRITICAL"
        critical_count=1
    elif [[ $final_score -lt 70 ]]; then
        status="WARNING"
        warning_count=1
    elif [[ $final_score -lt 85 ]]; then
        status="GOOD"
    fi
    
    local duration=$(calculate_duration "$start_time")
    
    # Générer le JSON
    cat > "$JSON_OUTPUT_FILE" <<EOF
{
  "metadata": {
    "script": "vps-security-audit",
    "version": "$VERSION",
    "timestamp": "$(get_iso_timestamp)",
    "hostname": "$hostname",
    "duration_seconds": $duration
  },
  "summary": {
    "status": "$status",
    "score": $final_score,
    "max_score": 100,
    "critical_issues": $critical_count,
    "warnings": $warning_count
  },
  "audits": {
    "ssh": $ssh_audit,
    "fail2ban": $fail2ban_audit,
    "firewall": $firewall_audit,
    "updates": $updates_audit,
    "users": $users_audit
  },
  "recommendations": []
}
EOF
    
    ln -sf "$JSON_OUTPUT_FILE" "$JSON_LATEST"
    
    log_verbose "Audit terminé. Score final: ${final_score}/100"
}

# ============================================================================
# AFFICHAGE TERMINAL
# ============================================================================

display_terminal_output() {
    [[ "$OUTPUT_TERMINAL" != "true" ]] && return
    [[ "$VERBOSITY" == "silent" ]] && return
    
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    local hostname=$(echo "$json_content" | grep -oP '(?<="hostname": ")[^"]+')
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+')
    local score=$(echo "$json_content" | grep -oP '(?<="score": )\d+')
    
    print_header "🔒 VPS Security Audit Report"
    
    # Score global
    print_section "🎯 Score de Sécurité"
    local score_color="${GREEN}"
    [[ $score -lt 85 ]] && score_color="${YELLOW}"
    [[ $score -lt 70 ]] && score_color="${YELLOW}"
    [[ $score -lt 50 ]] && score_color="${RED}"
    
    echo -e "  ${BOLD}${score_color}${score}/100${NC}"
    echo -e "  Statut: ${score_color}${status}${NC}"
    print_progress_bar "$score" "100"
    echo
    
    # SSH Configuration
    print_section "🔑 Configuration SSH"
    local ssh_checks=$(echo "$json_content" | grep -A1000 '"ssh"' | grep -B1000 '"fail2ban"' | grep '"checks"')
    
    while IFS= read -r check; do
        if [[ -n "$check" ]]; then
            local param=$(echo "$check" | grep -oP '(?<="parameter":")[^"]+')
            local value=$(echo "$check" | grep -oP '(?<="value":")[^"]+')
            local expected=$(echo "$check" | grep -oP '(?<="expected":")[^"]+')
            local check_status=$(echo "$check" | grep -oP '(?<="status":")[^"]+')
            
            local display_status="INFO"
            [[ "$check_status" == "pass" ]] && display_status="OK"
            [[ "$check_status" == "warning" ]] && display_status="WARNING"
            [[ "$check_status" == "fail" ]] && display_status="CRITICAL"
            
            print_table_row "$param" "$value (attendu: $expected)" "$display_status"
        fi
    done < <(echo "$json_content" | grep -oP '\{"parameter":"[^}]+\}')
    echo
    
    # Fail2ban
    print_section "🛡️  Fail2ban"
    local f2b_installed=$(echo "$json_content" | grep -oP '"fail2ban".*?"installed":(true|false)' | grep -oP '(true|false)')
    local f2b_active=$(echo "$json_content" | grep -oP '"fail2ban".*?"active":(true|false)' | grep -oP '(true|false)')
    local jails=$(echo "$json_content" | grep -oP '"jails_count":\d+' | grep -oP '\d+')
    
    if [[ "$f2b_installed" == "true" ]]; then
        print_table_row "Installation" "✓ Installé" "OK"
        if [[ "$f2b_active" == "true" ]]; then
            print_table_row "Service" "✓ Actif" "OK"
            print_table_row "Jails actives" "$jails" "INFO"
        else
            print_table_row "Service" "✗ Inactif" "CRITICAL"
        fi
    else
        print_table_row "Installation" "✗ Non installé" "WARNING"
    fi
    echo
    
    # Firewall
    print_section "🔥 Firewall"
    local ufw_installed=$(echo "$json_content" | grep -oP '"ufw".*?"installed":(true|false)' | grep -oP '(true|false)' | head -1)
    local ufw_active=$(echo "$json_content" | grep -oP '"ufw".*?"active":(true|false)' | grep -oP '(true|false)' | head -1)
    
    if [[ "$ufw_installed" == "true" ]]; then
        print_table_row "UFW" "✓ Installé" "OK"
        if [[ "$ufw_active" == "true" ]]; then
            print_table_row "UFW Status" "✓ Actif" "OK"
        else
            print_table_row "UFW Status" "✗ Inactif" "WARNING"
        fi
    else
        print_table_row "UFW" "✗ Non installé" "WARNING"
    fi
    echo
    
    # Mises à jour
    print_section "📦 Mises à Jour"
    local sec_updates=$(echo "$json_content" | grep -oP '"security_updates":\d+' | grep -oP '\d+')
    local total_updates=$(echo "$json_content" | grep -oP '"total_updates":\d+' | grep -oP '\d+')
    local reboot=$(echo "$json_content" | grep -oP '"reboot_required":(true|false)' | grep -oP '(true|false)')
    
    local update_status="OK"
    [[ $sec_updates -gt 0 ]] && update_status="WARNING"
    print_table_row "Mises à jour de sécurité" "$sec_updates en attente" "$update_status"
    print_table_row "Mises à jour totales" "$total_updates" "INFO"
    
    if [[ "$reboot" == "true" ]]; then
        print_table_row "Redémarrage" "⚠️ Requis" "WARNING"
    else
        print_table_row "Redémarrage" "✓ Non requis" "OK"
    fi
    echo
    
    # Utilisateurs
    print_section "👥 Comptes Utilisateurs"
    local users_shell=$(echo "$json_content" | grep -oP '"users_with_shell":\d+' | grep -oP '\d+' | head -1)
    local users_uid0=$(echo "$json_content" | grep -oP '"users_with_uid0":\d+' | grep -oP '\d+' | head -1)
    
    print_table_row "Comptes avec shell" "$users_shell" "INFO"
    
    if [[ "$users_uid0" -gt "0" ]]; then
        print_table_row "Comptes avec UID 0" "⚠️ $users_uid0 (DANGEREUX!)" "CRITICAL"
    else
        print_table_row "Comptes avec UID 0" "✓ 0 (uniquement root)" "OK"
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
    
    log_verbose "Génération du rapport HTML..."
    
    local template_file="$SCRIPT_DIR/../templates/security-audit.html"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template introuvable: $template_file"
        echo "<!-- HTML Dashboard pour Security Audit -->" > "$HTML_OUTPUT_FILE"
        ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
        return 1
    fi
    
    # Lire le JSON
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    
    # Extraire les valeurs avec jq
    local hostname=$(echo "$json_content" | jq -r '.metadata.hostname // "unknown"')
    local timestamp=$(echo "$json_content" | jq -r '.metadata.timestamp // ""')
    local score=$(echo "$json_content" | jq -r '.summary.score // 0')
    local status=$(echo "$json_content" | jq -r '.summary.status // "UNKNOWN"')
    
    # Scores par catégorie avec jq
    local score_ssh=$(echo "$json_content" | jq -r '.audits.ssh.score // 0')
    local score_fail2ban=$(echo "$json_content" | jq -r '.audits.fail2ban.score // 0')
    local score_firewall=$(echo "$json_content" | jq -r '.audits.firewall.score // 0')
    local score_updates=$(echo "$json_content" | jq -r '.audits.updates.score // 0')
    local score_users=$(echo "$json_content" | jq -r '.audits.users.score // 0')
    
    # Déterminer les classes CSS
    local score_class="excellent"
    [[ $score -lt 90 ]] && score_class="good"
    [[ $score -lt 70 ]] && score_class="warning"
    [[ $score -lt 50 ]] && score_class="critical"
    
    local score_label="EXCELLENT"
    [[ $score -lt 90 ]] && score_label="GOOD"
    [[ $score -lt 70 ]] && score_label="WARNING"
    [[ $score -lt 50 ]] && score_label="CRITICAL"
    
    # Copier le template et remplacer les placeholders
    cp "$template_file" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{HOSTNAME}}|${hostname:-$(hostname)}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{TIMESTAMP}}|${timestamp:-$TIMESTAMP}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{VERSION}}|$VERSION|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE}}|${score:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_LABEL}}|$score_label|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_SSH}}|${score_ssh:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_FAIL2BAN}}|${score_fail2ban:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_FIREWALL}}|${score_firewall:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_UPDATES}}|${score_updates:-0}|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_USERS}}|${score_users:-0}|g" "$HTML_OUTPUT_FILE"
    
    # Générer les checks SSH
    local ssh_checks_html=""
    local ssh_check_count=$(echo "$json_content" | jq '.audits.ssh.checks | length')
    for ((i=0; i<$ssh_check_count; i++)); do
        local param=$(echo "$json_content" | jq -r ".audits.ssh.checks[$i].parameter")
        local value=$(echo "$json_content" | jq -r ".audits.ssh.checks[$i].value")
        local expected=$(echo "$json_content" | jq -r ".audits.ssh.checks[$i].expected")
        local check_status=$(echo "$json_content" | jq -r ".audits.ssh.checks[$i].status")
        
        local icon="bi-check-circle-fill"
        local color="#10b981"
        [[ "$check_status" == "warning" ]] && icon="bi-exclamation-triangle-fill" && color="#f59e0b"
        [[ "$check_status" == "fail" ]] && icon="bi-x-circle-fill" && color="#ef4444"
        
        ssh_checks_html+="<div class='check-item'><i class='bi $icon check-icon' style='color: $color;'></i> <strong>$param:</strong> $value <span style='color: #9ca3af;'>(attendu: $expected)</span></div>"
    done
    [[ -z "$ssh_checks_html" ]] && ssh_checks_html="<div class='check-item'><i class='bi bi-info-circle check-icon' style='color: #3b82f6;'></i> Aucune donnée disponible</div>"
    # Échapper les caractères spéciaux pour sed (mais pas le pipe)
    ssh_checks_html=$(echo "$ssh_checks_html" | sed 's/[\/&]/\\&/g' | sed 's/|/\\|/g')
    
    # Générer les checks Fail2ban
    local fail2ban_checks_html=""
    local fail2ban_installed=$(echo "$json_content" | jq -r '.audits.fail2ban.installed')
    local fail2ban_active=$(echo "$json_content" | jq -r '.audits.fail2ban.active')
    local fail2ban_jails=$(echo "$json_content" | jq -r '.audits.fail2ban.jails_count // 0')
    
    if [[ "$fail2ban_installed" == "true" ]]; then
        fail2ban_checks_html="<div class='check-item'><i class='bi bi-check-circle-fill check-icon' style='color: #10b981;'></i> <strong>Installation:</strong> Installé</div>"
        if [[ "$fail2ban_active" == "true" ]]; then
            fail2ban_checks_html+="<div class='check-item'><i class='bi bi-check-circle-fill check-icon' style='color: #10b981;'></i> <strong>Statut:</strong> Actif</div>"
            fail2ban_checks_html+="<div class='check-item'><i class='bi bi-info-circle check-icon' style='color: #3b82f6;'></i> <strong>Jails actives:</strong> $fail2ban_jails</div>"
        else
            fail2ban_checks_html+="<div class='check-item'><i class='bi bi-exclamation-triangle-fill check-icon' style='color: #f59e0b;'></i> <strong>Statut:</strong> Installé mais inactif</div>"
        fi
    else
        fail2ban_checks_html="<div class='check-item'><i class='bi bi-x-circle-fill check-icon' style='color: #ef4444;'></i> <strong>Installation:</strong> Non installé</div>"
    fi
    fail2ban_checks_html=$(echo "$fail2ban_checks_html" | sed 's/[\/&]/\\&/g')
    
    # Générer les checks Firewall
    local firewall_checks_html=""
    local ufw_installed=$(echo "$json_content" | jq -r '.audits.firewall.ufw.installed')
    local ufw_active=$(echo "$json_content" | jq -r '.audits.firewall.ufw.active')
    local ufw_rules=$(echo "$json_content" | jq -r '.audits.firewall.ufw.rules // 0')
    
    if [[ "$ufw_installed" == "true" ]]; then
        firewall_checks_html="<div class='check-item'><i class='bi bi-check-circle-fill check-icon' style='color: #10b981;'></i> <strong>UFW:</strong> Installé</div>"
        if [[ "$ufw_active" == "true" ]]; then
            firewall_checks_html+="<div class='check-item'><i class='bi bi-check-circle-fill check-icon' style='color: #10b981;'></i> <strong>Statut UFW:</strong> Actif</div>"
            firewall_checks_html+="<div class='check-item'><i class='bi bi-info-circle check-icon' style='color: #3b82f6;'></i> <strong>Règles UFW:</strong> $ufw_rules</div>"
        else
            firewall_checks_html+="<div class='check-item'><i class='bi bi-exclamation-triangle-fill check-icon' style='color: #f59e0b;'></i> <strong>Statut UFW:</strong> Inactif</div>"
        fi
    else
        firewall_checks_html="<div class='check-item'><i class='bi bi-x-circle-fill check-icon' style='color: #ef4444;'></i> <strong>UFW:</strong> Non installé</div>"
    fi
    firewall_checks_html=$(echo "$firewall_checks_html" | sed 's/[\/&]/\\&/g')
    
    # Générer les checks Users
    local users_checks_html=""
    local shell_users=$(echo "$json_content" | jq -r '.audits.users.accounts_with_shell // 0')
    local uid0_count=$(echo "$json_content" | jq -r '.audits.users.uid_0_accounts // 1')
    
    users_checks_html="<div class='check-item'><i class='bi bi-info-circle check-icon' style='color: #3b82f6;'></i> <strong>Comptes avec shell:</strong> $shell_users</div>"
    if [[ "$uid0_count" -eq 1 ]]; then
        users_checks_html+="<div class='check-item'><i class='bi bi-check-circle-fill check-icon' style='color: #10b981;'></i> <strong>Comptes UID 0:</strong> 1 (uniquement root)</div>"
    else
        users_checks_html+="<div class='check-item'><i class='bi bi-x-circle-fill check-icon' style='color: #ef4444;'></i> <strong>Comptes UID 0:</strong> $uid0_count (CRITIQUE!)</div>"
    fi
    users_checks_html=$(echo "$users_checks_html" | sed 's/[\/&]/\\&/g')
    
    # Remplacer les placeholders
    sed -i "s|{{SSH_CHECKS}}|$ssh_checks_html|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAIL2BAN_CHECKS}}|$fail2ban_checks_html|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FIREWALL_CHECKS}}|$firewall_checks_html|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{USERS_CHECKS}}|$users_checks_html|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{SSH_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAIL2BAN_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FIREWALL_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{UPDATES_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{USERS_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SCORE_TEXT_CLASS}}|$score_class|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{SSH_RECOMMENDATIONS}}||g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FAIL2BAN_RECOMMENDATIONS}}||g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{FIREWALL_RECOMMENDATIONS}}||g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{USERS_RECOMMENDATIONS}}||g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{UPDATES_RECOMMENDATIONS}}||g" "$HTML_OUTPUT_FILE"
    
    # Extraire les données Updates du JSON
    local updates_total=$(echo "$json_content" | jq -r '.audits.updates.total_updates // 0')
    local updates_security=$(echo "$json_content" | jq -r '.audits.updates.security_updates // 0')
    local reboot_required=$(echo "$json_content" | jq -r '.audits.updates.reboot_required')
    local reboot_text="Non"
    [[ "$reboot_required" == "true" ]] && reboot_text="Oui"
    
    sed -i "s|{{UPDATES_COUNT}}|$updates_total|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{SECURITY_UPDATES_COUNT}}|$updates_security|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{REBOOT_REQUIRED}}|$reboot_text|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{CRITICAL_RECOMMENDATIONS}}|<li>Consulter le fichier JSON pour les recommandations détaillées</li>|g" "$HTML_OUTPUT_FILE"
    sed -i "s|{{IMPROVEMENT_RECOMMENDATIONS}}|<li>Consulter le fichier JSON pour les améliorations suggérées</li>|g" "$HTML_OUTPUT_FILE"
    
    sed -i "s|{{JSON_FILE_PATH}}|../json/security-audit_latest.json|g" "$HTML_OUTPUT_FILE"
    
    ln -sf "$HTML_OUTPUT_FILE" "$HTML_LATEST"
    
    log_verbose "Rapport HTML généré: $HTML_OUTPUT_FILE"
}

# ============================================================================
# GESTION DES ALERTES
# ============================================================================

send_alerts() {
    local json_content=$(cat "$JSON_OUTPUT_FILE")
    local score=$(echo "$json_content" | grep -oP '(?<="score": )\d+')
    local status=$(echo "$json_content" | grep -oP '(?<="status": ")[^"]+')
    
    # Vérifier si on doit envoyer une alerte
    if [[ "$ALERT_ON_LOW_SCORE" == "true" && $score -lt $SECURITY_SCORE_MINIMUM ]]; then
        local hostname=$(hostname)
        local alert_message="🔒 *ALERTE SÉCURITÉ* - ${hostname}

⚠️ Score de sécurité: *${score}/100*
📊 Statut: *${status}*
🎯 Seuil minimum: ${SECURITY_SCORE_MINIMUM}/100

Le score de sécurité est en dessous du seuil acceptable.
Consultez le rapport complet pour les détails et recommandations."
        
        [[ "$ENABLE_EMAIL" == "true" ]] && send_email_alert "Security Audit - Score Faible (${score}/100)" "$alert_message"
        [[ "$ENABLE_TELEGRAM" == "true" ]] && send_telegram_alert "$alert_message"
    else
        log_verbose "Score acceptable ($score/$SECURITY_SCORE_MINIMUM), pas d'alerte"
    fi
}

# ============================================================================
# AIDE
# ============================================================================

show_help() {
    cat <<EOF
Usage: sudo $SCRIPT_NAME [OPTIONS]

Audit complet de la configuration de sécurité du VPS

OPTIONS:
    -h, --help              Afficher cette aide
    -v, --verbose           Mode verbeux
    -s, --silent            Mode silencieux
    --no-json               Ne pas générer de JSON
    --no-html               Ne pas générer de HTML
    --email EMAIL           Envoyer alerte si score < seuil
    --telegram TOKEN CHAT   Envoyer alerte Telegram

EXEMPLES:
    sudo ./$SCRIPT_NAME
    sudo ./$SCRIPT_NAME --verbose --email admin@example.com

SCORING:
    - SSH Configuration: /100
    - Fail2ban: /100
    - Firewall: /100
    - Mises à jour: /100
    - Utilisateurs: /100
    
    Score global: /100 (moyenne pondérée)
    
    Excellent: ≥85
    Good: 70-84
    Warning: 50-69
    Critical: <50

SORTIES:
    Terminal: Rapport détaillé avec score
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
    
    collect_audit_data
    display_terminal_output
    generate_html_output
    send_alerts
    
    local duration=$(calculate_duration "$start_time")
    log_verbose "Audit terminé en ${duration}s"
    
    echo "[$(date)] Security audit completed - Score: $(grep '"score"' "$JSON_OUTPUT_FILE" | head -1 | awk -F':' '{print $2}' | tr -d ' ,')/100" >> "$LOG_FILE"
}

main
exit 0
