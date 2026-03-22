#!/bin/bash
# add-mount.sh — append a new encrypted mount entry to ~/.config/autostart-mounts.sh

dir0=`pwd`
case $0 in
    ./*) dir0=`pwd` ;;
    */*) dir0=`echo "$0" | sed 's,/[^/]*$,,'` ;;
esac

source "$dir0/bashrc.d/.colors.lib"

_mount_script="$HOME/.config/autostart-mounts.sh"

if [ ! -e "$_mount_script" ]; then
    printf "${Color_Off_}[${Red_} - ${Color_Off_}] Mount script not found at $_mount_script.\n"
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] Run install.sh first to create it.\n"
    exit 1
fi

# Check keyring availability
_keyring_ok=true
if ! command -v secret-tool >/dev/null 2>&1; then
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] secret-tool not found - keyring integration unavailable.\n"
    _keyring_ok=false
fi

# Determine which tools are available
_tools=()
command -v gocryptfs >/dev/null 2>&1 && _tools+=(gocryptfs)
command -v encfs     >/dev/null 2>&1 && _tools+=(encfs)

if [ ${#_tools[@]} -eq 0 ]; then
    printf "${Color_Off_}[${Red_} - ${Color_Off_}] No supported mount tools found (gocryptfs, encfs).\n"
    exit 1
fi

# Select tool
if [ ${#_tools[@]} -eq 1 ]; then
    _tool="${_tools[0]}"
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] Using $_tool.\n"
else
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] Available tools: ${_tools[*]}\n"
    read -rp "Mount tool to use [${_tools[0]}]: " _tool_input
    _tool="${_tool_input:-${_tools[0]}}"
    if ! printf '%s\n' "${_tools[@]}" | grep -qx "$_tool"; then
        printf "${Color_Off_}[${Red_} - ${Color_Off_}] Unknown tool: $_tool\n"
        exit 1
    fi
fi

# Prompt for cipher directory and mount point
read -rp "$_tool cipher directory: " _cipher
if [ -z "$_cipher" ]; then
    printf "${Color_Off_}[${Red_} - ${Color_Off_}] Cipher directory is required.\n"
    exit 1
fi

read -rp "$_tool mount point for $_cipher: " _mount
if [ -z "$_mount" ]; then
    printf "${Color_Off_}[${Red_} - ${Color_Off_}] Mount point is required.\n"
    exit 1
fi

# Optionally store password in keyring and write the mount line
case "$_tool" in
    gocryptfs)
        if [ "$_keyring_ok" = true ]; then
            read -rp "Store password for $_cipher in keyring now? [y/N] " _store
            if [[ "$_store" =~ ^[Yy]$ ]]; then
                secret-tool store --label="gocryptfs: $_cipher" \
                    gocryptfs-cipher "$_cipher"
            fi
            printf "secret-tool lookup gocryptfs-cipher %q | gocryptfs -passfile /dev/stdin %q %q\n" \
                "$_cipher" "$_cipher" "$_mount" >>"$_mount_script"
        else
            printf "gocryptfs %q %q\n" "$_cipher" "$_mount" >>"$_mount_script"
        fi
        ;;
    encfs)
        if [ "$_keyring_ok" = true ]; then
            read -rp "Store password for $_cipher in keyring now? [y/N] " _store
            if [[ "$_store" =~ ^[Yy]$ ]]; then
                secret-tool store --label="encfs: $_cipher" \
                    encfs-cipher "$_cipher"
            fi
            printf "secret-tool lookup encfs-cipher %q | encfs --stdinpass %q %q\n" \
                "$_cipher" "$_cipher" "$_mount" >>"$_mount_script"
        else
            printf "encfs %q %q\n" "$_cipher" "$_mount" >>"$_mount_script"
        fi
        ;;
esac

printf "${Color_Off_}[${Green_} + ${Color_Off_}] Appended $_tool mount ($_cipher -> $_mount) to $_mount_script.\n"
