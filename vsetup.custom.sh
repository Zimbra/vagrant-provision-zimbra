#!/bin/bash
# commands run to provision host after startup

prog=${0##*/}
export DEBIAN_FRONTEND=noninteractive

# map this to the vagrant user but with a home of /home/$myuser
myuser="$1"
if [[ -n "$myuser" ]]; then
    if [[ "$myuser" =~ / ]]; then
       echo "$prog: invalid username '$myuser'"
       echo "usage: $prog [username]"
       exit 1
    fi
fi

# ID="SomeThing" - remove up to equals sign and strip double quotes
dist=$( \
  grep ^ID= /etc/os-release 2>/dev/null \
  || cut -d: -f 3 /etc/system-release-cpe 2>/dev/null \
  )
dist=${dist#*=}
dist=${dist#*\"}
dist=${dist%*\"}

case $dist in
    centos|ubuntu)
        ;;
    *)
        echo "$prog does not support OS '$dist' yet"
        exit 1
        ;;
esac

function say () { builtin echo $(date --rfc-3339=s): $prog "$@"; }

function _install () { say "Installing package(s): $@"; _install_$dist "$@"; }
function _install_centos () { yum install -y -q "$@"; }
function _install_ubuntu () { apt-get install -y -qq "$@"; }

function main () { _install_custom; }

# nice (for me) to have...
function pkgs_centos () { echo "emacs-nox"; }
function pkgs_ubuntu () {
    echo \
      $(apt-cache depends emacs | awk '/Depends:/ && /nox/ {print $NF}') \
      "perl-doc"
}

function _install_custom()
{
    _install $(pkgs_$dist) hunspell perltidy
    [[ -n "$myuser" ]] && _update_passwd "$myuser"
    [[ "$myuser" = "ppearl" ]] && _install_hook_${myuser}
}

# setup a pseudo account for myself?
# - in the VM I can pick up my custom envirornment via: su - ppearl
function _update_passwd()
{
    [[ -n "$1" ]] || return
    myuser="$1"
    say "Create entry for ${myuser} in /etc/passwd"
    grep vagrant /etc/passwd | sed -e "s,vagrant,${myuser},g" | sudo tee -a /etc/passwd
}

# custom tunnel for perforce and reviewboard
# - connect VM ports to preexisting tunnels on my laptop via:
#   vagrant ssh -- -R 1066:127.1.1.1:1066 -R 1443:127.1.1.1:1443
# - where:
#   - .reviewboardrc has: REVIEWBOARD_URL="https://ztun:1443"
#   - .p4config has:      P4PORT=ztun:1066
function _install_hook_ppearl()
{
    entry="127.0.0.1 ztun" # reviewboard.eng...
    say "Adding entry to /etc/hosts: $entry"
    echo "$entry" | tee -a /etc/hosts
}

#
main
