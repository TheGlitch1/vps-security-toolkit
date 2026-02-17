#!/bin/bash
# filepath: /home/theglitch/tools/vps-security-toolkit/scripts/run.sh

SCRIPTS=(
  "vps-health-check.sh"
  "vps-intrusion-check.sh"
  "vps-security-audit.sh"
  "vps-ssh-analysis.sh"
)

for script in "${SCRIPTS[@]}"; do
  sudo ./"$script" "$@"
  if [ $? -ne 0 ]; then
    echo "Error: $script failed."
    exit 1
  fi
done

echo "All scripts executed successfully."