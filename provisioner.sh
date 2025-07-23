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

# --- Dependency Checks ---
# Check for required commands
check_dependencies() {
    local missing_deps=()
    
    for cmd in git whiptail; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "ERROR: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install the missing packages and try again." >&2
        exit 1
    fi
}

# --- Directory Setup ---
# Ensure required directories exist with proper permissions
setup_directories() {
    local dirs=(
        "$(dirname "${CONFIG_FILE}")"
        "$(dirname "${STATE_FILE}")"
        "$(dirname "${LOG_FILE}")"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chmod 755 "$dir"
        fi
    done
}

# --- Logging ---
# A robust logging function.
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Ensure log file exists and is writable
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}"
        chmod 644 "${LOG_FILE}"
    fi
    
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
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    log "INFO" "Configuration loaded from ${CONFIG_FILE}."
}

# --- State Management ---
# Checks if a module has been successfully run.
check_state() {
    local module_id="$1"
    # Ensure the state file exists before trying to read it
    if [[ ! -f "${STATE_FILE}" ]]; then
        touch "${STATE_FILE}"
        chmod 644 "${STATE_FILE}"
    fi
    # The 'grep' command will exit with 1 if not found, which is the expected
    # behavior for use in an 'if' or '||' condition. Errexit is not triggered here.
    grep -q "^${module_id}$" "${STATE_FILE}" 2>/dev/null || return 1
}

# Updates the state file to mark a module as completed.
update_state() {
    local module_id="$1"
    # Ensure the state file exists
    if [[ ! -f "${STATE_FILE}" ]]; then
        touch "${STATE_FILE}"
        chmod 644 "${STATE_FILE}"
    fi
    # Add the module if it's not already there
    if ! check_state "${module_id}"; then
        echo "${module_id}" >> "${STATE_FILE}"
    fi
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
        # First, ensure we're in a clean state
        if git -C "${MODULE_REPO_DIR}" status --porcelain | grep -q .; then
            log "WARN" "Repository has local changes. Stashing them before pull."
            git -C "${MODULE_REPO_DIR}" stash push -m "Auto-stash before provisioner sync $(date)"
        fi
        
        # Reset to HEAD to ensure clean state
        git -C "${MODULE_REPO_DIR}" reset --hard HEAD
        
        # Pull the latest changes
        if git -C "${MODULE_REPO_DIR}" pull origin main; then
            log "INFO" "Repository updated successfully."
            whiptail --title "Sync Success" --msgbox "Repository updated successfully." 8 78
        else
            log "WARN" "Failed to pull updates from repository. Trying to fetch and reset."
            # Try a more aggressive approach
            if git -C "${MODULE_REPO_DIR}" fetch origin && git -C "${MODULE_REPO_DIR}" reset --hard origin/main; then
                log "INFO" "Repository forcibly updated successfully."
                whiptail --title "Sync Success" --msgbox "Repository updated successfully (forced update)." 8 78
            else
                log "ERROR" "Failed to sync repository even with force. Manual intervention may be required."
                whiptail --title "Sync Failed" --msgbox "Could not sync repository. Check logs and network connectivity." 8 78
            fi
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

    if [[ ! -d "${category_dir}" ]]; then
        whiptail --title "Directory Not Found" --msgbox "Module directory '${category_dir}' does not exist.\n\nMake sure the repository is synced properly." 10 78
        return
    fi

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
            found_desc=$(grep 'description:' "${meta_file}" | cut -d: -f2- | xargs 2>/dev/null || true)
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
            1) show_module_menu "${MODULE_REPO_DIR}/modules/install" "Package Installation Modules" ;;
            2) show_module_menu "${MODULE_REPO_DIR}/modules/setup" "Server Setup Modules" ;;
            3) show_module_menu "${MODULE_REPO_DIR}/modules/tools" "Common Tools Modules" ;;
            4) sync_repo ;;
            5) 
                if [[ -f "${LOG_FILE}" && -s "${LOG_FILE}" ]]; then
                    whiptail --title "Execution Log" --textbox "${LOG_FILE}" 20 78 --scrolltext
                else
                    whiptail --title "Execution Log" --msgbox "Log file is empty or does not exist." 8 78
                fi
                ;;
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
    # Check for required dependencies first
    check_dependencies

    # Ensure script is run as root
    if [[ $EUID -ne 0 ]]; then
       # A direct echo is more reliable for user feedback before exiting.
       echo "ERROR: This script must be run as root." >&2
       exit 1
    fi

    # Setup required directories
    setup_directories

    # Load configuration. The script will exit if this fails.
    load_config

    # --- Configuration Validation ---
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