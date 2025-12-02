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

# Variables
ROOT_UID=0
DNF_SELECT=()
FLATPAK_SELECT=()

# Config files options
copr_file_options=()
microsoftKeys_file_options=()

# User selected options
copr_install_options=()
microsoftKeys_install_options=()


#######################################
#   :::::: F U N C T I O N S ::::::   #
#######################################

# Set prompt function for colored messages
function prompt () {
	case ${1} in
        "-d"|"--default")
			echo -e "${b_CDEF}${@/-d/}${CDEF}";;            # print success message
		"-s"|"--success")
			echo -e "${b_CGSC}${@/-s/}${CDEF}";;            # print success message
		"-e"|"--error")
			echo -e "${b_CRER}${@/-e/}${CDEF}";;            # print error message
		"-w"|"--warning")
			echo -e "${b_CWAR}${@/-w/}${CDEF}";;            # print warning message
		"-i"|"--info")
			echo -e "${b_CCIN}${@/-i/}${CDEF}";;            # print info message
		*)
			echo -e "$@"
		;;
	 esac
}

# Function to check if the script is run as root
function check_root() {
    if [ "$UID" -ne "$ROOT_UID" ]; then
        echo "This script must be run as root. Please run 'sudo ./fpi.sh'"
        exit 1
    fi
}

# Function to check and refresh sudo cache
function check_sudo_cache() {
    # Checks if the sudo timestamp is valid without prompting for a password
    while ! sudo -n true 2> /dev/null; do
        echo -e "Sudo credentials are required to proceed."

        # Force a password prompt
        if ! sudo true; then
            echo "Authentication failed. Trying again..."
        fi
    done
}

# Function to display usage information
function usage() {
    echo "Usage: $0 [OPTION]..."
    echo "            "
    echo "OPTIONS (assumes '-a' if no parameters is informed):"
    echo "  -a, --all          run all update system (dnf, flatpal and fwupdmgr) [Default]"
    echo "  -d, --dnf          run 'dnf upgrade --refresh'"
    echo "  -f, --flatpak      run 'flatpak update'"
    echo "  -x, --firmware     run firmware update commands (fwupdmgr)"
    echo "  -h, --help         Show this help"
    echo ""
}

function show_menu() {
    clear
    prompt -s "========================================"
    prompt -s "    Fedora Post Installation Script     "
    prompt -s "         Author: Pedro Liberal          "
    prompt -s "========================================"
    prompt -s ""
    prompt -w "Menu (Choose one or more options separated by comman)"
    prompt -d " 1. System upgrade (dnf | flatpak | firmware)"
    prompt -d " 2. Base install (copr repositories, packages and better fonts)"
    prompt -d " 3. Microsoft packages"
    prompt -d " 4. Flatpak packages install"
    prompt -d " 5. nVidia install (Requires manual intervention)"
    prompt -d " 0. All steps above"
    prompt -d " -"
    prompt -d " Q. Quit"
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
check_root
show_menu

