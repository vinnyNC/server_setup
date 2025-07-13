#!/bin/bash
#
# Module: update-system
# Category: tools
#
# This module performs a full system update and upgrade,
# removes unused packages, and cleans the package cache.
#

# --- Strict Mode ---
set -euo pipefail

# --- Main Logic ---
echo "Starting full system update..."
apt-get update

echo "Upgrading installed packages..."
# Use non-interactive frontend to avoid prompts
export DEBIAN_FRONTEND=noninteractive
apt-get upgrade -y

echo "Removing unused packages..."
apt-get autoremove -y

echo "Cleaning up package cache..."
apt-get clean

echo "System update and cleanup complete."

# A short sleep to ensure the user sees the final message
sleep 2
