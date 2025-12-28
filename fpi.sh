#/bin/bash
#
# This script guides to fedora post installation
#
# @Author: Pedro Liberal
# @Date:   2020-03-20 14:28:23
# @Last Modified by:   phgl
# @Last Modified time: 2024-06-10 10:15:00
#


#####################################################
#   :::::: G L O B A L   V A R I A B L E S ::::::   #
#####################################################

# Exit immediately if a command fails
#set -o errexit

# Global constants
#ROOT_UID=0

# Global variables
dnf_select=()
flatpak_select=()

# Config files options
copr_options=()
ms_options=()

# User selected options
#copr_install_options=()
#microsoftKeys_install_options=()


#######################################
#   :::::: F U N C T I O N S ::::::   #
#######################################

# Function: prompt
# Description: Centralizes output logging with color coding using flags.
# Usage: prompt <flag> <message>
# Flags:
#   -d  : Default (White)        | -db : Default Bold
#   -i  : Info (Blue)            | -ib : Info Bold
#   -w  : Warning (Yellow)       | -wb : Warning Bold
#   -e  : Error (Red)            | -eb : Error Bold
#   -g  : Debug (Cyan)           | -gb : Debug Bold
#   -s  : Success (Green)        | -sb : Success Bold
function prompt() {
    local flag="$1"
    local message="$2"
    local C_RESET='\033[0m'

    case "$flag" in
        -d)  echo -e "\033[0;37m${message}${C_RESET}" ;;  # White
        -db) echo -e "\033[1;37m${message}${C_RESET}" ;;  # White Bold
        -i)  echo -e "\033[0;34m${message}${C_RESET}" ;;  # Blue
        -ib) echo -e "\033[1;34m${message}${C_RESET}" ;;  # Blue Bold
        -w)  echo -e "\033[0;33m${message}${C_RESET}" ;;  # Yellow
        -wb) echo -e "\033[1;33m${message}${C_RESET}" ;;  # Yellow Bold
        -e)  echo -e "\033[0;31m${message}${C_RESET}" ;;  # Red
        -eb) echo -e "\033[1;31m${message}${C_RESET}" ;;  # Red Bold
        -g)  echo -e "\033[0;36m${message}${C_RESET}" ;;  # Cyan (Debug)
        -gb) echo -e "\033[1;36m${message}${C_RESET}" ;;  # Cyan Bold
        -s)  echo -e "\033[0;32m${message}${C_RESET}" ;;  # Green (Success)
        -sb) echo -e "\033[1;32m${message}${C_RESET}" ;;  # Green Bold
        *)   echo -e "${message}" ;;                       # Fallback
    esac
}

# Function: pause
# Description: Pauses execution until user presses Enter.
function pause() {
    read -rp "Press [Enter] to continue..."
}

# Function: sudo_check
# Description: Silent check to verify if the sudo session is currently active.
# Returns: 0 if active, non-zero otherwise.
function sudo_check() {
    sudo -n true 2> /dev/null
}

# Function: ensure_sudo
# Description: Ensures sudo privileges are cached, prompting user if needed.
function ensure_sudo() {
    while ! sudo_check; do
        prompt -eb "Sudo credentials are required to proceed."
        
        # Ask the password to the users
        sudo -v
        
        if [ $? -ne 0 ]; then
             prompt -e "Authentication failed. Trying again (or CTRL+C to exit)..."
        fi
    done
    
    prompt -s "Sudo activated..."
}

# Function: check_command
# Description: Checks if a command exists; exits with error if not found.
function check_command() {
    local cmd="$1"
    echo "$cmd"

    if command -v "$cmd" &> /dev/null; then
        return  0
    fi
}

# Function: enable_flatpak
# Description: Enables flatpak remotes if not exist
function enable_flatpak() {
    prompt -db ""
    prompt -db "Trying to enable flatpak remotes if not exist..."

    if ! check_command "flatpak"; then
        prompt -wb "Flatpak is not installed. Installing via DNF..."
        
        ensure_sudo
        sudo dnf install -y flatpak
        
        prompt -bs "Flatpak installed successfully."
    fi

    if flatpak remotes | grep -q "flathub"; then
        prompt -sb "Flathub remote already enabled... skipping."
        return
    fi

    prompt -ib "Adding Flathub repository..."

    if sudo -n true 2>/dev/null; then
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    else
        prompt -i "Authentication required via GUI to add remote..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    
    prompt -sb "Flathub enabled!"
}

# Function: enable_RPMFusion
# Description: Enables RPMFusion repositories
function enable_RPMFusion() {
    prompt -db ""
    prompt -db "Enabling RPM Fusion free and nonfree repositories..."

    if [[ -f /etc/yum.repos.d/rpmfusion-free.repo || -f /etc/yum.repos.d/rpmfusion-nonfree.repo ]]; then
        prompt -db "RPM Fusion repositories already enabled... skipping."
        return
    fi

    ensure_sudo
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    prompt -ib "Refreshing repository metadata..."
    sudo dnf makecache
    prompt -sb "RPM Fusion repositories enabled!"
}

