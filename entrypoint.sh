#!/bin/bash

##############################
#                            #
#    Utility Loader          #
#                            #
##############################

# Loading ini file editor script
cd /
source ./ini_editor.sh

##############################
#                            #
#    Main Entrypoint Logic   #
#                            #
##############################
# Setup tty width so wine console output doesn't prematurely wrap
stty columns 250

# Information output
echo "Running on Debian $(cat /etc/debian_version)"
echo "Current timezone: $(cat /etc/timezone)"
wine --version

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP
echo -e "Server is running on IP: ${INTERNAL_IP}"

# Modify the configuration file with the environment variables
CONFIG_FILE="/home/container/RDS_Data/config/rds_config.ini"
set_config_file "${CONFIG_FILE}"

if [ -f "${CONFIG_FILE}" ]; then
    echo "Configuration file found. Setting Keys"
    if [ -n "${MASTER_PRIVATE_KEY}" ]; then update_key "MasterPrivateKey" "${MASTER_PRIVATE_KEY}"; fi
    if [ -n "${SERVER_NAME}" ]; then update_key "ServerName" "${SERVER_NAME}"; fi
    if [ -n "${PASSWORD}" ]; then update_key "Password" "${PASSWORD}"; fi
    if [ -n "${WHITELIST}" ]; then update_key "Whitelist" "${WHITELIST}"; fi
    if [ -n "${MAX_PLAYERS}" ]; then update_key "MaxPlayers" "${MAX_PLAYERS}"; fi
    if [ -n "${PVP}" ]; then update_key "PVP" "${PVP}"; fi
    if [ -n "${GAME_MODE}" ]; then update_key "GameMode" "${GAME_MODE}"; fi
    if [ -n "${SLEEP_MODE}" ]; then update_key "SleepMode" "${SLEEP_MODE}"; fi
    if [ -n "${ENFORCE_MODS}" ]; then update_key "EnforceMods" "${ENFORCE_MODS}"; fi
    if [ -n "${ICON_URL}" ]; then update_key "IconUrl" "${ICON_URL}"; fi
    if [ -n "${BANNER_URL}" ]; then update_key "BannerUrl" "${BANNER_URL}"; fi
    if [ -n "${SHOW_IN_SERVERLIST}" ]; then update_key "ShowInServerlist" "${SHOW_IN_SERVERLIST}"; fi
    if [ -n "${RESTART_ON_CRASH}" ]; then update_key "RestartOnCrash" "${RESTART_ON_CRASH}"; fi
    if [ -n "${NETWORKING_LAYER}" ]; then update_key "NetworkingLayer" "${NETWORKING_LAYER}"; fi
    if [ -n "${CONSOLE_PORT}" ]; then update_key "ConsolePort" "${CONSOLE_PORT}"; fi
    if [ -n "${UPDATE_BRANCH}" ]; then update_key "UpdateBranch" "${UPDATE_BRANCH}"; fi
    if [ -n "${MAX_SERVER_FPS}" ]; then update_key "MaxServerFPS" "${MAX_SERVER_FPS}"; fi
else
    echo "Configuration file not found. Proceeding to first time launch..."
fi


# Set working directory
cd /home/container

# Download and install SteamCMD
if [ ! -d ./steamcmd ]; then
    echo "SteamCMD not found. Installing..."
    mkdir -p ./steamcmd
    cd ./steamcmd
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    cd /home/container
fi

## just in case someone removed the defaults.
if [ -z "${STEAM_USER}" ] || [ -z "${STEAM_PASS}" ]; then
    echo -e "Steam user or password or authcode is not set.\n"
else
    echo -e "Steam User set to ${STEAM_USER}"
    # Set auth if not set
    if [ -z "${STEAM_AUTH}" ]; then
        STEAM_AUTH=""
    fi

    ## if starting command is updategame or updateboth update the game
    if [ "${STARTUP}" == "updategame" ] || [ "${STARTUP}" == "updateboth" ]; then 
        echo -e "Checking for game updates and updating if necessary..."
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} +@sSteamCmdForcePlatformType windows $(printf %s "+app_update 648800 -beta beta") +quit
    else
        echo -e "Not updating game as startup command is not set to updategame or updateboth. Starting Server"
    fi
fi

# Install necessary to run packages
echo "First launch will throw some errors. Ignore them"

Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} &

# Disable sound 
winetricks -q sound=disabled

# Create Wine prefix directory if necessary
mkdir -p $WINEPREFIX

if [ ! -f "$WINEPREFIX/mono.msi" ]; then
        echo "Installing mono"
        wget -q -O $WINEPREFIX/mono.msi https://dl.winehq.org/wine/wine-mono/9.1.0/wine-mono-9.1.0-x86.msi
fi
wine msiexec /i $WINEPREFIX/mono.msi /qn /quiet /norestart /log $WINEPREFIX/mono_install.log

EXECUTABLE="RaftDedicatedServer.exe"

# if starting command is updateserver or updateboth update the server
if [ "${STARTUP}" == "updateserver" ] || [ "${STARTUP}" == "updateboth" ]; then
    EXECUTABLE="RaftDedicatedServer.exe -update"
else
    echo -e "Not updating server as startup command is not set to updateserver or updateboth. Starting Server..."
fi

# Starting RDS itself
echo -e "#############################################\n# Starting Raft Dedicated Server...         #\n#############################################"
echo -e "  _____    _____     _____ \n |  __ \  |  __ \   / ____|\n | |__) | | |  | | | (___  \n |  _  /  | |  | |  \___ \ \n | | \ \  | |__| |  ____) |\n |_|  \_\ |_____/  |_____/ \n                           \n                           "



/usr/bin/xvfb-run -a -l env WINEDLLOVERRIDES="wininet=native,builtin" wine64 ${EXECUTABLE} < /dev/stdin
exit 0