# 📐 HTML Templates

> Templates HTML professionnels pour les rapports VPS Security Toolkit

## 🎨 Technologies Utilisées

- **Bootstrap 5.3.2** - Framework CSS responsive
- **Bootstrap Icons 1.11.3** - Icônes vectorielles
- **Chart.js 4.4.1** - Graphiques interactifs
- **DataTables 1.13.7** - Tables de données interactives avec recherche/tri/export
- **jQuery 3.7.1** - Requis par DataTables

## 📁 Templates Disponibles

### 1. `health-check.html`
**Dashboard de monitoring système en temps réel**

**Fonctionnalités:**
- 🎯 Cartes métriques colorées (CPU, RAM, Disk, Uptime)
- 📊 Graphiques doughnut et bar pour CPU/RAM
- 📈 Barres de progression animées
- 🔍 DataTable pour l'utilisation disque
- 🟢 Statut des services (SSH, Cron, Fail2ban)
- 📡 Statistiques réseau et processus
- 🖨️ Export PDF et JSON

**Placeholders:**
```
{{HOSTNAME}}, {{TIMESTAMP}}, {{VERSION}}
{{STATUS_CLASS}}, {{STATUS_VALUE}}
{{CPU_VALUE}}, {{RAM_VALUE}}, {{DISK_VALUE}}, {{UPTIME_DAYS}}
{{CRITICAL_COUNT}}, {{WARNING_COUNT}}, {{SERVICES_ACTIVE}}
{{CPU_CORES}}, {{CPU_USAGE}}, {{CPU_TEMP}}
{{RAM_TOTAL}}, {{RAM_USED}}, {{RAM_FREE}}, {{RAM_PERCENT}}
{{SWAP_TOTAL}}, {{SWAP_USED}}, {{SWAP_FREE}}, {{SWAP_PERCENT}}
{{DISK_ROWS}} (HTML table rows)
{{SSH_STATUS}}, {{CRON_STATUS}}, {{FAIL2BAN_STATUS}}
{{CONNECTIONS_ESTABLISHED}}, {{LISTENING_PORTS}}, {{TIME_WAIT}}
{{PROCESS_TOTAL}}, {{PROCESS_RUNNING}}, {{PROCESS_ZOMBIE}}
{{JSON_FILE_PATH}}
```

---

### 2. `security-audit.html`
**Dashboard d'audit de sécurité avec scoring**

**Fonctionnalités:**
- 🎯 Score global circulaire coloré (0-100)
- 📊 Graphique radar des 5 catégories
- 📈 Graphique bar horizontal des scores
- ✅ Checks détaillés par catégorie (SSH, Fail2ban, Firewall, Updates, Users)
- 💡 Recommandations prioritaires
- 🎨 Code couleur (Excellent/Good/Warning/Critical)
- 🖨️ Export PDF et JSON

**Placeholders:**
```
{{HOSTNAME}}, {{TIMESTAMP}}, {{VERSION}}
{{SCORE}}, {{SCORE_CLASS}}, {{SCORE_LABEL}}
{{SCORE_SSH}}, {{SCORE_FAIL2BAN}}, {{SCORE_FIREWALL}}, {{SCORE_UPDATES}}, {{SCORE_USERS}}
{{SSH_CLASS}}, {{SSH_CHECKS}}, {{SSH_RECOMMENDATIONS}}
{{FAIL2BAN_CLASS}}, {{FAIL2BAN_CHECKS}}, {{FAIL2BAN_RECOMMENDATIONS}}
{{FIREWALL_CLASS}}, {{FIREWALL_CHECKS}}, {{FIREWALL_RECOMMENDATIONS}}
{{UPDATES_CLASS}}, {{UPDATES_COUNT}}, {{SECURITY_UPDATES_COUNT}}, {{REBOOT_REQUIRED}}
{{USERS_CLASS}}, {{USERS_CHECKS}}, {{USERS_RECOMMENDATIONS}}
{{CRITICAL_RECOMMENDATIONS}}, {{IMPROVEMENT_RECOMMENDATIONS}}
{{JSON_FILE_PATH}}
```

---

### 3. `ssh-analysis.html`
**Dashboard d'analyse des attaques SSH**

**Fonctionnalités:**
- 🎯 Cartes statistiques (échecs, IPs, users invalides, logins OK)
- 📊 Graphique doughnut pour distribution géographique
- 📈 Graphique line pour timeline des attaques
- 🏆 Top 3 attackers avec badges (gold/silver/bronze)
- 🔍 DataTable complète des top attackers avec export CSV/Excel
- 🗺️ Distribution géographique avec badges pays
- ⚠️ Détection patterns (brute force, port scan, dictionary, root attacks)
- 🛡️ Statut Fail2ban
- 🖨️ Export PDF, JSON, CSV

