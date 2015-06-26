#!/bin/bash -uxe

SSH_USER=${SSH_USERNAME:-vagrant}
SSH_USER_HOME=${SSH_USER_HOME:-/home/${SSH_USER}}
SUDOERS_FILE="/etc/sudoers.d/${SSH_USER}"
VAGRANT_INSECURE_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

# see also:
# - https://github.com/boxcutter/centos/blob/master/script/vagrant.sh
# - https://github.com/smerrill/docker-vagrant-centos/blob/master/centos-6/provision.sh

yum install -y initscripts centos-release redhat-lsb-core openssh-clients openssh-server
yum install -y rsyslog sudo rsync

# Set up some things to make /sbin/init and udev work (or not start as appropriate)

# https://github.com/dotcloud/docker/issues/1240#issuecomment-21807183
echo "NETWORKING=yes" > /etc/sysconfig/network

# http://gaijin-nippon.blogspot.com/2013/07/audit-on-lxc-host.html
sed -i -e '/pam_loginuid\.so/ d' /etc/pam.d/sshd

# Kill udev. (http://serverfault.com/a/580504/82874)
echo " " > /sbin/start_udev

# No more requiretty for sudo. (Vagrant likes to run Puppet/shell via sudo.)
sed -i 's/.*requiretty$/Defaults !requiretty/' /etc/sudoers

# Let this run as an unmodified Vagrant box
echo 'Configuring settings for vagrant'

echo "Creating group and user '${SSH_USER}'"
groupadd "${SSH_USER}"
useradd "${SSH_USER}" -g "${SSH_USER}" -G wheel
echo "${SSH_USER}:${SSH_USER}" | chpasswd

echo "Creating sudoers file '${SUDOERS_FILE}'"
echo "${SSH_USER} ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_FILE}"
chmod 0440 "${SUDOERS_FILE}"

# KEY_URL=https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
# wget --no-check-certificate -O authorized_keys "${KEY_URL}"
echo "Installing vagrant ssh key"
mkdir -pm 700 ${SSH_USER_HOME}/.ssh
echo "${VAGRANT_INSECURE_KEY}" > "${SSH_USER_HOME}/.ssh/authorized_keys"
chmod 0600 "${SSH_USER_HOME}/.ssh/authorized_keys"
chown -R "${SSH_USER}:${SSH_USER}" "${SSH_USER_HOME}/.ssh"

# Customize the message of the day
#echo 'Welcome to your Vagrant-built Docker container.' > /etc/motd
