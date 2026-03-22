#!/bin/bash

dir0=`pwd`
case $0 in
    ./*) dir0=`pwd` ;;
    */*) dir0=`echo "$0" | sed 's,/[^/]*$,,'` ;;
esac

source "$dir0/bashrc.d/.colors.lib"

#Setup basic bash stuff
printf "$Color_Off_[$Green_ + $Color_Off_] Setting up automatic bash details\n"
if grep "for rc in ~/.bashrc.d/" ~/.bashrc >/dev/null 2>&1 ; then
    printf "$Color_Off_[$Red_ - $Color_Off_] Bash profile already set to auto-load home scripts.\n"
else
    cat >~/.bashrc <<EOF
# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
EOF
fi

if test -d "$HOME/.bashrc.d" -o -h "$HOME/.bashrc.d" ; then
    printf "$Color_Off_[$Red_ - $Color_Off_] .bashrc.d exists already.\n"
else
    ln -s "$dir0/bashrc.d" "$HOME/.bashrc.d"
fi

if test ! -e "$HOME/.bashrc.d/.colors.lib" ; then
    printf "$Color_Off_[$Green_ + $Color_Off_] Adding colors lib.\n"
    ln -s "$dir0/bashrc.d/.colors.lib" "$HOME/.bashrc.d/.colors.lib"
fi

if test ! -e "$HOME/.bashrc.d/.git.lib" ; then
    printf "$Color_Off_[$Green_ + $Color_Off_] Adding git-ps lib.\n"
    ln -s "$dir0/bashrc.d/.git.lib" "$HOME/.bashrc.d/.git.lib"
fi

if test ! -e "$HOME/.bashrc.d/ps1.conf" ; then
    printf "$Color_Off_[$Green_ + $Color_Off_] Adding PS1 config.\n"
    ln -s "$dir0/bashrc.d/ps1.conf" "$HOME/.bashrc.d/ps1.conf"
fi

# Generate a bashrc.d env-vars file
if test ! -e "$HOME/.bashrc.d/env.vars" ; then
    cat > "$HOME/.bashrc.d/env.vars" <<EOF
# Extra variables to add to the bash environment
EOF
fi

# Detect distribution and install required packages
printf "$Color_Off_[$Green_ + $Color_Off_] Detecting distribution.\n"
_pkg_family="unknown"
_pkg_install=""
_pkg_check=""

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
        fedora|rhel|centos|rocky|almalinux)  _pkg_family="fedora" ;;
        debian|ubuntu|linuxmint|pop)         _pkg_family="debian" ;;
        arch|manjaro|endeavouros|artix)      _pkg_family="arch"   ;;
        *)
            # ID_LIKE covers derivatives (e.g. ID=fedora in a spin)
            case "${ID_LIKE-}" in
                *fedora*|*rhel*)  _pkg_family="fedora" ;;
                *debian*|*ubuntu*) _pkg_family="debian" ;;
                *arch*)            _pkg_family="arch"   ;;
            esac
            ;;
    esac
fi

# Fall back to probing the package manager if os-release didn't resolve
if [ "$_pkg_family" = "unknown" ]; then
    if   command -v dnf    >/dev/null 2>&1; then _pkg_family="fedora"
    elif command -v apt-get >/dev/null 2>&1; then _pkg_family="debian"
    elif command -v pacman  >/dev/null 2>&1; then _pkg_family="arch"
    fi
fi

case "$_pkg_family" in
    fedora) _pkg_install="sudo dnf install -y";          _pkg_check="rpm -q" ;;
    debian) _pkg_install="sudo apt-get install -y";      _pkg_check="dpkg-query -W" ;;
    arch)   _pkg_install="sudo pacman -S --noconfirm";   _pkg_check="pacman -Q" ;;
esac

if [ "$_pkg_family" = "unknown" ]; then
    printf "$Color_Off_[$Yellow_ ! $Color_Off_] Could not detect distribution - skipping package installation.\n"
