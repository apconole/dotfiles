#!/bin/sh

dir0=`pwd`
case $0 in
    ./*) dir0=`pwd` ;;
    */*) dir0=`echo "$0" | sed 's,/[^/]*$,,'` ;;
esac

source "$dir0/bashrc.d/.colors.lib"

#Setup basic bash stuff
echo "$Color_off[$Green + $Color_off] Setting up automatic bash details"
if grep "for rc in ~/.bashrc.d/" ~/.bashrc >/dev/null 2>&1 ; then
	echo "$Color_off[$Red-$Color_off] Bash profile already set to auto-load home scripts."
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
	echo ".bashrc.d exists already."
else
	ln -s "$dir0/bashrc.d" "$HOME/.bashrc.d"
fi

#setup emacs init files
echo "Setup the initial Emacs details."
mkdir -p "$HOME/.emacs.d"

if test -e "$HOME/.emacs.d/emacs.org" -o -h "$HOME/.emacs.d/emacs.org"; then
	echo "emacs.org already exists.  Skipping linking to $dir0/emacs.org."
else
	ln -s "$dir0/emacs.org" "$HOME/.emacs.d/emacs.org"
fi

if test -e "$HOME/.emacs.d/init.el" ; then
	echo "Unable to create init.el - one exists."
else
	cat >"$HOME/.emacs.d/init.el" <<EOF
;;; init.el --- Literate configuration bootstrap  -*- lexical-binding: t -*-

;; All Emacs configuration lives in emacs.org (literate, documented).
;; Sensitive settings (accounts, credentials, paths) live in private.org
;; and are loaded from the generated private.el.
;;
;; To regenerate private.el after editing private.org:
;;   M-x org-babel-tangle   (with private.org as the current buffer)

(require 'org)
(org-babel-load-file (expand-file-name "emacs.org" user-emacs-directory))
EOF
fi

