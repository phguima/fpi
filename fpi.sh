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

# Global color scheme variables
CDEF="\033[0m"                                 	        	# default color
CCIN="\033[0;36m"                              		        # info color
CGSC="\033[0;32m"                              		        # success color
CRER="\033[0;31m"                              		        # error color
CWAR="\033[0;33m"                              		        # waring color
b_CDEF="\033[1;37m"                            		        # bold default color
b_CCIN="\033[1;36m"                            		        # bold info color
b_CGSC="\033[1;32m"                            		        # bold success color
b_CRER="\033[1;31m"                            		        # bold error color
b_CWAR="\033[1;33m"                            		        # bold warning color

# Exit immediately if a command fails
set -o errexit

# Global constants
ROOT_UID=0

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

# Set prompt function for colored messages
function prompt () {
	case ${1} in
        "-d"|"--default")
			echo -e "${CDEF}${@/-d/}${CDEF}";;          # print default message
        "-bd"|"--default-bold")
			echo -e "${b_CDEF}${@/-bd/}${CDEF}";;       # print bold default message
		"-s"|"--success")
			echo -e "${CGSC}${@/-s/}${CDEF}";;          # print success message
        "-bs"|"--success-bold")
			echo -e "${b_CGSC}${@/-bs/}${CDEF}";;       # print bold success message
		"-e"|"--error")
			echo -e "${CRER}${@/-e/}${CDEF}";;          # print error message
        "-be"|"--error-bold")
			echo -e "${b_CRER}${@/-be/}${CDEF}";;       # print bold error message
		"-w"|"--warning")
			echo -e "${CWAR}${@/-w/}${CDEF}";;          # print warning message
        "-bw"|"--warning-bold")
			echo -e "${b_CWAR}${@/-bw/}${CDEF}";;       # print bold warning message
		"-i"|"--info")
			echo -e "${CCIN}${@/-i/}${CDEF}";;          # print info message
        "-bi"|"--info-bold")
			echo -e "${b_CCIN}${@/-bi/}${CDEF}";;       # print boldinfo message
		*)
			echo -e "$@"
		;;
	 esac
}

: '
# Check if the script is run as root
function sudo() {
    if [ "$UID" -ne "$ROOT_UID" ]; then
        prompt -be "This script must be run as root. Please run 'sudo ./fpi.sh'"
        exit 1
    fi
}
'

# Active sudo silent check
function sudo_check() {
    # The last command return status is the function return
    sudo -n true 2> /dev/null
}

# Check and refresh sudo cache
function ensure_sudo() {
    # Checks if the sudo timestamp is valid without prompting for a password
    while ! sudo_check; do
        prompt -be "Sudo credentials are required to proceed."
        
        # Ask the password to the users (3 attempts)
        sudo -v
        
        # Check for a success sudo -v
        # Loop while $? is not igual to 0
        if [ $? -ne 0 ]; then
             echo "Authentication failed. Trying again (or CRTL+C to exit script)..."
        fi
    done
    
    echo "Sudo activated..."
}

: '
# Function to display usage information
function usage() {
    echo "Usage: $0 [OPTION]..."
    echo "            "
    echo "OPTIONS (assumes '-a' if no parameters is informed):"
    echo "  -a, --all          run all update system (dnf, flatpak and fwupdmgr) [Default]"
    echo "  -d, --dnf          run 'dnf upgrade --refresh'"
    echo "  -f, --flatpak      run 'flatpak update'"
    echo "  -x, --firmware     run firmware update commands (fwupdmgr)"
    echo "  -h, --help         Show this help"
    echo ""
}
'

: '
Estrutura do menu

|- System setup
|--- Configuration
        |------ Enable flathub
|------ Enable RPMFusion
|------ Optimise DNF speed
|--- System update
|------ DNF
|------ Flatpak
|------ Firmware
|- Software setup
|--- Install Oh-My-ZSH
|--- Install DNF softwares
|--- Install flatpak softwares
|--- Install microsoft softwares
|--- Install extras (fonts & codecs)
|- Hardware setup
|--- Install VA-API driver for Intel GPUs
|--- Install VA-API and VDPAU drivers for AMD GPUs
|--- Install NVIDIA proprietary driver (signed)
|- Tweaks
|--- Set hostname
'

# Header to be used with all menus
function menu_header() {
    clear
    prompt -bs "+======================================+"
    prompt -bs "        Fedora Post Installation        "
    prompt -bs "            by Pedro Liberal            "
    prompt -bs "                  v1.0                  "
    prompt -bs "+======================================+"
    prompt -bs ""
}

# fpi main menu
function menu_main() {
    menu_header
    prompt -bw "Main Menu"
    prompt -d " 1. System setup"
    prompt -d " 2. Software setup"
    prompt -d " 3. Hardware setup"
    prompt -d " 4. Tweaks"
    prompt -d " -"
    prompt -d " 0. Quit"
    prompt -d ""
}

# System menu
function menu_system() {
    menu_header
    prompt -bw "System Menu"
    prompt -bi "- Configuration"
    prompt -d "  1. Enable flathub"
    prompt -d "  2. Enable RPMFusion"
    prompt -d "  3. Optimise DNF speed"
    prompt -bi "- Updates"
    prompt -d "  4. DNF"
    prompt -d "  5. Flatpak"
    prompt -d "  6. Firmware"
    prompt -d "  -"
    prompt -d "  0. Quit"
    prompt -d ""
}

# Enables flatpak remotes if not exist
function enable_flatpak() {
    prompt -bd ""
    prompt -bd "Trying to enable flatpak remotes if not exist..."
    prompt -bd "User password will be prompted using GUI"
    sleep 1 

    if sudo_check; then
        runuser -u $SUDO_USER -- flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    else
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
}

#
function enable_RPMFusion() {
    prompt -bd ""
    prompt -bd "Enabling RPM Fusion default repositories..."
    prompt -bd "This is include free and nonfree releases"

    ensure_sudo
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf upgrade --refresh -y
    sudo dnf group upgrade -y core
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

# Main script execution
#sudo

while true; do
    menu_main
    read -p " Option: " option

    case ${option} in
        1)
            while true; do
                menu_system
                read -p " Option: " option

                case ${option} in
                    1)
                        enable_flatpak
                        ;;
                    2)
                        enable_RPMFusion
                        ;;
                    3)
                        ;;
                    4)
                        ;;
                    5)
                        ;;
                    6)
                        ;;
                    0)
                        ;;
                    *)
                        ;;
                esac
            done
            ;;
        0)
            prompt -bs ">>>   Thanks for use Fedora Post Installation Script   <<<"
            exit 0
            ;;
        *)
            exit 1
            ;;
    esac
done