**Placeholders:**
```
{{HOSTNAME}}, {{TIMESTAMP}}, {{VERSION}}, {{PERIOD}}
{{FAILED_ATTEMPTS}}, {{UNIQUE_IPS}}, {{INVALID_USERS}}, {{SUCCESSFUL_LOGINS}}
{{ROOT_ATTACKS}}, {{BANNED_IPS}}, {{COUNTRIES_COUNT}}
{{BRUTE_FORCE_COUNT}}, {{PORT_SCAN_COUNT}}, {{DICTIONARY_USERS}}, {{ROOT_ATTACK_SOURCES}}
{{TOP_3_CARDS}} (HTML cards)
{{GEO_LABELS}}, {{GEO_DATA}} (JSON arrays pour Chart.js)
{{TIMELINE_LABELS}}, {{TIMELINE_DATA}} (JSON arrays)
{{COUNTRY_BADGES}} (HTML badges)
{{ATTACKERS_ROWS}} (HTML table rows)
{{SSH_KEY_LOGINS}}, {{PASSWORD_LOGINS}}, {{SUCCESSFUL_IPS}}
{{FAIL2BAN_STATUS}}, {{FAIL2BAN_BANNED}}, {{FAIL2BAN_JAILS}}
{{JSON_FILE_PATH}}
```

---

### 4. `intrusion-check.html`
**Dashboard de détection d'intrusion**

**Fonctionnalités:**
- 🎯 Header de statut global (OK/Suspicious/Warning/Critical)
- 📊 Compteurs d'issues (Critiques, Avertissements, Suspects)
- 📈 Graphique doughnut de répartition des issues
- 🔍 7 checks détaillés avec cartes colorées
- 📡 DataTable des ports en écoute
- 📁 Liste des fichiers SUID avec marquage critique
- ⏱️ Timeline des modifications système
- 💡 Recommandations d'actions
- 🖨️ Export PDF et JSON

**Placeholders:**
```
{{HOSTNAME}}, {{TIMESTAMP}}, {{VERSION}}, {{HOURS}}
{{STATUS_CLASS}}, {{STATUS_ICON}}, {{STATUS_TEXT}}
{{CRITICAL_COUNT}}, {{WARNING_COUNT}}, {{SUSPICIOUS_COUNT}}
{{SESSIONS_COUNT}}, {{SESSIONS_STATUS_CLASS}}, {{SESSIONS_STATUS}}, {{SESSIONS_LIST}}
{{PROCESSES_SUSPECT}}, {{PROCESSES_STATUS_CLASS}}, {{PROCESSES_STATUS}}
{{MINERS_COUNT}}, {{HIGH_CPU_COUNT}}, {{BACKDOORS_COUNT}}, {{PROCESSES_DETAILS}}
{{PORTS_TOTAL}}, {{PORTS_UNUSUAL}}, {{PORTS_STATUS_CLASS}}, {{PORTS_STATUS}}, {{PORTS_ROWS}}
{{SUID_TOTAL}}, {{SUID_SUSPICIOUS}}, {{SUID_STATUS_CLASS}}, {{SUID_STATUS}}, {{SUID_FILES}}
{{MODIFICATIONS_COUNT}}, {{MODIFICATIONS_STATUS_CLASS}}, {{MODIFICATIONS_STATUS}}, {{MODIFICATIONS_TIMELINE}}
{{CONNECTIONS_TOTAL}}, {{CONNECTIONS_SUSPICIOUS}}, {{CONNECTIONS_EXTERNAL}}
{{CONNECTIONS_DETAILS}}, {{NETWORK_STATUS_CLASS}}, {{NETWORK_STATUS}}
{{HIDDEN_COUNT}}, {{HIDDEN_TMP}}, {{HIDDEN_VAR_TMP}}, {{HIDDEN_SHM}}
{{HIDDEN_STATUS_CLASS}}, {{HIDDEN_STATUS}}, {{HIDDEN_FILES_LIST}}
{{RECOMMENDATIONS}}
{{JSON_FILE_PATH}}
```

---

## 🚀 Utilisation

### Méthode 1: Remplacement de placeholders (Simple)

Les scripts Bash lisent le template et remplacent les `{{PLACEHOLDER}}` par les valeurs réelles :

```bash
# Exemple dans vps-health-check.sh
local html_content=$(cat templates/health-check.html)
html_content=${html_content//\{\{HOSTNAME\}\}/"$(hostname)"}
html_content=${html_content//\{\{CPU_VALUE\}\}/"$cpu_usage"}
echo "$html_content" > "$HTML_OUTPUT_FILE"
```

### Méthode 2: Avec sed (Robuste)

```bash
# Copier le template
cp templates/health-check.html "$HTML_OUTPUT_FILE"

# Remplacer les placeholders
sed -i "s/{{HOSTNAME}}/$(hostname)/g" "$HTML_OUTPUT_FILE"
sed -i "s/{{CPU_VALUE}}/$cpu_usage/g" "$HTML_OUTPUT_FILE"
sed -i "s/{{RAM_VALUE}}/$ram_usage/g" "$HTML_OUTPUT_FILE"
```