# Function: optimize_dnf
# Description: Optimize DNF speed by setting max_parallel_downloads and fastestmirror
function optimize_dnf() {
    prompt -db ""
    prompt -db "Enabling 'max_parallel_downloads' and 'fastestmirror' flags"

    local dnf_conf="/etc/dnf/dnf.conf"
    local config_to_add=""
    local needs_optimization=false

    if grep -q "max_parallel_downloads" "$dnf_conf"; then
        prompt -db " - max_parallel_downloads: OK"
    else
        prompt -ib " - max_parallel_downloads: Queued for update (15)"
        config_to_add+="max_parallel_downloads=15\n"
        needs_optimization=true
    fi

    if grep -q "fastestmirror" "$dnf_conf"; then
        prompt -db " - fastestmirror: OK"
    else
        prompt -ib " - fastestmirror: Queued for update (True)"
        config_to_add+="fastestmirror=True"
        needs_optimization=true
    fi

    if [ "$needs_optimization" = true ]; then
        ensure_sudo

        # The '-e' allows echo to interpret \n as a newline
        echo -e "$config_to_add" | sudo tee -a "$dnf_conf" > /dev/null        
        prompt -sb "DNF configuration updated successfully!"
    else
        prompt -sb "DNF is already fully optimized."
    fi
}

# Function: update_dnf
# Description: Update system packages using DNF
function update_dnf() {
    prompt -db ""
    prompt -db "This will upgrade all system packages and refresh repositories."

    ensure_sudo

    if sudo dnf upgrade --refresh -y; then
        prompt -sb "System packages updated successfully!"
    else
        prompt -eb "DNF update encountered errors."
    fi
}

# Function: update_flatpak
# Description: Update Flatpak applications
function update_flatpak() {
    prompt -db ""
    prompt -db "This will update all Flatpak applications."

    if ! check_command "flatpak"; then
        prompt -wb "Flatpak is not installed. Skipping..."
        return
    fi

    if flatpak update -y; then
        prompt -sb "Flatpak applications updated successfully!"
    else
        prompt -eb "Flatpak update encountered errors."
    fi
}

# Function: update_firmware
# Description: Update system firmware using fwupd
function update_firmware() {
    prompt -db ""
    prompt -db "Checking for supported hardware and available updates..."

    if ! check_command "fwupdmgr"; then
        prompt -wb "fwupd (fwupdmgr) is not installed. Skipping..."
        return
    fi

    ensure_sudo

    prompt -i "Refreshing firmware metadata..."
    sudo fwupdmgr refresh --force

    prompt -i "Checking for updates..."
    if sudo fwupdmgr update; then
        prompt -sb "Firmware operations completed."
    else
        # fwupdmgr can return error if no updates are available, which is normal,
        # but here we capture real failures too.
        prompt -wb "No firmware updates applied or an error occurred."
    fi
}

# Function: nvidia_warning
# Description: Show nVidia installation warning and instructions
function nvidia_warning() {
    echo ""
    echo ">>> IMPORTANT <<<"
    echo ""
    echo "Installing nVidia drivers requires some manual procedures."
    echo ""
    echo "First, select option number '1' from the menu below. Some packages will be installed"
    echo "and then the kernel key generation procedure for secure boot will start."
    echo ""
    echo ">> A password must be created when prompted. <<"
    echo ""
    echo "The password does not need to be complex and should be easy to memorize as it will"
    echo "be requested the next time the system is started."
    echo ""
    echo "After this, the script will ask if it should restart the system automatically (recommended)"
    echo "or if you want to restart later."
    echo ""
    echo ">> It is important to remember this password cause the procedure can only be completed after"
    echo "restarting the system and enrolling the kernel key in secure boot. <<"
    echo ""
    echo "When the system restarts, the secure boot key enrollment system will be displayed"
    echo "on the screen. This procedure is part of the BIOS and must be performed for the drivers"
    echo "to be successfully installed."
    echo ""
    echo ">> This screen will ask for the key that was created in the step before restarting the system. <<"
    echo ""
    echo "The steps are described below:"
    echo ""
    echo "1. Select “Enroll MOK“."
    echo "2. Click on “Continue“."
    echo "3. Select “Yes” and enter the password generated in the previous step"
    echo "4. Select \"OK\" and your computer will restart again"
    echo ""
    echo "After the system restart, restart the script and select the option referring to the nVidia driver"
    echo "in the main menu and, later, select option 2 of the specific menu for the nVidia drivers."
    echo ""
}

