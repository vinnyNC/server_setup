#!/bin/bash
#
# Module: htop
# Category: tools
#
# Installs htop - an interactive process viewer.
#

# --- Strict Mode ---
set -euo pipefail

echo "Installing htop..."

# Check if htop is already installed
if command -v htop >/dev/null 2>&1; then
    echo "htop is already installed."
else
    echo "Installing htop package..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y htop
    echo "htop installed successfully!"
fi

echo "htop is now available. You can run it by typing 'htop' in the terminal."

# Brief pause to show completion message
sleep 2
