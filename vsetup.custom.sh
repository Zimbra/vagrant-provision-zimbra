#!/bin/bash
# commands run to provision host after startup

export DEBIAN_FRONTEND=noninteractive

prog=${0##*/}
dist=`lsb_release -is`
[ "$dist" != "Ubuntu" ] && echo "$prog is for Ubuntu, not '$dist'" && exit 1

echo()
{
    builtin echo `date --rfc-3339=s`: $prog "$@"
}

main()
{
    _install_custom
}

# nice (for me) to have...
_install_custom()
{
    _install emacs24-nox
    _install ispell
    # workaround for /usr/share/doc/dictionaries-common/README.problems
    # ref: http://stackoverflow.com/questions/23671727/error-with-sudo-apt-get-dictionnary-commons-since-update-to-ubuntu-14-04
    # tbd: /usr/share/debconf/fix_db.pl
    apt-get upgrade -y -qq
    _install perl-doc perltidy

    # setup a pseudo account for myself
    # - in the VM I can pick up my custom envirornment via: su - ppearl
    echo "Create entry for ppearl in /etc/passwd"
    grep vagrant /etc/passwd | sed -e 's,vagrant,ppearl,g' | sudo tee -a /etc/passwd

    # custom tunnel for perforce and reviewboard
    # - connect VM ports to preexisting tunnels on my laptop via:
    #   vagrant ssh -- -R 1066:127.1.1.1:1066 -R 1443:127.1.1.1:1443
    # - where:
    #   - .reviewboardrc has: REVIEWBOARD_URL="https://ztun:1443"
    #   - .p4config has:      P4PORT=ztun:1066
    entry="127.0.0.1 ztun reviewboard.eng.zimbra.com"
    echo "Adding entry to /etc/hosts: $entry"
    echo "$entry" | tee -a /etc/hosts
}

_install()
{
    for pkg in "$@"; do
        echo "Installing $pkg..."
        apt-get install -y -qq "$pkg"
    done
}

#
main
