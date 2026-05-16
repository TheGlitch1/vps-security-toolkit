#!/bin/bash
# =============================================================================
# FAIL2BAN → IPSET AUTO-FEED INSTALLATION GUIDE
# =============================================================================
# This script shows all commands needed to configure fail2ban to automatically
# add banned IPs to your permanent IPSet blacklist
#
# DO NOT RUN THIS SCRIPT DIRECTLY!
# Copy and paste commands one by one to understand what's happening
# =============================================================================

echo "=========================================="
echo "FAIL2BAN → IPSET SETUP GUIDE"
echo "=========================================="
echo ""

# =============================================================================
# STEP 1: VERIFY YOUR ENVIRONMENT
# =============================================================================
echo "STEP 1: Verify your current setup"
echo "-----------------------------------"

# Check fail2ban is running
echo "Checking fail2ban status..."
sudo systemctl status fail2ban --no-pager | head -5

# Check ipset is installed
echo "Checking ipset..."
which ipset && ipset --version

# Check your permanent blacklist exists
echo "Checking blacklist-permanent..."
sudo ipset list blacklist-permanent -n

# Check current fail2ban actions
echo "Current fail2ban actions for sshd:"
sudo fail2ban-client get sshd actions

echo ""
echo "✅ If all checks passed, continue to Step 2"
echo ""

# =============================================================================
# STEP 2: BACKUP YOUR CONFIGURATION
# =============================================================================
echo "STEP 2: Backup current configuration"
echo "--------------------------------------"

# Backup jail.local
echo "Creating backup..."
sudo cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d_%H%M%S)

# Verify backup
echo "Backup created:"
ls -lh /etc/fail2ban/jail.local.backup.*

echo ""
echo "✅ Configuration backed up"
echo ""

# =============================================================================
# STEP 3: INSTALL CUSTOM ACTION FILE
# =============================================================================
echo "STEP 3: Install custom fail2ban action"
echo "---------------------------------------"

# Choose ONE of these options:

echo "OPTION A: Simple - All banned IPs go to permanent list"
echo "-------------------------------------------------------"
cat << 'EOF_ACTION' | sudo tee /etc/fail2ban/action.d/ipset-blacklist-permanent.conf
[Definition]

actionstart = 

actionstop = 

actioncheck = 

actionban = ipset -exist add <ipmset> <ip>
            logger -t fail2ban-permanent "Added <ip> to permanent blacklist - Jail: <name>"

actionunban = 

[Init]

ipmset = blacklist-permanent
name = default
EOF_ACTION

echo ""
echo "OR"
echo ""

echo "OPTION B: Smart - Only repeat offenders (RECOMMENDED)"
echo "-----------------------------------------------------"
cat << 'EOF_REPEAT' | sudo tee /etc/fail2ban/action.d/ipset-repeat-offender.conf
[Definition]

actionstart = 

actionstop = 

actioncheck = 

actionban = if [ -f /var/lib/fail2ban/fail2ban.sqlite3 ]; then
                ban_count=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "SELECT COUNT(*) FROM bans WHERE ip='<ip>' AND jail='<name>';" 2>/dev/null || echo 1)
            else
                ban_count=1
            fi
            if [ "$ban_count" -ge <repeat_threshold> ]; then
                ipset -exist add <ipmset> <ip>
                logger -t fail2ban-repeat "REPEAT OFFENDER <ip> added to permanent blacklist - Ban count: $ban_count"
            else
                logger -t fail2ban-repeat "IP <ip> banned (count: $ban_count, threshold: <repeat_threshold>)"
            fi

actionunban = 

[Init]

ipmset = blacklist-permanent
repeat_threshold = 2
name = default
destemail = root@localhost
EOF_REPEAT

# Set correct permissions
echo "Setting permissions..."
sudo chmod 644 /etc/fail2ban/action.d/ipset-*.conf

echo ""
echo "✅ Action file installed"
echo ""

# =============================================================================
# STEP 4: MODIFY JAIL CONFIGURATION
# =============================================================================
echo "STEP 4: Update jail.local configuration"
echo "----------------------------------------"

echo "Open your jail.local for editing:"
echo "  sudo nano /etc/fail2ban/jail.local"
echo ""
echo "Find the [sshd] section and modify the 'action' line:"
echo ""

