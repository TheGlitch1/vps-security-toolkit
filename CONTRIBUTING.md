# 🤝 Guide de Contribution

> Merci de votre intérêt pour contribuer à VPS Security Toolkit !

## 📋 Table des Matières

1. [Code de Conduite](#-code-de-conduite)
2. [Comment Contribuer](#-comment-contribuer)
3. [Processus de Pull Request](#-processus-de-pull-request)
4. [Style de Code](#-style-de-code)
5. [Standards de Commit](#-standards-de-commit)
6. [Structure du Projet](#-structure-du-projet)
7. [Tests](#-tests)
8. [Documentation](#-documentation)

---

## 📜 Code de Conduite

### Notre Engagement

Dans l'intérêt de favoriser un environnement ouvert et accueillant, nous nous engageons à faire de la participation à notre projet une expérience exempte de harcèlement pour tous.

### Comportements Attendus

- ✅ Utiliser un langage accueillant et inclusif
- ✅ Respecter les points de vue et expériences différents
- ✅ Accepter gracieusement les critiques constructives
- ✅ Se concentrer sur ce qui est meilleur pour la communauté
- ✅ Faire preuve d'empathie envers les autres membres

### Comportements Inacceptables

- ❌ Langage ou images sexualisés
- ❌ Trolling, commentaires insultants ou dérogatoires
- ❌ Harcèlement public ou privé
- ❌ Publication d'informations privées d'autrui sans permission
- ❌ Toute autre conduite raisonnablement inappropriée

---

## 🎯 Comment Contribuer

### Types de Contributions

Nous acceptons plusieurs types de contributions :

#### 🐛 Rapports de Bugs

- Utilisez le [template de bug report](.github/ISSUE_TEMPLATE/bug_report.md)
- Décrivez le comportement attendu vs observé
- Incluez les logs et messages d'erreur
- Spécifiez votre environnement (OS, version Bash, etc.)

#### ✨ Nouvelles Fonctionnalités

- Utilisez le [template de feature request](.github/ISSUE_TEMPLATE/feature_request.md)
- Décrivez le problème que la fonctionnalité résoudrait
- Proposez une solution ou des alternatives
- Expliquez les bénéfices pour les utilisateurs

#### 📝 Amélioration Documentation

- Corrections de typos
- Clarification d'instructions
- Ajout d'exemples
- Traductions

#### 🔧 Correctifs Code

- Corrections de bugs
- Optimisations de performance
- Refactoring
- Tests additionnels

### Workflow de Contribution

1. **Fork** le repository
2. **Cloner** votre fork localement
3. **Créer** une branche pour votre contribution
4. **Développer** votre fonctionnalité/correctif
5. **Tester** vos modifications
6. **Commiter** avec des messages clairs
7. **Pusher** vers votre fork
8. **Ouvrir** une Pull Request

---

## 🔄 Processus de Pull Request

### Avant de Soumettre

- [ ] Lire ce guide de contribution complet
- [ ] Vérifier qu'une issue existe ou en créer une
- [ ] Rechercher si une PR similaire existe déjà
- [ ] Tester localement sur Ubuntu 20.04/22.04/24.04
- [ ] Vérifier le style de code
- [ ] Mettre à jour la documentation si nécessaire

### Checklist de la PR

```markdown
## Description
[Décrivez vos changements]

## Type de Changement
- [ ] Bug fix (changement non-breaking qui corrige une issue)
- [ ] Nouvelle fonctionnalité (changement non-breaking qui ajoute une fonctionnalité)
- [ ] Breaking change (fix ou fonctionnalité qui casse la rétrocompatibilité)
- [ ] Documentation

## Tests
- [ ] Testé sur Ubuntu 20.04
- [ ] Testé sur Ubuntu 22.04
- [ ] Testé sur Ubuntu 24.04
- [ ] Validation JSON avec jq
- [ ] Scripts shellcheck sans erreurs

## Screenshots (si applicable)
[Ajouter screenshots]

## Issue Liée
Fixes #[numéro]
```

### Processus de Review

1. **Review automatique** : CI/CD checks (si configuré)
2. **Review manuelle** : Par un mainteneur
3. **Demandes de changements** : Si nécessaire
4. **Approbation** : Après validation
5. **Merge** : Par un mainteneur

### Critères d'Acceptation

- ✅ Code conforme au style guide
- ✅ Tests passent sur toutes les versions Ubuntu
- ✅ Documentation mise à jour
- ✅ Commits bien formatés
- ✅ Pas de conflits avec master
- ✅ Review approuvée par au moins 1 mainteneur

---

## 💻 Style de Code

### Principes Généraux

1. **Lisibilité** > Concision
2. **Cohérence** avec le code existant
3. **Commentaires** pour la logique complexe
4. **Gestion d'erreurs** robuste

### Shell Script (Bash)

#### Shebang et Version

```bash
#!/usr/bin/env bash
# Nécessite Bash 4.0+
```

#### Indentation

- **4 espaces** (pas de tabs)
- Aligner les paramètres multilignes

```bash
# ✅ Bon
if [[ "$status" == "OK" ]]; then
    echo "Everything is fine"
fi

# ❌ Mauvais
if [[ "$status" == "OK" ]]; then
  echo "Everything is fine"  # 2 espaces
fi
```

#### Nommage

```bash
# Variables globales : MAJUSCULES
LOG_DIR="/var/log/vps-toolkit"
CPU_WARNING=80

# Variables locales : snake_case
local cpu_usage=50
local disk_free="10G"

# Fonctions : snake_case avec verbes
check_cpu_usage() {
    ...
}

get_disk_space() {
    ...
}

# Constantes : readonly
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="vps-health-check"
```

#### Guillemets

```bash
# ✅ Toujours guillemeter les variables
echo "$my_variable"
cp "$source" "$destination"

# ❌ Pas de guillemets = risque d'erreurs
echo $my_variable  # Mauvais
```

#### Conditions

```bash
# ✅ Utiliser [[ ]] (Bash moderne)
if [[ "$var" == "value" ]]; then
    ...
fi

# ✅ Vérifier variables vides
if [[ -z "$var" ]]; then
    echo "Variable is empty"
fi

# ✅ Vérifier fichiers
if [[ -f "/path/to/file" ]]; then
    echo "File exists"
fi
```

#### Fonctions

```bash
# ✅ Documentation des fonctions
##
# Description courte de la fonction
#
# Arguments:
#   $1 - Description du premier argument
#   $2 - Description du deuxième argument
# Returns:
#   0 on success, 1 on error
# Globals:
#   LOG_DIR - Directory for logs
##
my_function() {
    local arg1="$1"
    local arg2="$2"
    
    # Validation
    if [[ -z "$arg1" ]]; then
        echo "Error: arg1 required"
        return 1
    fi
    
    # Logique
    ...
    
    return 0
}
```

#### Gestion d'Erreurs

```bash
# ✅ set -euo pipefail au début du script
set -euo pipefail

# ✅ Vérifier les codes de retour
if ! command -v jq &> /dev/null; then
    echo "Error: jq not installed"
    exit 1
fi

# ✅ Trap pour cleanup
cleanup() {
    rm -f "$temp_file"
}
trap cleanup EXIT
```

#### Shellcheck

Tous les scripts doivent passer **shellcheck** sans erreurs.

```bash
# Installer shellcheck
sudo apt install shellcheck

# Vérifier un script
shellcheck scripts/vps-health-check.sh

# Ignorer certains warnings (justifié)
# shellcheck disable=SC2034
UNUSED_VAR="value"  # Utilisé par sourced script
```

### JSON Output

```bash
# ✅ JSON valide et bien formaté
cat > output.json <<EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "OK",
    "data": {
        "cpu": 50,
        "ram": 75
    }
}
EOF

# Toujours valider avec jq
jq '.' output.json > /dev/null
```

### Couleurs et Formatage

```bash
# Utiliser les fonctions de shared-functions.sh
print_header "Section Title"
print_success "Operation successful"
print_warning "Warning message"
print_error "Error message"
print_info "Information"

# Ne pas hardcoder les codes ANSI
# ❌ Mauvais
echo -e "\033[32mGreen text\033[0m"

# ✅ Bon
echo "${COLOR_GREEN}Green text${COLOR_RESET}"
```

---

## 📝 Standards de Commit

### Format des Messages

```
type(scope): subject

[body optionnel]

[footer optionnel]
```

### Types de Commit

- **feat**: Nouvelle fonctionnalité
- **fix**: Correction de bug
- **docs**: Documentation uniquement
- **style**: Formatage (pas de changement de code)
- **refactor**: Refactoring (ni fix ni feat)
- **perf**: Amélioration de performance
- **test**: Ajout ou correction de tests
- **chore**: Maintenance (dépendances, config, etc.)

### Scope

Le composant affecté :
- `health-check`
- `security-audit`
- `ssh-analysis`
- `intrusion-check`
- `setup`
- `config`
- `docs`

### Exemples

```bash
# Feature
git commit -m "feat(health-check): Add temperature monitoring with lm-sensors"

# Bug fix
git commit -m "fix(ssh-analysis): Handle empty auth.log gracefully"

# Documentation
git commit -m "docs(readme): Add installation troubleshooting section"

# Refactoring
git commit -m "refactor(shared-functions): Simplify send_alert function"

# Performance
git commit -m "perf(intrusion-check): Cache SUID file list for 24h"

# Multiple paragraphes
git commit -m "fix(security-audit): Correct SSH config parsing

The parser was failing on commented lines. Added filtering
to skip lines starting with #.

Fixes #42"
```

### Bonnes Pratiques

- **Présent impératif** : "Add feature" pas "Added feature"
- **Première lettre minuscule** dans le subject
- **Pas de point** à la fin du subject
- **Ligne de 50 caractères** max pour subject
- **Ligne de 72 caractères** max pour body
- **Référencer les issues** : "Fixes #123", "Closes #456"

---

## 🏗️ Structure du Projet

```
vps-security-toolkit/
├── scripts/
│   ├── shared-functions.sh      # Fonctions communes
│   ├── vps-health-check.sh      # Script health check
│   ├── vps-security-audit.sh    # Script security audit
│   ├── vps-ssh-analysis.sh      # Script SSH analysis
│   └── vps-intrusion-check.sh   # Script intrusion check
├── config/
│   ├── vps-toolkit.conf.example # Configuration exemple
│   └── cron-examples/           # Exemples cron
├── tests/
│   ├── test-email-alert.sh      # Test alertes email
│   └── test-telegram-alert.sh   # Test alertes Telegram
├── .github/
│   ├── ISSUE_TEMPLATE/          # Templates d'issues
│   └── FUNDING.yml              # Sponsorship
├── docs/                        # Documentation additionnelle
├── INSTALL.md                   # Guide d'installation
├── USAGE.md                     # Guide d'utilisation
├── CONTRIBUTING.md              # Ce fichier
├── CHANGELOG.md                 # Historique des versions
├── README.md                    # Présentation du projet
├── LICENSE                      # Licence MIT
└── VERSION                      # Version actuelle
```

### Ajouter un Nouveau Script

1. Créer le script dans `scripts/`
2. Sourcer `shared-functions.sh`
3. Implémenter les fonctions requises :
   - `check_dependencies()`
   - `generate_json_output()`
   - `generate_html_output()`
   - `main()`
4. Ajouter la documentation dans `USAGE.md`
5. Ajouter des tests
6. Mettre à jour `CHANGELOG.md`

### Modifier une Fonction Partagée

1. **Attention** : Impact sur tous les scripts
2. Tester **tous les scripts** après modification
3. Documenter le changement
4. Vérifier la rétrocompatibilité

---

## 🧪 Tests

### Tests Manuels Requis

Avant chaque PR, tester sur :

#### Ubuntu 24.04 (Priorité 1)
```bash
# Health Check
sudo ./scripts/vps-health-check.sh --verbose
sudo ./scripts/vps-health-check.sh --silent

# Security Audit
sudo ./scripts/vps-security-audit.sh --verbose

# SSH Analysis
sudo ./scripts/vps-ssh-analysis.sh --period 24h --verbose
sudo ./scripts/vps-ssh-analysis.sh --period 7d --no-geo

# Intrusion Check
sudo ./scripts/vps-intrusion-check.sh --verbose
sudo ./scripts/vps-intrusion-check.sh --hours 48
```

#### Ubuntu 22.04 (Priorité 2)
```bash
# Tests minimaux
sudo ./scripts/vps-health-check.sh
sudo ./scripts/vps-security-audit.sh
sudo ./scripts/vps-ssh-analysis.sh
sudo ./scripts/vps-intrusion-check.sh
```

#### Ubuntu 20.04 (Priorité 3)
```bash
# Test de compatibilité
sudo ./scripts/vps-health-check.sh
```

### Validation JSON

Tous les outputs JSON doivent être valides :

```bash
# Valider avec jq
for file in /var/log/vps-toolkit/json/*.json; do
    echo "Validating $file..."
    jq '.' "$file" > /dev/null || echo "❌ Invalid JSON: $file"
done
```

### Shellcheck

Tous les scripts doivent passer shellcheck :

```bash
# Check tous les scripts
for script in scripts/*.sh; do
    echo "Checking $script..."
    shellcheck "$script" || exit 1
done
```

### Tests d'Alerte

```bash
# Email
sudo ./tests/test-email-alert.sh votre-email@example.com

# Telegram
sudo ./tests/test-telegram-alert.sh
```

### Créer des Tests

Pour ajouter des tests :

1. Créer un script dans `tests/`
2. Nommer `test-*.sh`
3. Rendre exécutable : `chmod +x tests/test-*.sh`
4. Documenter dans `USAGE.md`

---

## 📚 Documentation

### Documentation Requise

Pour chaque contribution, mettre à jour :

#### Nouveau Script
- [ ] Docstring en en-tête du script
- [ ] Commentaires dans le code
- [ ] Section dans [USAGE.md](USAGE.md)
- [ ] Mention dans [README.md](README.md)
- [ ] Exemple cron dans [INSTALL.md](INSTALL.md)

#### Nouvelle Fonctionnalité
- [ ] Commentaires dans le code
- [ ] Mise à jour [USAGE.md](USAGE.md)
- [ ] Mise à jour [CHANGELOG.md](CHANGELOG.md)

#### Bug Fix
- [ ] Commentaire expliquant le fix
- [ ] Mise à jour [CHANGELOG.md](CHANGELOG.md)

### Style de Documentation

#### Markdown

```markdown
# Titre H1 (page)

## Titre H2 (section)

### Titre H3 (sous-section)

**Gras** pour l'emphase
*Italique* pour les termes techniques
`code` pour les commandes
```

#### Blocs de Code

````markdown
```bash
# Commande avec commentaire
sudo ./script.sh --option value
```
````

#### Listes

```markdown
- Item 1
- Item 2
  - Sous-item 2.1
  - Sous-item 2.2
```

#### Tables

```markdown
| Colonne 1 | Colonne 2 | Colonne 3 |
|-----------|-----------|-----------|
| Valeur 1  | Valeur 2  | Valeur 3  |
```

#### Liens

```markdown
[Texte du lien](URL)
[Référence][ref]

[ref]: URL "Titre optionnel"
```

---

## 🎖️ Reconnaissance des Contributeurs

Les contributeurs sont listés dans le [README.md](README.md) :

- Issues rapportées
- Pull Requests mergées
- Documentation améliorée
- Tests ajoutés

---

## 📞 Contact

- **Issues** : https://github.com/TheGlitch1/vps-security-toolkit/issues
- **Discussions** : https://github.com/TheGlitch1/vps-security-toolkit/discussions
- **Email** : (voir profil GitHub)

---

## 📄 Licence

En contribuant, vous acceptez que vos contributions soient sous [licence MIT](LICENSE).

---

## 🙏 Merci !

Merci de prendre le temps de contribuer à VPS Security Toolkit ! 

Chaque contribution, petite ou grande, est précieuse pour améliorer la sécurité des VPS Ubuntu. 🚀

---

**Questions ?** N'hésitez pas à ouvrir une [issue](https://github.com/TheGlitch1/vps-security-toolkit/issues) !