else
    printf "$Color_Off_[$Green_ + $Color_Off_] Detected family: $_pkg_family.\n"

    # Check each package and collect missing ones, then install in one shot.
    _check_and_install() {
        local desc="$1"; shift
        local missing=""
        for pkg in "$@"; do
            $_pkg_check "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
        done
        if [ -n "$missing" ]; then
            printf "$Color_Off_[$Green_ + $Color_Off_] Installing $desc:$missing\n"
            # shellcheck disable=SC2086
            $_pkg_install $missing
        else
            printf "$Color_Off_[$Green_ + $Color_Off_] $desc: all present.\n"
        fi
    }

    case "$_pkg_family" in
        fedora)
            _check_and_install "kernel development" \
                gcc make flex bison bc perl \
                elfutils-libelf-devel openssl-devel ncurses-devel \
                dwarves coccinelle sparse ctags cscope \
                python3-sphinx git patch

            _check_and_install "DPDK development" \
                numactl-devel libpcap-devel python3-pyelftools \
                meson ninja-build pkg-config \
                libbpf-devel libmnl-devel clang llvm

            _check_and_install "Open vSwitch development" \
                autoconf automake libtool libcap-ng-devel \
                graphviz python3-twisted python3-six \
                libnl3-devel libunwind-devel

            _check_and_install "developer tools" \
                gdb valgrind strace perf bpftrace bpftool ccache \
                emacs gnupg2 git-email
            ;;

        debian)
            _check_and_install "kernel development" \
                gcc make flex bison bc perl \
                libelf-dev libssl-dev libncurses-dev \
                dwarves coccinelle sparse universal-ctags cscope \
                python3-sphinx git patch

            _check_and_install "DPDK development" \
                libnuma-dev libpcap-dev python3-pyelftools \
                meson ninja-build pkg-config \
                libbpf-dev libmnl-dev clang llvm

            _check_and_install "Open vSwitch development" \
                autoconf automake libtool libcap-ng-dev \
                graphviz python3-twisted python3-six \
                libnl-3-dev libunwind-dev

            _check_and_install "developer tools" \
                gdb valgrind strace linux-perf bpftrace bpftool ccache \
                emacs gnupg2 git-email
            ;;

        arch)
            _check_and_install "kernel development" \
                gcc make flex bison bc perl \
                libelf openssl ncurses \
                pahole coccinelle sparse ctags cscope \
                python-sphinx git patch

            _check_and_install "DPDK development" \
                numactl libpcap python-pyelftools \
                meson ninja pkgconf \
                libbpf libmnl clang llvm

            _check_and_install "Open vSwitch development" \
                autoconf automake libtool libcap-ng \
                graphviz python-twisted python-six \
                libnl libunwind

            # git send-email is included in the arch 'git' package
            _check_and_install "developer tools" \
                gdb valgrind strace perf bpftrace bpftool ccache \
                emacs gnupg
            ;;
    esac
fi

#setup emacs init files
printf "$Color_Off_[$Green_ + $Color_Off_] Setup the initial Emacs details.\n"
mkdir -p "$HOME/.emacs.d"

if test -e "$HOME/.emacs.d/emacs.org" -o -h "$HOME/.emacs.d/emacs.org"; then
    printf "$Color_Off_[$Red_ - $Color_Off_] emacs.org already exists.  Skipping linking to $dir0/emacs.org.\n"
else
    ln -s "$dir0/emacs.org" "$HOME/.emacs.d/emacs.org"
fi

if test -e "$HOME/.emacs.d/init.el" ; then
    printf "$Color_Off_[$Red_ - $Color_Off_] Unable to create init.el - one exists.\n"
else
    cat >"$HOME/.emacs.d/init.el" <<EOF
;;; init.el --- Literate configuration bootstrap  -*- lexical-binding: t -*-

;; All Emacs configuration lives in emacs.org (literate, documented).
;; Sensitive settings (accounts, credentials, paths) live in private.org
;; and are loaded from the generated private.el.
;;
;; To regenerate private.el after editing private.org:
;;   M-x org-babel-tangle   (with private.org as the current buffer)

;; Suppress the "following symlink" prompt for version-controlled org files.
(setq vc-follow-symlinks t)

