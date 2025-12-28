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

# Enables flatpak remotes if not exist
function enable_flatpak() {
    prompt -db ""
    prompt -db "Trying to enable flatpak remotes if not exist..."
    prompt -db "User password will be prompted using GUI"
    sleep 1 

    if sudo_check; then
        runuser -u $SUDO_USER -- flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    else
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
}

# Enables RPMFusion repositories
function enable_RPMFusion() {
    prompt -db ""
    prompt -db "Enabling RPM Fusion default repositories..."
    prompt -db "This is include free and nonfree releases"

    if -f /etc/yum.repos.d/rpmfusion-free.repo || -f /etc/yum.repos.d/rpmfusion-nonfree.repo; then
        prompt -db "RPM Fusion repositories already enabled... skipping."
        return
    fi

    ensure_sudo
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf upgrade --refresh -y
    sudo dnf group upgrade -y core
}

# Set DNF max_parallel_downloads to 15
function optimize_dnf() {
    prompt -db ""
    prompt -db "Optimizing DNF speed..."
    prompt -db "This is include max_parallel_downloads and fastestmirror flags"

    if grep -q "max_parallel_downloads" /etc/dnf/dnf.conf; then
        prompt -db "Already optimized for max_parallel_downloads... skipping."
    else
        prompt -ib "Applying DNF optimization for max_parallel_downloads..."
        ensure_sudo

        # The echo command puts the text into the pipe, and tee (as root) writes it to the file.
        echo 'max_parallel_downloads=15' | sudo tee -a /etc/dnf/dnf.conf > /dev/null
        prompt -sb "DNF optimization for max_parallel_downloads applied!"
    fi

    if grep -q "fastestmirror" /etc/dnf/dnf.conf; then
        prompt -db "Already optimized for fastestmirror... skipping."    
    else
        prompt -ib "Applying DNF optimization for fastestmirror..."
        ensure_sudo

        # The echo command puts the text into the pipe, and tee (as root) writes it to the file.
        echo 'fastestmirror=True' | sudo tee -a /etc/dnf/dnf.conf > /dev/null
        prompt -sb "DNF optimization for fastestmirror applied!"
    fi
}

# Function to show nVidia installation warning
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
            1) prompt -i "Updating DNF..." ; pause ;;
            2) prompt -i "Updating Flatpak..." ; pause ;;
            3) prompt -i "Updating Firmware..." ; pause ;;
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