# Function: nvidia_reboot
# Description: Show nVidia reboot instructions
function nvidia_reboot() {
    echo ""
    echo ">>> IMPORTANT <<<"
    echo ""
    echo "When the system restarts, the secure boot key enrollment system will be displayed"
    echo "on the screen. This procedure is part of the BIOS and must be performed for the drivers"
    echo "to be successfully installed."
    echo ""
    echo ">> This screen will ask for the key that was created in the step before restarting the system. <<"
    echo ""
    echo "The steps are described below:"
    echo ""
    echo "1. Select “Enroll MOK“."
    echo "2. Click on “Continue“."
    echo "3. Select “Yes” and enter the password generated in the previous step"
    echo "4. Select \"OK\" and your computer will restart again"
    echo ""
    echo "After the system restart, restart the script and select the option referring to the nVidia driver"
    echo "in the main menu and, later, select option 2 of the specific menu for the nVidia drivers."
    echo ""
}


###############################
#   :::::: M E N U S ::::::   #
###############################

# Function: menu_header
# Description: Header to be used with menus
function menu_header() {
    clear
    prompt -bs "+======================================+"
    prompt -bs "        Fedora Post Installation        "
    prompt -bs "            by Pedro Liberal            "
    prompt -bs "                  v1.0                  "
    prompt -bs "+======================================+"
    prompt -bs ""
}

# Function: menu_sys_config
# Description: Submenu for System Configuration
function menu_sys_config() {
    while true; do
        clear
        menu_header
        prompt -ib "=== System Setup > Configuration ==="
        echo "1. Enable Flathub"
        echo "2. Enable RPMFusion"
        echo "3. Optimise DNF speed"
        echo "0. Back"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) prompt -i "Enabling Flathub..." ; enable_flatpak ; pause ;;
            2) prompt -i "Enabling RPMFusion..." ; enable_RPMFusion ; pause ;;
            3) prompt -i "Optimising DNF speed..." ; optimize_dnf ; pause ;;
            0) break ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Function: menu_sys_update
# Description: Submenu for System Update
function menu_sys_update() {
    while true; do
        clear
        menu_header
        prompt -ib "=== System Setup > System Update ==="
        echo "1. Update DNF"
        echo "2. Update Flatpak"
        echo "3. Update Firmware"
        echo "0. Back"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) prompt -i "Starting System Update (DNF)..." ; update_dnf ; pause ;;
            2) prompt -i "Starting Flatpak Update..." ; update_flatpak ; pause ;;
            3) prompt -i "Starting Firmware Update (fwupd)..." ; update_firmware ; pause ;;
            0) break ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Function: menu_system_setup
# Description: Menu for System Setup
function menu_system_setup() {
    while true; do
        clear
        menu_header
        prompt -ib "=== System Setup ==="
        echo "1. Configuration"
        echo "2. System Update"
        echo "0. Back"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) menu_sys_config ;;
            2) menu_sys_update ;;
            0) break ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Function: menu_software_setup
# Description: Menu for Software Setup
function menu_software_setup() {
    while true; do
        clear
        menu_header
        prompt -ib "=== Software Setup ==="
        echo "1. Install Oh-My-ZSH"
        echo "2. Install DNF softwares"
        echo "3. Install Flatpak softwares"
        echo "4. Install Microsoft softwares"
        echo "5. Install extras (fonts & codecs)"
        echo "0. Back"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) prompt -i "Installing Oh-My-ZSH..." ; pause ;;
            2) prompt -i "Installing DNF softwares..." ; pause ;;
            3) prompt -i "Installing Flatpak softwares..." ; pause ;;
            4) prompt -i "Installing Microsoft softwares..." ; pause ;;
            5) prompt -i "Installing extras..." ; pause ;;
            0) break ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Function: menu_hardware_setup
# Description: Menu for Hardware Setup
function menu_hardware_setup() {
    while true; do
        clear
        menu_header
        prompt -ib "=== Hardware Setup ==="
        echo "1. Install VA-API driver for Intel GPUs"
        echo "2. Install VA-API and VDPAU drivers for AMD GPUs"
        echo "3. Install NVIDIA proprietary driver (signed)"
        echo "0. Back"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) prompt -i "Installing Intel drivers..." ; pause ;;
            2) prompt -i "Installing AMD drivers..." ; pause ;;
            3) prompt -i "Installing NVIDIA drivers..." ; pause ;;
            0) break ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Function: menu_tweaks
# Description: Menu for Tweaks
function menu_tweaks() {
    while true; do
        clear
        menu_header
        prompt -ib "=== Tweaks ==="
        echo "1. Set hostname"
        echo "0. Back"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) prompt -i "Setting hostname..." ; pause ;;
            0) break ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}

# Function: main_menu
# Description: Main application menu
function main_menu() {
    while true; do
        clear
        menu_header
        prompt -ib "=== Fedora Post Install Script ==="
        echo "1. System setup"
        echo "2. Software setup"
        echo "3. Hardware setup"
        echo "4. Tweaks"
        echo "0. Exit"
        echo ""
        read -p "Select an option: " choice

        case $choice in
            1) menu_system_setup ;;
            2) menu_software_setup ;;
            3) menu_hardware_setup ;;
            4) menu_tweaks ;;
            0) prompt -s "Exiting..." ; exit 0 ;;
            *) prompt -e "Invalid option." ; pause ;;
        esac
    done
}



# Main script execution
#sudo

main_menu