echo "FOR OPTION A (All banned → permanent):"
echo "---------------------------------------"
cat << 'EOF_JAIL_A'
[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s
maxretry = 3
bantime  = 86400
findtime = 600
destemail = examplemail@gmail.com
sendername = Fail2ban-VPS
mta = mail
action = %(action_)s
         ipset-blacklist-permanent[name=sshd]
         mail-buffered[name=sshd, dest="examplemail@gmail.com", sender="fail2ban@vmi"]
EOF_JAIL_A

echo ""
echo "FOR OPTION B (Repeat offenders only - RECOMMENDED):"
echo "----------------------------------------------------"
cat << 'EOF_JAIL_B'
[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s
maxretry = 3
bantime  = 86400
findtime = 600
destemail = examplemail@gmail.com
sendername = Fail2ban-VPS
mta = mail
action = %(action_)s
         ipset-repeat-offender[name=sshd, repeat_threshold=2, destemail="examplemail@gmail.com"]
         mail-buffered[name=sshd, dest="examplemail@gmail.com", sender="fail2ban@vmi"]
EOF_JAIL_B

echo ""
echo "After editing, save the file (Ctrl+O, Enter, Ctrl+X in nano)"
echo ""

# =============================================================================
# STEP 5: TEST CONFIGURATION
# =============================================================================
echo "STEP 5: Test configuration"
echo "--------------------------"

echo "Test fail2ban configuration syntax:"
echo "  sudo fail2ban-client -t"
echo ""

# =============================================================================
# STEP 6: RESTART FAIL2BAN
# =============================================================================
echo "STEP 6: Restart fail2ban"
echo "------------------------"

echo "Restart fail2ban to apply changes:"
echo "  sudo systemctl restart fail2ban"
echo ""
echo "Check status:"
echo "  sudo systemctl status fail2ban --no-pager"
echo ""

# =============================================================================
# STEP 7: VERIFY SETUP
# =============================================================================
echo "STEP 7: Verify the new action is active"
echo "----------------------------------------"

echo "Check sshd jail actions:"
echo "  sudo fail2ban-client get sshd actions"
echo ""
echo "You should see 'ipset-blacklist-permanent' or 'ipset-repeat-offender' in the list"
echo ""

# =============================================================================
# STEP 8: MONITOR & TEST
# =============================================================================
echo "STEP 8: Monitor and test"
echo "------------------------"

echo "Monitor fail2ban log in real-time:"
echo "  sudo tail -f /var/log/fail2ban.log"
echo ""
echo "Monitor syslog for permanent blacklist additions:"
echo "  sudo journalctl -f | grep fail2ban-permanent"
echo ""
echo "OR for repeat offenders:"
echo "  sudo journalctl -f | grep fail2ban-repeat"
echo ""

echo "Check blacklist size:"
echo "  sudo ipset list blacklist-permanent | grep 'Number of entries'"
echo ""

# =============================================================================
# TESTING (OPTIONAL - BE CAREFUL!)
# =============================================================================
echo "=========================================="
echo "OPTIONAL: TESTING"
echo "=========================================="
echo ""
echo "⚠️  WARNING: Only test from a different IP that you can afford to block!"
echo ""
echo "To test from another machine:"
echo "1. Try to SSH with wrong password 3 times"
echo "2. Check if IP gets banned:"
echo "   sudo fail2ban-client status sshd"
echo "3. Check if IP was added to permanent blacklist:"
echo "   sudo ipset list blacklist-permanent | grep YOUR_TEST_IP"
echo ""
echo "To unban a test IP:"
echo "   sudo fail2ban-client set sshd unbanip YOUR_TEST_IP"
echo "To remove from permanent blacklist:"
echo "   sudo ipset del blacklist-permanent YOUR_TEST_IP"
echo ""

# =============================================================================
# TROUBLESHOOTING
# =============================================================================
echo "=========================================="
echo "TROUBLESHOOTING"
echo "=========================================="
echo ""
echo "If fail2ban won't start:"
echo "  sudo fail2ban-client -t                    # Test config syntax"
echo "  sudo journalctl -xeu fail2ban              # Check errors"
echo ""
echo "If IPs aren't being added to permanent list:"
echo "  sudo journalctl -f | grep ipset            # Monitor ipset commands"
echo "  sudo ipset list blacklist-permanent        # Check list contents"
echo "  sudo fail2ban-client get sshd actions      # Verify action is loaded"
echo ""
echo "To restore original config:"
echo "  sudo cp /etc/fail2ban/jail.local.backup.* /etc/fail2ban/jail.local"
echo "  sudo systemctl restart fail2ban"
echo ""

# =============================================================================
# MAINTENANCE
# =============================================================================
echo "=========================================="
echo "MAINTENANCE COMMANDS"
echo "=========================================="
echo ""
echo "View all permanently banned IPs:"
echo "  sudo ipset list blacklist-permanent"
echo ""
echo "Remove specific IP from permanent blacklist:"
echo "  sudo ipset del blacklist-permanent 1.2.3.4"
echo ""
echo "Clear entire permanent blacklist (nuclear option):"
echo "  sudo ipset flush blacklist-permanent"
echo ""
echo "Check how many IPs are permanently banned:"
echo "  sudo ipset list blacklist-permanent | grep 'Number of entries'"
echo ""
echo "View fail2ban statistics:"
echo "  sudo fail2ban-client status sshd"
echo ""

echo "=========================================="
echo "SETUP COMPLETE!"
echo "=========================================="
