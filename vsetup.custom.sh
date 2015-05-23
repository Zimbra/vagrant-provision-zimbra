#!/bin/bash
# commands run to provision host after startup

export DEBIAN_FRONTEND=noninteractive

# map this to the vagrant user but with a home of /home/$myuser
myuser=ppearl

# ID="SomeThing" - remove up to equals sign and strip double quotes
dist=$(grep ^ID= /etc/os-release)
dist=${dist#*=}
dist=${dist#*\"}
dist=${dist%*\"}
prog=${0##*/}

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
function pkgs_ubuntu () { echo "emacs24-nox perl-doc"; }

_install_custom()
{
    _install $(pkgs_$dist) hunspell perltidy

    # workaround for /usr/share/doc/dictionaries-common/README.problems
    # ref: http://stackoverflow.com/questions/23671727/error-with-sudo-apt-get-dictionnary-commons-since-update-to-ubuntu-14-04
    # tbd: /usr/share/debconf/fix_db.pl
    # apt-get upgrade -y -qq

    # setup a pseudo account for myself
    # - in the VM I can pick up my custom envirornment via: su - ppearl
    say "Create entry for ppearl in /etc/passwd"
    grep vagrant /etc/passwd | sed -e "s,vagrant,${myuser},g" | sudo tee -a /etc/passwd

    # custom tunnel for perforce and reviewboard
    # - connect VM ports to preexisting tunnels on my laptop via:
    #   vagrant ssh -- -R 1066:127.1.1.1:1066 -R 1443:127.1.1.1:1443
    # - where:
    #   - .reviewboardrc has: REVIEWBOARD_URL="https://ztun:1443"
    #   - .p4config has:      P4PORT=ztun:1066
    entry="127.0.0.1 ztun" # reviewboard.eng...
    say "Adding entry to /etc/hosts: $entry"
    echo "$entry" | tee -a /etc/hosts
}

#
main