(require 'org)
(org-babel-load-file (expand-file-name "emacs.org" user-emacs-directory))
EOF
fi

if test -e "$dir0/private.org" ; then
    printf "$Color_Off_[$Green_ + $Color_Off_] Detected private.org, linking.\n"
    if test ! -h "$HOME/.emacs.d/private.org" ; then
        ln -s "$dir0/private.org" "$HOME/.emacs.d/private.org"
        printf "$Color_Off_[$Green_ + $Color_Off_] Linked.\n"
    else
        printf "$Color_Off_[$Red_ + $Color_Off_] A private.org already exists.\n"
    fi

    # Setup the initial private.org tangle
    if test ! -e "$HOME/.emacs.d/private.el" ; then
        emacs -Q --batch "$HOME/.emacs.d/private.org" \
              -l org --eval "(org-babel-tangle)"
    fi
else
    printf "$Color_Off_[$Red_ - $Color_Off_] private.org not found.\n"
    if test -e "$dir0/private.org.example" ; then
        read -rp "Create private.org from example now? [y/N] " _create_private
        if [[ "$_create_private" =~ ^[Yy]$ ]]; then
            read -rp "Full name: " _priv_name
            read -rp "Email address: " _priv_email
            read -rp "SMTP server: " _priv_smtp_server
            read -rp "SMTP port [587]: " _priv_smtp_port
            _priv_smtp_port="${_priv_smtp_port:-587}"
            read -rp "IMAP server: " _priv_imap_server
            read -rp "GPG key ID (fingerprint or email): " _priv_gpg_key

            _priv_from="$_priv_name <$_priv_email>"
            _priv_smtp_method="smtp $_priv_smtp_server $_priv_smtp_port $_priv_email"
            _priv_smtp_accounts="(\"$_priv_email\" \"$_priv_name\" \"$_priv_smtp_server\" $_priv_smtp_port)"

            sed \
                -e "s|@EMAIL_ADDRESS@|$_priv_email|g" \
                -e "s|@EMAIL_NAME@|$_priv_name|g" \
                -e "s|@SMTP_ACCOUNTS@|$_priv_smtp_accounts|g" \
                -e "s|@SMTP_SERVER@|$_priv_smtp_server|g" \
                -e "s|@SMTP_SERVICE_PORT@|$_priv_smtp_port|g" \
                -e "s|@IMAP_SERVER@|$_priv_imap_server|g" \
                -e "s|@ADDRESS@|$_priv_email|g" \
                -e "s|@FROM_ADDRESS_LINE@|$_priv_from|g" \
                -e "s|@SMTP_METHOD@|$_priv_smtp_method|g" \
                -e "s|@USER_GPG_KEYID@|$_priv_gpg_key|g" \
                -e "s|@HOME@|$HOME|g" \
                "$dir0/private.org.example" > "$dir0/private.org"

            ln -s "$dir0/private.org" "$HOME/.emacs.d/private.org"
            emacs -Q --batch "$HOME/.emacs.d/private.org" \
                  -l org --eval "(org-babel-tangle)"
            printf "$Color_Off_[$Green_ + $Color_Off_] Created and tangled private.org.\n"
        else
            printf "$Color_Off_[$Red_ - $Color_Off_] Skipping private.org - rerun install after creating it from private.org.example.\n"
        fi
    fi
fi

# Setup ~/.authinfo.gpg
printf "$Color_Off_[$Green_ + $Color_Off_] Checking for GPG.\n"
if command -v gpg >/dev/null 2>&1; then
    if test -e "$HOME/.authinfo.gpg" ; then
        printf "$Color_Off_[$Red_ - $Color_Off_] ~/.authinfo.gpg already exists, skipping.\n"
    else
        read -rp "Setup ~/.authinfo.gpg for email credentials? [y/N] " _setup_authinfo
        if [[ "$_setup_authinfo" =~ ^[Yy]$ ]]; then
            # Reuse values from private.org creation if available, otherwise prompt
            if [ -z "$_priv_gpg_key" ]; then
                read -rp "GPG key ID for encryption: " _priv_gpg_key
            fi
            if [ -z "$_priv_imap_server" ]; then
                read -rp "IMAP server: " _priv_imap_server
            fi
            if [ -z "$_priv_smtp_server" ]; then
                read -rp "SMTP server: " _priv_smtp_server
            fi
            if [ -z "$_priv_smtp_port" ]; then
                read -rp "SMTP server Port [587]: " _priv_smtp_port
                _priv_smtp_port="${_priv_smtp_port:-587}"
            fi
            if [ -z "$_priv_email" ]; then
                read -rp "Email login (username): " _priv_email
            fi

            read -rsp "IMAP password: " _authinfo_imap_pass
            printf "\n"
            read -rsp "SMTP password (leave blank if same as IMAP): " _authinfo_smtp_pass
            printf "\n"
            [ -z "$_authinfo_smtp_pass" ] && _authinfo_smtp_pass="$_authinfo_imap_pass"

            _authinfo_tmp=$(mktemp)
            printf "machine %s login %s password %s\n" \
                "$_priv_imap_server" "$_priv_email" "$_authinfo_imap_pass" > "$_authinfo_tmp"
            printf "machine %s login %s password %s port %s\n" \
                "$_priv_smtp_server" "$_priv_email" "$_authinfo_smtp_pass" >> "$_authinfo_tmp" "$_priv_smtp_port"

            gpg --recipient "$_priv_gpg_key" --encrypt --output "$HOME/.authinfo.gpg" "$_authinfo_tmp"
            shred -u "$_authinfo_tmp"
            printf "$Color_Off_[$Green_ + $Color_Off_] Created ~/.authinfo.gpg.\n"
        fi
    fi
else
    printf "$Color_Off_[$Yellow_ ! $Color_Off_] gpg not found - install gnupg for .authinfo.gpg support.\n"
fi

# Add Emacs as editor
if test -e "$HOME/.bashrc.d/env.vars"; then
    if grep "EDITOR" "$HOME/.bashrc.d/env.vars" >/dev/null 2>&1 ; then
        printf "$Color_off_[$Red_ - $Color_Off_] Skipping EDITOR.\n"
    else
        echo "export EDITOR=\"emacs\"" >> "$HOME/.bashrc.d/env.vars"
        printf "$Color_off_[$Green_ - $Color_Off_] EDITOR is emacs.\n"
    fi
fi

# Setup ~/bin and add-mount utility
printf "$Color_Off_[$Green_ + $Color_Off_] Setting up ~/bin directory.\n"
mkdir -p "$HOME/bin"

if test ! -e "$HOME/.bashrc.d/path.conf" ; then
    printf "$Color_Off_[$Green_ + $Color_Off_] Adding PATH config for ~/bin.\n"
    ln -s "$dir0/bashrc.d/path.conf" "$HOME/.bashrc.d/path.conf"
else
    printf "$Color_Off_[$Red_ - $Color_Off_] path.conf already exists, skipping.\n"
fi

if test ! -e "$HOME/bin/add-mount" ; then
    printf "$Color_Off_[$Green_ + $Color_Off_] Linking add-mount into ~/bin.\n"
    ln -s "$dir0/add-mount.sh" "$HOME/bin/add-mount"
else
    printf "$Color_Off_[$Red_ - $Color_Off_] ~/bin/add-mount already exists, skipping.\n"
fi

# Setup auto-loading stuff
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

printf "${Color_Off_}[${Green_} + ${Color_Off_}] Checking for encrypted filesystem tools.\n"
for tool in gocryptfs encfs cryptomator; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf "${Color_Off_}[${Green_} + ${Color_Off_}] Found $tool.\n"
    else
        printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] $tool not found - install it for encrypted mount support.\n"
    fi
