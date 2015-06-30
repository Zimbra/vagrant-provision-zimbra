# based on:
# https://github.com/smerrill/docker-vagrant-centos/blob/master/centos-6/Dockerfile

FROM centos:centos6
MAINTAINER Phil Pearl <ppearl@zimbra.com>

COPY vagrantize.sh /tmp/
RUN bash /tmp/vagrantize.sh

EXPOSE 22
CMD ["/sbin/init"]
