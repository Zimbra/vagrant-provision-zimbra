#!/bin/bash -uxe

VAGRANT_USER=${VAGRANT_USER:-vagrant}
VAGRANT_USER_HOME=${VAGRANT_USER_HOME:-/home/${VAGRANT_USER}}
SUDOERS_FILE="/etc/sudoers.d/${VAGRANT_USER}"

# KEY_URL=https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
# wget --no-check-certificate -O authorized_keys "${KEY_URL}"
VAGRANT_INSECURE_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

prog=${0##*/}
function say () { builtin echo $(date --rfc-3339=s): $prog "$@"; }
function usage ()
{
    for info in "$@"; do
        say "$info"
    done
    cat <<EOF
Usage: $0 [-g {groupadd_args}] [-u {useradd_args}] [username]
    -g "{groupadd_args}"
    -u "{useradd_args}"
EOF
}

#[[ "$#" -eq 0 ]] && usage "an argument is required" && exit 1
while getopts "g:u:" opt; do
    case "$opt" in
        g) GROUPADD_ARGS=${OPTARG} ;;
        u) USERADD_ARGS=${OPTARG} ;;
        h) usage && exit 0 ;;
        \?) errors=1 ;;
    esac
done
shift $((OPTIND-1))
[[ -n "$errors" ]] && usage "invalid arguments" && exit 3
[[ "$#" -ne 0 ]] && usage "invalid argument: $1" && exit 3

# https://github.com/sequenceiq/docker-pam/blob/master/centos-6.5/Dockerfile
# - so su will not work...

# see also:
# - https://github.com/boxcutter/centos/blob/master/script/vagrant.sh
# - https://github.com/smerrill/docker-vagrant-centos/blob/master/centos-6/provision.sh
# redhat-lsb-core rsync
yum install -y initscripts awk xargs openssh-clients openssh-server rsyslog sudo

# generate ssh keys
service sshd start
service sshd stop

# turn off all services by default
chkconfig --list | awk '!/ssh|syslog/ && /:on/{print $1}' | xargs -I {} chkconfig {} off

# Set up some things to make /sbin/init and udev work (or not start as appropriate)

# https://github.com/dotcloud/docker/issues/1240#issuecomment-21807183
# ALREADY ON: echo "NETWORKING=yes" > /etc/sysconfig/network

# http://gaijin-nippon.blogspot.com/2013/07/audit-on-lxc-host.html
sed -i -e '/pam_loginuid\.so/ d' /etc/pam.d/sshd
sed -i -e 's/^\(UsePam\) yes/\1 no/i' /etc/ssh/sshd_config

# Kill udev. (http://serverfault.com/a/580504/82874)
echo " " > /sbin/start_udev

# No more requiretty for sudo. (Vagrant likes to run Puppet/shell via sudo.)
sed -i 's/.*requiretty$/Defaults !requiretty/' /etc/sudoers

# Let this run as an unmodified Vagrant box
echo 'Configuring settings for vagrant...'

useradd=(-m -g "${VAGRANT_USER}" -G wheel $USERADD_ARGS)
echo "Creating group '${VAGRANT_USER}' with args '${GROUPADD_ARGS}'"
groupadd ${GROUPADD_ARGS} "${VAGRANT_USER}"
echo "Creating user  '${VAGRANT_USER}' with args '${useradd[@]}'"
useradd "${useradd[@]}" "${VAGRANT_USER}"
echo "${VAGRANT_USER}:${VAGRANT_USER}" | chpasswd

echo "Creating sudoers file '${SUDOERS_FILE}'"
echo "${VAGRANT_USER} ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_FILE}"
chmod 0440 "${SUDOERS_FILE}"

echo "Installing vagrant ssh key"
mkdir -pm 700 ${VAGRANT_USER_HOME}/.ssh
echo "${VAGRANT_INSECURE_KEY}" > "${VAGRANT_USER_HOME}/.ssh/authorized_keys"
chmod 0600 "${VAGRANT_USER_HOME}/.ssh/authorized_keys"
chown -R "${VAGRANT_USER}:${VAGRANT_USER}" "${VAGRANT_USER_HOME}/.ssh"

yum clean all