done

# Check keyring stack
printf "${Color_Off_}[${Green_} + ${Color_Off_}] Checking keyring stack.\n"
_keyring_ok=true

if command -v secret-tool >/dev/null 2>&1; then
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] Found secret-tool.\n"
else
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] secret-tool not found - install libsecret-tools for keyring integration.\n"
    _keyring_ok=false
fi

if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] Found gnome-keyring-daemon.\n"
else
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] gnome-keyring-daemon not found - install gnome-keyring for secret storage.\n"
    _keyring_ok=false
fi

if grep -rl "pam_gnome_keyring" /etc/pam.d/ >/dev/null 2>&1; then
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] PAM keyring integration is configured.\n"
else
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] pam_gnome_keyring not found in /etc/pam.d/ - keyring may not auto-unlock at login.\n"
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] Add 'auth optional pam_gnome_keyring.so' and 'session optional pam_gnome_keyring.so auto_start' to your PAM login config.\n"
    _keyring_ok=false
fi

# Create a user-editable mount script that runs at login
_mount_script="$HOME/.config/autostart-mounts.sh"
if [ -e "$_mount_script" ]; then
    printf "${Color_Off_}[${Red_} - ${Color_Off_}] Mount script already exists at $_mount_script, skipping.\n"
else
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] Creating encrypted mount script at $_mount_script.\n"
    cat >"$_mount_script" <<'MOUNTEOF'
#!/bin/bash
# Auto-mount script for encrypted filesystems.
# Cryptomator vaults are managed through the Cryptomator GUI on first launch.