### Méthode 3: Template engine (Avancé)

Utiliser un template engine Bash comme `envsubst` ou créer une fonction dédiée.

---

## 🎨 Personnalisation

### Modifier les Couleurs

Chaque template utilise des gradients CSS personnalisables :

```css
/* health-check.html */
.metric-card.cpu { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }

/* security-audit.html */
.status-excellent { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }

/* ssh-analysis.html */
body { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }

/* intrusion-check.html */
body { background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); }
```

### Modifier les Graphiques

Charts.js est configuré dans le `<script>` en bas de chaque template. Modifiez les options selon vos besoins :

```javascript
options: {
    responsive: true,
    maintainAspectRatio: false,
    // Vos options personnalisées
}
```

### Ajouter des Sections

1. Ajoutez le HTML avec les placeholders
2. Ajoutez les styles CSS nécessaires
3. Mettez à jour le script Bash pour remplir les placeholders

---

## 📊 Graphiques Inclus

### health-check.html
- **CPU Doughnut**: Utilisation CPU (used/free)
- **Memory Bar**: Comparaison RAM/SWAP

### security-audit.html
- **Radar Chart**: 5 catégories de sécurité
- **Horizontal Bar**: Scores détaillés

### ssh-analysis.html
- **Geographic Doughnut**: Répartition par pays
- **Timeline Line**: Évolution temporelle
- **Fail2ban Doughnut**: IPs bannies vs actives

### intrusion-check.html
- **Summary Doughnut**: Critiques/Warnings/Suspects/OK
- **Connections Bar**: Total/Externes/Suspectes

---

## 🔧 Fonctionnalités DataTables

Toutes les tables interactives incluent :
- ✅ Recherche en temps réel
- ✅ Tri par colonne
- ✅ Pagination
- ✅ Export CSV/Excel/PDF/Print
- ✅ Affichage responsive
- ✅ Traduction française

---

## 📱 Responsive Design

Tous les templates sont **100% responsive** grâce à Bootstrap 5 :
- Desktop (> 1200px) : Affichage complet
- Tablet (768px - 1199px) : Layout adapté
- Mobile (< 768px) : Colonnes empilées, navigation simplifiée

---

## 🖨️ Export et Impression

Chaque dashboard inclut :
- **Print** : CSS optimisé pour l'impression
- **Export JSON** : Téléchargement du rapport JSON
- **Export CSV** : Pour les tables (DataTables)

---

## 🎯 Classes CSS Utilitaires

### Status Classes
- `.status-ok` / `.badge-ok` - Vert (succès)
- `.status-suspicious` / `.badge-suspicious` - Cyan (info)
- `.status-warning` / `.badge-warning` - Jaune (warning)
- `.status-critical` / `.badge-critical` - Rouge (danger)

### Score Classes
- `.score-excellent` - Score ≥ 85
- `.score-good` - Score 70-84
- `.score-warning` - Score 50-69
- `.score-critical` - Score < 50

---

## 💡 Best Practices

1. **Échapper les caractères spéciaux** : Utilisez `sed` avec le bon délimiteur
2. **Valider le JSON** : Assurez-vous que les arrays JSON sont bien formés
3. **Tester les placeholders** : Vérifiez qu'aucun `{{PLACEHOLDER}}` ne reste
4. **Optimiser les images** : Pas d'images incluses, tout en CSS/SVG
5. **Minifier en production** : Compresser le HTML final si besoin

---

## 🔗 CDN Utilisés

Tous les templates utilisent des CDN publics :
- Bootstrap: `cdn.jsdelivr.net/npm/bootstrap@5.3.2`
- Bootstrap Icons: `cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3`
- Chart.js: `cdn.jsdelivr.net/npm/chart.js@4.4.1`
- DataTables: `cdn.datatables.net/1.13.7`
- jQuery: `code.jquery.com/jquery-3.7.1`

**Avantages:**
- ✅ Pas d'installation locale
- ✅ Cache navigateur
- ✅ Toujours à jour

**Alternative offline:**
Téléchargez les librairies localement si nécessaire.

---

## 📚 Documentation Externe

- [Bootstrap 5](https://getbootstrap.com/docs/5.3/)
- [Chart.js](https://www.chartjs.org/docs/latest/)
- [DataTables](https://datatables.net/manual/)
- [Bootstrap Icons](https://icons.getbootstrap.com/)

---

## 🤝 Contribution

Pour améliorer les templates :
1. Testez sur tous les navigateurs (Chrome, Firefox, Safari, Edge)
2. Vérifiez le responsive (mobile, tablet, desktop)
3. Validez le HTML avec W3C Validator
4. Documentez les nouveaux placeholders
5. Soumettez une Pull Request

---

**Templates HTML prêts pour production !** 🚀
