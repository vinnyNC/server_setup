#!/bin/bash
#
# Enterprise Provisioner - Main Script
# Author: Your Name
# Version: 1.0.0
#
# This script provides a menu-driven interface to provision and manage servers.
# It is designed to be idempotent, stateful, and easily extensible.
#

# --- Strict Mode & Error Handling ---
set -o errexit
set -o pipefail
set -o nounset

# --- Global Variables & Constants ---
readonly CONFIG_FILE="/etc/provisioner/config.conf"
readonly STATE_FILE="/var/lib/provisioner/state"
readonly LOG_FILE="/var/log/provisioner.log"
readonly SCRIPT_NAME=$(basename "$0")

# --- Color & Style Codes ---
# These are not used for whiptail, but for logging and console output.
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_NC='\033[0m' # No Color

# --- Logging ---
# A robust logging function.
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [${level}] - ${message}" | tee -a "${LOG_FILE}"
}

# --- Configuration Loading ---
# Loads configuration from the central config file.
load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log "ERROR" "Configuration file not found at ${CONFIG_FILE}!"
        exit 1
    fi
    # Source the config file to load variables
    # shellcheck source=/etc/provisioner/config.conf
    source "${CONFIG_FILE}"
    log "INFO" "Configuration loaded from ${CONFIG_FILE}."
}

# --- State Management ---
# Checks if a module has been successfully run.
check_state() {
    local module_id="$1"
    grep -q "^${module_id}$" "${STATE_FILE}"
}

# Updates the state file to mark a module as completed.
update_state() {
    local module_id="$1"
    # Ensure the state file exists
    touch "${STATE_FILE}"
    # Add the module if it's not already there
    check_state "${module_id}" || echo "${module_id}" >> "${STATE_FILE}"
}

# --- Core Logic ---
# Clones or updates the modules repository from Git.
sync_repo() {
    whiptail --title "Syncing Repository" --infobox "Contacting GitHub..." 8 78
    log "INFO" "Starting repository sync from ${GIT_REPO_URL}."

    if [[ ! -d "${MODULE_REPO_DIR}/.git" ]]; then
        log "INFO" "Cloning repository for the first time."
        if git clone "${GIT_REPO_URL}" "${MODULE_REPO_DIR}"; then
            log "INFO" "Repository cloned successfully."
            whiptail --title "Sync Success" --msgbox "Repository cloned successfully." 8 78
        else
            log "ERROR" "Failed to clone repository."
            whiptail --title "Sync Failed" --msgbox "Failed to clone repository. Check logs." 8 78
            exit 1
        fi
    else
        log "INFO" "Repository exists. Pulling latest changes."
        cd "${MODULE_REPO_DIR}"
        if git pull; then
            log "INFO" "Repository updated successfully."
            whiptail --title "Sync Success" --msgbox "Repository updated successfully." 8 78
        else
            log "WARN" "Failed to pull updates from repository. It might be offline or you have local changes."
            whiptail --title "Sync Warning" --msgbox "Could not pull updates. Check logs for details." 8 78
        fi
    fi
    # Ensure all module scripts are executable
    find "${MODULE_REPO_DIR}" -type f -name "*.sh" -exec chmod +x {} \;
}

# Executes a selected module script.
run_module() {
    local module_path="$1"
    local module_id
    module_id=$(basename "${module_path}" .sh)
    local module_category
    module_category=$(basename "$(dirname "${module_path}")")
    local full_module_id="${module_category}/${module_id}"

    # Check state and ask if user wants to re-run
    if check_state "${full_module_id}"; then
        if ! whiptail --title "Module Already Run" --yesno "'${full_module_id}' has already been run successfully. Do you want to run it again?" 8 78; then
            log "INFO" "Skipping already completed module: ${full_module_id}"
            return
        fi
    fi

    log "INFO" "Executing module: ${full_module_id}"
    
    # Show a progress gauge during execution
    {
        # Execute the script, redirecting its output for the gauge
        if bash "${module_path}"; then
            # On success, update the state
            update_state "${full_module_id}"
            log "INFO" "Module '${full_module_id}' completed successfully."
            whiptail --title "Execution Success" --msgbox "Module '${module_id}' ran successfully." 8 78
        else
            log "ERROR" "Module '${full_module_id}' failed during execution. Check logs for details."
            whiptail --title "Execution Failed" --msgbox "Module '${module_id}' failed. Please check the log file: ${LOG_FILE}" 10 78
        fi
    } | whiptail --title "Running Module" --gauge "Executing '${module_id}'... Please wait." 8 78 0
}