MOUNTEOF

    if command -v gocryptfs >/dev/null 2>&1; then
        while true; do
            read -rp "gocryptfs cipher directory (leave blank to stop): " _gc_cipher
            [ -z "$_gc_cipher" ] && break
            read -rp "gocryptfs mount point for $_gc_cipher: " _gc_mount
            if [ "$_keyring_ok" = true ]; then
                read -rp "Store password for $_gc_cipher in keyring now? [y/N] " _gc_store
                if [[ "$_gc_store" =~ ^[Yy]$ ]]; then
                    secret-tool store --label="gocryptfs: $_gc_cipher" \
                        gocryptfs-cipher "$_gc_cipher"
                fi
                printf "secret-tool lookup gocryptfs-cipher %q | gocryptfs -passfile /dev/stdin %q %q\n" \
                    "$_gc_cipher" "$_gc_cipher" "$_gc_mount" >>"$_mount_script"
            else
                printf "gocryptfs %q %q\n" "$_gc_cipher" "$_gc_mount" >>"$_mount_script"
            fi
        done
    fi

    if command -v encfs >/dev/null 2>&1; then
        while true; do
            read -rp "encfs cipher directory (leave blank to stop): " _ef_cipher
            [ -z "$_ef_cipher" ] && break
            read -rp "encfs mount point for $_ef_cipher: " _ef_mount
            if [ "$_keyring_ok" = true ]; then
                read -rp "Store password for $_ef_cipher in keyring now? [y/N] " _ef_store
                if [[ "$_ef_store" =~ ^[Yy]$ ]]; then
                    secret-tool store --label="encfs: $_ef_cipher" \
                        encfs-cipher "$_ef_cipher"
                fi
                printf "secret-tool lookup encfs-cipher %q | encfs --stdinpass %q %q\n" \
                    "$_ef_cipher" "$_ef_cipher" "$_ef_mount" >>"$_mount_script"
            else
                printf "encfs %q %q\n" "$_ef_cipher" "$_ef_mount" >>"$_mount_script"
            fi
        done
    fi

    chmod +x "$_mount_script"
fi

if [ -e "$AUTOSTART_DIR/encrypted-mounts.desktop" ]; then
    printf "${Color_Off_}[${Red_} - ${Color_Off_}] Encrypted mounts autostart entry already exists, skipping.\n"
else
    printf "${Color_Off_}[${Green_} + ${Color_Off_}] Registering encrypted mounts autostart entry.\n"
    cat >"$AUTOSTART_DIR/encrypted-mounts.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Encrypted Mounts
Exec=$_mount_script
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
fi

# Bitwarden autostart
printf "${Color_Off_}[${Green_} + ${Color_Off_}] Checking for Bitwarden.\n"
_bw_exec=""
_bw_ssh_sock=""
if command -v bitwarden >/dev/null 2>&1; then
    _bw_exec="bitwarden --start-hidden"
    _bw_ssh_sock="$HOME/.bitwarden-ssh-agent.sock"
elif flatpak list 2>/dev/null | grep -qi "bitwarden"; then
    _bw_exec="flatpak run com.bitwarden.desktop --start-hidden"
    _bw_ssh_sock="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
fi

if [ -n "$_bw_exec" ]; then
    if [ -e "$AUTOSTART_DIR/bitwarden.desktop" ]; then
        printf "${Color_Off_}[${Red_} - ${Color_Off_}] Bitwarden autostart entry already exists, skipping.\n"
    else
        printf "${Color_Off_}[${Green_} + ${Color_Off_}] Registering Bitwarden autostart entry.\n"
        cat >"$AUTOSTART_DIR/bitwarden.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Bitwarden
Exec=$_bw_exec
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
    fi
else
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] Bitwarden not found - install it for password manager autostart.\n"
fi

