#!/bin/bash
#
# Module: ssh-hardening
# Category: setup
#
# Hardens SSH configuration for better security.
#

# --- Strict Mode ---
set -euo pipefail

echo "Hardening SSH configuration..."

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Create a secure SSH configuration
cat > /etc/ssh/sshd_config.new << 'EOF'
# SSH Configuration - Hardened by Enterprise Provisioner

# Network settings
Port 22
AddressFamily inet
ListenAddress 0.0.0.0

# Protocol and encryption
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
LoginGraceTime 30
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 2
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security features
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression delayed
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel INFO

# SFTP subsystem
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO

# Banner (optional)
# Banner /etc/issue.net
EOF

# Test the new configuration
if sshd -t -f /etc/ssh/sshd_config.new; then
    echo "New SSH configuration is valid. Applying..."
    mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
    
    echo "Restarting SSH service..."
    systemctl restart ssh
    
    echo "SSH hardening complete!"
    echo ""
    echo "IMPORTANT SECURITY CHANGES APPLIED:"
    echo "- Root login disabled"
    echo "- Maximum 3 authentication attempts"
    echo "- Connection timeout after 5 minutes of inactivity"
    echo "- X11 forwarding disabled"
    echo ""
    echo "Please test SSH access in a new terminal before closing this session!"
else
    echo "ERROR: New SSH configuration is invalid. Keeping original configuration."
    rm -f /etc/ssh/sshd_config.new
    exit 1
fi

# Brief pause to show completion message
sleep 5
