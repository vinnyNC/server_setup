#!/bin/bash
#
# Module: firewall-basic
# Category: setup
#
# Configures a basic firewall with UFW (Uncomplicated Firewall).
#

# --- Strict Mode ---
set -euo pipefail

echo "Setting up basic firewall configuration..."

# Install UFW if not present
if ! command -v ufw >/dev/null 2>&1; then
    echo "Installing UFW..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y ufw
fi

echo "Configuring firewall rules..."

# Reset to defaults (just in case)
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (port 22) - CRITICAL: Don't lock yourself out!
ufw allow ssh

# Allow HTTP and HTTPS
ufw allow http
ufw allow https

# Enable the firewall
echo "Enabling firewall..."
ufw --force enable

# Show status
echo "Firewall configuration complete. Current status:"
ufw status verbose

echo ""
echo "Basic firewall setup complete!"
echo "Allowed ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
echo "All other incoming connections are blocked."

# Brief pause to show completion message
sleep 3
