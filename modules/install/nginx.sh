#!/bin/bash
#
# Module: nginx
# Category: install
#
# Installs and configures NGINX web server.
#

# --- Strict Mode ---
set -euo pipefail

echo "Installing NGINX web server..."

# Check if NGINX is already installed
if command -v nginx >/dev/null 2>&1; then
    echo "NGINX is already installed. Version: $(nginx -v 2>&1 | cut -d' ' -f3)"
    echo "Checking if service is running..."
    if systemctl is-active --quiet nginx; then
        echo "NGINX service is already running."
    else
        echo "Starting NGINX service..."
        systemctl start nginx
        systemctl enable nginx
    fi
else
    echo "Installing NGINX..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y nginx
    
    echo "Starting and enabling NGINX service..."
    systemctl start nginx
    systemctl enable nginx
fi

echo "NGINX installation and configuration complete."
echo "NGINX is accessible at: http://$(hostname -I | awk '{print $1}')"

# Brief pause to show completion message
sleep 2
