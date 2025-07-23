#!/bin/bash
#
# Module: essential-tools
# Category: tools
#
# Installs a collection of essential command-line tools.
#

# --- Strict Mode ---
set -euo pipefail

echo "Installing essential command-line tools..."

# List of essential tools to install
tools=(
    "curl"          # HTTP client
    "wget"          # Download tool
    "vim"           # Text editor
    "nano"          # Simple text editor
    "git"           # Version control
    "unzip"         # Archive extraction
    "zip"           # Archive creation
    "tree"          # Directory tree viewer
    "net-tools"     # Network tools (netstat, etc.)
    "lsof"          # List open files
    "jq"            # JSON processor
    "screen"        # Terminal multiplexer
    "tmux"          # Modern terminal multiplexer
)

echo "Updating package database..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

echo "Installing tools: ${tools[*]}"
apt-get install -y "${tools[@]}"

echo ""
echo "Essential tools installation complete!"
echo "Installed tools:"
for tool in "${tools[@]}"; do
    echo "  - $tool"
done

echo ""
echo "All tools are now available in your PATH."

# Brief pause to show completion message
sleep 3
