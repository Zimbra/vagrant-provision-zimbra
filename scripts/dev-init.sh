#! /bin/bash
### BEGIN INIT INFO
# Provides:          zimbra
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start Zimbra development instance.
# Description:       Start Zimbra development instance, if present, as the
#                    user that installed the instance.
### END INIT INFO

function check_run_as ()
{
    cmd=$1

    if [[ ! -x $cmd ]]; then
        echo "$cmd not available!"
        return 1
    fi

    user=$(ls -l $cmd | cut -d ' ' -f 3)

    sudo -u $user -i "$@"
}

function check_run ()
{
    cmd=$1

    if [[ ! -x $cmd ]]; then
        echo "$cmd not available!"
        return 1
    fi

    "$@"
}

case "$1" in
    start)
        check_run_as /opt/zimbra/bin/ldap start
        check_run_as /opt/zimbra/bin/jetty start
        ;;
    stop)
        check_run_as /opt/zimbra/bin/jetty stop

        # note that stopping ldap actually requires root...
        check_run /opt/zimbra/bin/ldap stop
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