# --- UI Menus ---
# Displays a dynamic menu for a given module category.
show_module_menu() {
    local category_dir="$1"
    local menu_title="$2"
    
    local whiptail_options=()
    local module_files
    mapfile -d '' module_files < <(find "${category_dir}" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)

    if [[ ${#module_files[@]} -eq 0 ]]; then
        whiptail --title "No Modules Found" --msgbox "No modules were found in this category." 8 78
        return
    fi
    
    for module_path in "${module_files[@]}"; do
        local module_id
        module_id=$(basename "${module_path}" .sh)
        local module_category
        module_category=$(basename "$(dirname "${module_path}")")
        local full_module_id="${module_category}/${module_id}"
        
        local status="[ ]" # Default: Not run
        if check_state "${full_module_id}"; then
            status="[X]" # Completed
        fi
        
        # Try to read description from a .meta file
        local meta_file="${module_path%.sh}.meta"
        local description="No description available."
        if [[ -f "${meta_file}" ]]; then
            description=$(grep 'description:' "${meta_file}" | cut -d: -f2- | xargs)
        fi

        whiptail_options+=("${module_id}" "${status} ${description}")
    done

    if [[ ${#whiptail_options[@]} -eq 0 ]]; then
        whiptail --title "Error" --msgbox "Could not build menu options." 8 78
        return
    fi

    # Loop for the sub-menu
    while true; do
        CHOICE=$(whiptail --title "${menu_title}" --menu "Choose a module to run" 20 78 12 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
        
        if [[ $? -ne 0 ]]; then # User pressed Cancel or Esc
            return
        fi

        run_module "${category_dir}/${CHOICE}.sh"
        # After running, we return to the main menu. To stay in the sub-menu, remove the 'return'
        # and instead re-generate the whiptail_options array to reflect the new state.
        return 
    done
}

# The main menu of the application.
main_menu() {
    while true; do
        CHOICE=$(whiptail --title "Enterprise Provisioner Main Menu" --menu "Choose an option" 16 78 6 \
            "1" "Install a Package" \
            "2" "Run a Server Setup" \
            "3" "Use Common Tools" \
            "4" "Sync Scripts from Git" \
            "5" "View Execution Log" \
            "6" "Exit" 3>&1 1>&2 2>&3)

        # Check exit status
        if [[ $? -ne 0 ]]; then
            CHOICE=6 # Exit on Cancel
        fi

        case "$CHOICE" in
            1) show_module_menu "${MODULE_REPO_DIR}/install" "Package Installation Modules" ;;
            2) show_module_menu "${MODULE_REPO_DIR}/setup" "Server Setup Modules" ;;
            3) show_module_menu "${MODULE_REPO_DIR}/tools" "Common Tools Modules" ;;
            4) sync_repo ;;
            5) whiptail --title "Execution Log" --textbox "${LOG_FILE}" 20 78 --scrolltext ;;
            6)
                log "INFO" "User exited the provisioner."
                echo -e "${C_BLUE}Goodbye!${C_NC}"
                exit 0
                ;;
        esac
    done
}

# --- Script Entry Point ---
main() {
    # Ensure script is run as root
    if [[ $EUID -ne 0 ]]; then
       log "ERROR" "This script must be run as root."
       exit 1
    fi

    # Load configuration
    load_config

    # Start the main menu
    main_menu
}

# Execute the main function
main "$@"
