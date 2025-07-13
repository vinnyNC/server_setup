#!/bin/bash
#
# Enterprise Provisioner - Main Script
# Author: Your Name
# Version: 1.2.0
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
    # Ensure log file exists and is writable
    # This might fail if permissions are incorrect, but running as root should mitigate this.
    touch -a "${LOG_FILE}"
    echo -e "${timestamp} [${level}] - ${message}" | tee -a "${LOG_FILE}"
}

# --- Configuration Loading ---
# Loads configuration from the central config file.
load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log "ERROR" "Configuration file not found at ${CONFIG_FILE}!"
        # Use whiptail for user-facing error if available
        if command -v whiptail &> /dev/null; then
            whiptail --title "Configuration Error" --msgbox "Configuration file not found at ${CONFIG_FILE}.\n\nPlease create it and define GIT_REPO_URL and MODULE_REPO_DIR." 10 78
        fi
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
    # Ensure the state file exists before trying to read it
    touch -a "${STATE_FILE}"
    # The 'grep' command will exit with 1 if not found, which is the expected
    # behavior for use in an 'if' or '||' condition. Errexit is not triggered here.
    grep -q "^${module_id}$" "${STATE_FILE}"
}

# Updates the state file to mark a module as completed.
update_state() {
    local module_id="$1"
    # Ensure the state file exists
    touch -a "${STATE_FILE}"
    # Add the module if it's not already there
    check_state "${module_id}" || echo "${module_id}" >> "${STATE_FILE}"
}

# --- Core Logic ---
# Clones or updates the modules repository from Git.
sync_repo() {
    whiptail --title "Syncing Repository" --infobox "Contacting GitHub..." 8 78
    log "INFO" "Starting repository sync from ${GIT_REPO_URL}."

    # Ensure parent directory exists
    mkdir -p "$(dirname "${MODULE_REPO_DIR}")"

    if [[ ! -d "${MODULE_REPO_DIR}/.git" ]]; then
        log "INFO" "Cloning repository for the first time."
        if git clone "${GIT_REPO_URL}" "${MODULE_REPO_DIR}"; then
            log "INFO" "Repository cloned successfully."
            whiptail --title "Sync Success" --msgbox "Repository cloned successfully." 8 78
        else
            log "ERROR" "Failed to clone repository."
            whiptail --title "Sync Failed" --msgbox "Failed to clone repository. Check URL and permissions." 8 78
            exit 1
        fi
    else
        log "INFO" "Repository exists. Pulling latest changes."
        # Use -C to avoid changing the script's CWD (current working directory)
        if git -C "${MODULE_REPO_DIR}" pull; then
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

    # Execute the script and show a message box with the log tail on completion.
    if bash "${module_path}" >> "${LOG_FILE}" 2>&1; then
        update_state "${full_module_id}"
        log "INFO" "Module '${full_module_id}' completed successfully."
        whiptail --title "Execution Success" --msgbox "Module '${module_id}' ran successfully. View log for details." 8 78
    else
        log "ERROR" "Module '${full_module_id}' failed during execution."
        whiptail --title "Execution Failed" --msgbox "Module '${module_id}' failed. Please check the log file for details: ${LOG_FILE}" 10 78
    fi
}

# --- UI Menus ---
# Displays a dynamic menu for a given module category.
show_module_menu() {
    local category_dir="$1"
    local menu_title="$2"

    local whiptail_options=()
    # Safely find all modules using NUL delimiters
    local module_files
    mapfile -d '' module_files < <(find "${category_dir}" -maxdepth 1 -type f -name "*.sh" -print0 2>/dev/null | sort -z)

    if [[ ${#module_files[@]} -eq 0 ]]; then
        whiptail --title "No Modules Found" --msgbox "No modules were found in '${category_dir}'.\n\nMake sure the repository is synced and contains scripts in this category." 10 78
        return
    fi

    for module_path in "${module_files[@]}"; do
        # Ignore empty entries that can result from the mapfile command
        [[ -z "${module_path}" ]] && continue

        local module_id
        module_id=$(basename "${module_path}" .sh)
        local module_category
        module_category=$(basename "$(dirname "${module_path}")")
        local full_module_id="${module_category}/${module_id}"

        local status="[ ]" # Default: Not run
        if check_state "${full_module_id}"; then
            status="[X]" # Completed
        fi

        # The '|| true' is crucial to prevent the script from exiting if 'description:' is not found.
        local meta_file="${module_path%.sh}.meta"
        local description="No description available."
        if [[ -f "${meta_file}" ]]; then
            # The result is checked to ensure we only update the description if one was actually found.
            local found_desc
            found_desc=$(grep 'description:' "${meta_file}" | cut -d: -f2- | xargs || true)
            if [[ -n "${found_desc}" ]]; then
                description="${found_desc}"
            fi
        fi

        whiptail_options+=("${module_id}" "${status} ${description}")
    done

    local CHOICE
    CHOICE=$(whiptail --title "${menu_title}" --menu "Choose a module to run" 20 78 12 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)

    # $? is the exit status of whiptail. Non-zero means User pressed Cancel or Esc.
    if [[ $? -ne 0 ]]; then
        return
    fi

    run_module "${category_dir}/${CHOICE}.sh"
    # We return to the main menu after each action by design.
}

# The main menu of the application.
main_menu() {
    while true; do
        # The 3>&1 1>&2 2>&3 redirection correctly captures whiptail's output to STDOUT into a variable.
        local CHOICE
        CHOICE=$(whiptail --title "Enterprise Provisioner Main Menu" --menu "Choose an option" 16 78 6 \
            "1" "Install a Package" \
            "2" "Run a Server Setup" \
            "3" "Use Common Tools" \
            "4" "Sync Scripts from Git" \
            "5" "View Execution Log" \
            "6" "Exit" 3>&1 1>&2 2>&3)

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
       # A direct echo is more reliable for user feedback before exiting.
       echo "ERROR: This script must be run as root." >&2
       log "ERROR" "This script must be run as root."
       exit 1
    fi

    # Load configuration. The script will exit if this fails.
    load_config

    # --- ADDED: Configuration Validation ---
    # Check if the critical variables from the config file are actually set.
    # Using ':-""}' provides a default empty value to prevent 'nounset' error if var doesn't exist.
    if [[ -z "${GIT_REPO_URL:-""}" || -z "${MODULE_REPO_DIR:-""}" ]]; then
        log "ERROR" "GIT_REPO_URL or MODULE_REPO_DIR is not set in the configuration file."
        whiptail --title "Configuration Error" --msgbox "GIT_REPO_URL and/or MODULE_REPO_DIR are not defined in ${CONFIG_FILE}. Please define them before running." 10 78
        exit 1
    fi

    # On the very first run, automatically clone the repo before showing the menu.
    if [[ ! -d "${MODULE_REPO_DIR}/.git" ]]; then
        log "INFO" "First run detected. Automatically cloning modules repository..."
        sync_repo
    fi

    # Start the main menu
    main_menu
}

# Execute the main function, passing all script arguments to it.
main "$@"