# Setup XFCE keyboard shortcuts
printf "${Color_Off_}[${Green_} + ${Color_Off_}] Checking for xfconf-query.\n"
if command -v xfconf-query >/dev/null 2>&1; then
    # Helper: set a keybind idempotently, warn if already bound to something else
    _xfce_keybind() {
        local key="$1" cmd="$2"
        local prop="/commands/custom/$key"
        local existing
        existing=$(xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" 2>/dev/null)
        if [ -n "$existing" ]; then
            if [ "$existing" = "$cmd" ]; then
                printf "${Color_Off_}[${Red_} - ${Color_Off_}] $key already bound to $cmd, skipping.\n"
            else
                printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] $key already bound to '$existing' => changing ('$cmd').\n"
		xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -n -t string -s "$cmd"
            fi
        else
            xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -n -t string -s "$cmd"
            printf "${Color_Off_}[${Green_} + ${Color_Off_}] Bound $key -> $cmd\n"
        fi
    }

    # Detect terminal
    _term_cmd=""
    for _t in xfce4-terminal gnome-terminal alacritty kitty xterm; do
        if command -v "$_t" >/dev/null 2>&1; then
            _term_cmd="$_t"
            break
        fi
    done
    if [ -z "$_term_cmd" ]; then
        read -rp "Terminal command (none detected): " _term_cmd
    else
        read -rp "Terminal command [$_term_cmd]: " _term_input
        [ -n "$_term_input" ] && _term_cmd="$_term_input"
    fi

    _xfce_keybind "<Super>e" "emacs"
    _xfce_keybind "<Super>t" "$_term_cmd"
else
    printf "${Color_Off_}[${Yellow_} ! ${Color_Off_}] xfconf-query not found - skipping XFCE keybindings.\n"
fi

# Setup ~/.gitconfig
printf "$Color_Off_[$Green_ + $Color_Off_] Setting up git configuration.\n"
if test -e "$HOME/.gitconfig"; then
    printf "$Color_Off_[$Red_ - $Color_Off_] ~/.gitconfig already exists, skipping.\n"
else
    # Try to pull values from private.el first, then fall back to shell
    # variables set during private.org creation, then prompt.
    # Uses Emacs in batch mode to evaluate the variable so any valid elisp works.
    _parse_privel() {
        emacs -Q --batch \
              --load "$HOME/.emacs.d/private.el" \
              --eval "(princ $1)" 2>/dev/null
    }

    if [ -z "$_priv_name" ];        then _priv_name=$(_parse_privel "user-full-name"); fi
    if [ -z "$_priv_email" ];       then _priv_email=$(_parse_privel "user-mail-address"); fi
    if [ -z "$_priv_gpg_key" ];     then _priv_gpg_key=$(_parse_privel "epg-user-id"); fi
    if [ -z "$_priv_smtp_server" ]; then _priv_smtp_server=$(_parse_privel "smtpmail-smtp-server"); fi
    if [ -z "$_priv_smtp_port" ];   then _priv_smtp_port=$(_parse_privel "smtpmail-smtp-service"); fi

    [ -z "$_priv_name" ]        && read -rp "Git user name: " _priv_name
    [ -z "$_priv_email" ]       && read -rp "Git email: " _priv_email
    [ -z "$_priv_gpg_key" ]     && read -rp "GPG signing key ID: " _priv_gpg_key
    [ -z "$_priv_smtp_server" ] && read -rp "SMTP server for git send-email: " _priv_smtp_server
    [ -z "$_priv_smtp_port" ]   && { read -rp "SMTP port [587]: " _priv_smtp_port; _priv_smtp_port="${_priv_smtp_port:-587}"; }

    cat > "$HOME/.gitconfig" <<EOF
[include]
	path = $dir0/gitconfig.base

[user]
	name = $_priv_name
	email = $_priv_email
	signingkey = $_priv_gpg_key

[commit]
	gpgsign = true

[sendemail]
	smtpserver = $_priv_smtp_server
	smtpserverport = $_priv_smtp_port
	smtpencryption = tls
	smtpuser = $_priv_email
EOF
    printf "$Color_Off_[$Green_ + $Color_Off_] Created ~/.gitconfig.\n"
fi

# Add extra variables like SSH_AUTH_SOCK
if test -n "$_bw_exec" -a -e "$HOME/.bashrc.d/env.vars"; then
    if grep "SSH_AUTH_SOCK" "$HOME/.bashrc.d/env.vars" >/dev/null 2>/dev/null ; then
        printf "$Color_Off_[$Red_ - $Color_Off_] Skipping SSH_AUTH_SOCK.\n"
    else
        echo "export SSH_AUTH_SOCK=\"$_bw_ssh_sock\"" >> "$HOME/.bashrc.d/env.vars"
        printf "$Color_Off_[$Green_ - $Color_Off_] SSH_AUTH_SOCK is bitwarden.\n"
    fi
fi
