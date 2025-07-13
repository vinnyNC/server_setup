#!/bin/bash
#
# Enterprise Provisioner - Bootstrapper
#
# This script prepares a fresh Ubuntu server to use the provisioner.
# It installs dependencies, creates the required directory structure,
# downloads the main script and configuration, and launches the provisioner.
#

# --- Strict Mode ---
set -euo pipefail

# --- Configuration ---
# The raw URL to your main provisioner script on GitHub.
readonly PROVISIONER_URL="https://raw.githubusercontent.com/vinnyNC/server_setup/main/provisioner.sh"
# The raw URL to your default configuration file on GitHub.
readonly CONFIG_URL="https://raw.githubusercontent.com/vinnyNC/server_setup/main/config.conf"

# --- Functions ---
log_step() {
    echo "--- $1 ---"
}

# --- Main Logic ---
main() {
    log_step "Starting Provisioner Bootstrap Process"

    # 1. Check for root privileges
    if [[ $EUID -ne 0 ]]; then
       echo "This script must be run as root. Please use sudo."
       exit 1
    fi

    # 2. Install dependencies
    log_step "Updating package lists and installing dependencies (git, whiptail)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y git whiptail

    # 3. Create required directory structure
    log_step "Creating necessary directories..."
    mkdir -p /etc/provisioner
    mkdir -p /var/lib/provisioner
    # The module repo dir will be created by the config, but we ensure its parent exists
    mkdir -p /opt

    # 4. Download the main provisioner script
    log_step "Downloading main provisioner script..."
    if ! curl -sSLf "${PROVISIONER_URL}" -o /usr/local/bin/provisioner; then
        echo "ERROR: Failed to download provisioner script from ${PROVISIONER_URL}"
        exit 1
    fi
    chmod +x /usr/local/bin/provisioner

    # 5. Download the configuration file
    log_step "Downloading default configuration file..."
    if [[ ! -f /etc/provisioner/config.conf ]]; then
        if ! curl -sSLf "${CONFIG_URL}" -o /etc/provisioner/config.conf; then
            echo "ERROR: Failed to download configuration from ${CONFIG_URL}"
            exit 1
        fi
    else
        log_step "Configuration file already exists. Skipping download."
    fi

    log_step "Bootstrap complete!"
    echo
    echo "You can now run the main script by typing: provisioner"
    echo "Launching for the first time..."
    echo

    # 6. Execute the main provisioner script
    # The script will handle the initial repo sync itself.
    /usr/local/bin/provisioner
}

main "$@"
