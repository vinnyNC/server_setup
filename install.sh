#!/bin/bash
#
# Enterprise Provisioner - Bootstrapper
# Version: 1.1.0
#
# This script prepares a fresh Ubuntu/Debian server to use the provisioner.
# It installs dependencies, creates the required directory structure,
# downloads the main script and configuration, and launches the provisioner.
#
# Usage: sudo bash install.sh
# Requirements: Ubuntu/Debian system with internet connectivity
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

log_error() {
    echo "ERROR: $1" >&2
}

log_info() {
    echo "INFO: $1"
}

# Download a file with error handling and basic validation
download_file() {
    local url="$1"
    local destination="$2"
    local description="$3"
    
    log_step "Downloading $description..."
    
    if ! curl -sSLf --connect-timeout 30 --max-time 300 "$url" -o "$destination"; then
        log_error "Failed to download $description from $url"
        return 1
    fi
    
    # Basic validation - check if file exists and is not empty
    if [[ ! -f "$destination" ]] || [[ ! -s "$destination" ]]; then
        log_error "Downloaded file $destination is empty or doesn't exist"
        return 1
    fi
    
    log_info "Successfully downloaded $description to $destination"
    return 0
}

# Cleanup function for error scenarios
cleanup_on_error() {
    local exit_code=$?
    log_error "Installation failed with exit code $exit_code. Cleaning up..."
    
    # Remove potentially corrupted downloads
    [[ -f /usr/local/bin/provisioner ]] && rm -f /usr/local/bin/provisioner
    [[ -f /etc/provisioner/config.conf ]] && rm -f /etc/provisioner/config.conf
    
    log_info "Cleanup completed. Please fix the issues and try again."
    exit $exit_code
}

# Set up error trap
trap cleanup_on_error ERR

# --- Main Logic ---
main() {
    log_step "Starting Provisioner Bootstrap Process"

    # 1. Check for root privileges
    if [[ $EUID -ne 0 ]]; then
       log_error "This script must be run as root. Please use sudo."
       exit 1
    fi

    # 1.1. Check if we're on a supported system
    if [[ ! -f /etc/debian_version ]] && [[ ! -f /etc/ubuntu_version ]]; then
        log_error "This script is designed for Debian/Ubuntu systems only."
        exit 1
    fi

    # 1.2. Check for internet connectivity
    log_step "Checking internet connectivity..."
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected. Please check your network and try again."
        exit 1
    fi

    # 2. Install dependencies
    log_step "Updating package lists and installing dependencies (git, whiptail, curl)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y git whiptail curl

    # 3. Create required directory structure
    log_step "Creating necessary directories..."
    mkdir -p /etc/provisioner
    mkdir -p /var/lib/provisioner
    # The module repo dir will be created by the config, but we ensure its parent exists
    mkdir -p /opt

    # 4. Download the main provisioner script
    if ! download_file "${PROVISIONER_URL}" "/usr/local/bin/provisioner" "main provisioner script"; then
        log_error "Failed to download provisioner script. Please check your internet connection and try again."
        exit 1
    fi
    chmod +x /usr/local/bin/provisioner

    # 5. Download the configuration file
    if [[ ! -f /etc/provisioner/config.conf ]]; then
        if ! download_file "${CONFIG_URL}" "/etc/provisioner/config.conf" "default configuration file"; then
            log_error "Failed to download configuration file. Please check your internet connection and try again."
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
    if [[ -x /usr/local/bin/provisioner ]]; then
        log_info "Launching provisioner for the first time..."
        /usr/local/bin/provisioner
    else
        log_error "Provisioner script is not executable. Something went wrong during installation."
        exit 1
    fi
}

main "$@"
