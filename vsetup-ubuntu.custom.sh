#!/bin/bash
# commands run to provision host after startup

dist=`lsb_release -is`
[ "$dist" != "Ubuntu" ] && echo "$0 is for Ubuntu, not '$dist'" && exit 1

main()
{
    _install_custom
}

# nice (for me) to have...
_install_custom()
{
    _install emacs24-nox ispell perl-doc perltidy

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
