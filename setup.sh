#!/bin/bash

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Configuration ---
# Your actual GitHub repository URL
GITHUB_REPO="https://github.com/vinnyNC/server_setup.git"
# The local directory where the repository will be cloned
SCRIPT_DIR="/opt/ubuntu-setup-scripts"

# --- Helper Functions ---

# Function to print a centered header
print_header() {
    local title="$1"
    local term_width=$(tput cols)
    local title_len=${#title}
    local padding=$(((term_width - title_len) / 2))
    printf "\n%${padding}s" ""
    printf "${BLUE}==================== ${title} ====================${NC}\n"
}

# Function to display a message and wait for user to press Enter
press_enter_to_continue() {
    echo -e "\n${YELLOW}Press [Enter] to continue...${NC}"
    read -r
}

# Function to handle script execution and logging
run_script() {
    local script_path="$1"
    local log_file="/var/log/setup-script.log"
    echo "Executing $script_path at $(date)" >> "$log_file"
    if [ -f "$script_path" ]; then
        if bash "$script_path"; then
            echo -e "${GREEN}Script '$script_path' executed successfully.${NC}"
        else
            echo -e "${RED}Error executing script '$script_path'. Check log for details.${NC}"
        fi
    else
        echo -e "${RED}Error: Script '$script_path' not found.${NC}"
    fi
    press_enter_to_continue
}

# --- Menu Functions ---

# Function to display and handle a dynamic menu
show_dynamic_menu() {
    local menu_title="$1"
    local script_folder="$2"

    # Loop for the sub-menu
    while true; do
        clear
        print_header "$menu_title"
        
        local options=()
        # Read script files from the specified folder
        while IFS= read -r -d $'\0' file; do
            options+=("$(basename "$file" .sh)")
        done < <(find "$script_folder" -maxdepth 1 -type f -name "*.sh" -print0 2>/dev/null | sort -z)

        if [ ${#options[@]} -eq 0 ]; then
            echo -e "${YELLOW}No scripts found in '$script_folder'.${NC}"
            press_enter_to_continue
            return
        fi

        options+=("Go Back")

        select opt in "${options[@]}"; do
            if [[ "$opt" == "Go Back" ]]; then
                return # Exit the function to go back to the main menu
            elif [[ -n "$opt" ]]; then
                local script_path="$script_folder/$opt.sh"
                run_script "$script_path"
                break # Break from select to redisplay this sub-menu
            else
                echo -e "${RED}Invalid option. Please try again.${NC}"
                press_enter_to_continue
                break # Break from select to redisplay this sub-menu
            fi
        done
    done
}

# --- Main Logic ---

# Function to clone or update the script repository
sync_repo() {
    print_header "Syncing Scripts from GitHub"
    if [ ! -d "$SCRIPT_DIR" ]; then
        echo -e "${YELLOW}Cloning repository...${NC}"
        if git clone "$GITHUB_REPO" "$SCRIPT_DIR"; then
            echo -e "${GREEN}Repository cloned successfully.${NC}"
        else
            echo -e "${RED}Failed to clone repository. Please check the URL and permissions.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Updating repository...${NC}"
        cd "$SCRIPT_DIR" || exit
        if git pull; then
            echo -e "${GREEN}Repository updated successfully.${NC}"
        else
            echo -e "${RED}Failed to update repository.${NC}"
        fi
    fi
    # Set correct permissions for all scripts in the subdirectories
    if [ -d "$SCRIPT_DIR/scripts" ]; then
        sudo chmod +x "$SCRIPT_DIR"/scripts/**/*.sh 2>/dev/null
    fi
    press_enter_to_continue
}

# Main menu function
main_menu() {
    while true; do
        clear
        print_header "Ubuntu Server Main Setup Menu"
        echo "Please choose a category:"
        options=("Install Package" "Server Setup Scripts" "Common Tools" "Update Scripts from Git" "Exit")
        
        select opt in "${options[@]}"; do
            case $opt in
                "Install Package")
                    show_dynamic_menu "Install a Package" "$SCRIPT_DIR/scripts/install"
                    ;;
                "Server Setup Scripts")
                    show_dynamic_menu "Server Setup Scripts" "$SCRIPT_DIR/scripts/setup"
                    ;;
                "Common Tools")
                    show_dynamic_menu "Common Maintenance Tools" "$SCRIPT_DIR/scripts/tools"
                    ;;
                "Update Scripts from Git")
                    sync_repo
                    ;;
                "Exit")
                    echo -e "${BLUE}Exiting script. Goodbye!${NC}"
                    exit 0
                    ;;
                *) 
                    echo -e "${RED}Invalid option. Please try again.${NC}"
                    press_enter_to_continue
                    ;;
            esac
            # Break after a selection to redisplay the main menu
            break
        done
    done
}

# --- Script Entry Point ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

# Initial sync of the repository
sync_repo

# Start the main menu
main_menu
