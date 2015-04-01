#!/bin/bash
# commands run to provision host after startup

_usage()
{
    prog=${0##*/}
    for info in "$@"; do
        echo "$prog: $@"
    done
    echo "Usage: $prog <[-b][-d][-r]>"
    echo "  environment type (choose all desired zimbra related environments):"
    echo "    -b  == build"
    echo "    -d  == development"
    echo "    -r  == runtime (for dev/test)"
}

while getopts bdr opt; do
    case "$opt" in
    b) buildenv=1 ;;
    d) devenv=1 ;;
    r) runenv=1 ;;
    ?) _usage && exit 2;;
    esac
done
shift $(($OPTIND - 1))

[ "$#" -ne 0 ] && _usage && exit 1

# see also:
# http://wiki.eng.zimbra.com/index.php/ZimbraMaven#Jars_which_are_not_available_in_Maven
# - Zimbra patched jars files are in ZimbraCommon/jars-bootstrap in perforce
# - ant reset-all calls the 'maven-seed-local-repo' target
# - if/when modifying your Maven local repository (~/.m2/repository)
#   also check ZimbraServer/mvn.seed.properties (used by ant)
#   see also the mvn-local-jars shell script to populate the local repository

dist=`lsb_release -is`
[ "$dist" != "Ubuntu" ] && echo "$0 is for Ubuntu, not '$dist'" && exit 1

export DEBIAN_FRONTEND=noninteractive

# dev+run
if [ -n "$devenv" -o -n "$runenv" ]; then
    MYSQLPASS="zimbra"
    _install curl netcat memcached redis-server
    _install_mariadb_server
    _install_consul 0.5.0
fi

# build+dev+run
_install_java 8

# build
if [ -n "$buildenv" ]; then
    _install_maven
    _install_buildtools # compilers, dev headers/libs, packaging, ...
fi

# dev
if [ -n "$devenv" ]; then
    _install_devtools # reviewboard
fi

echo "Running dist-upgrade..."
apt-get update -qq && apt-get dist-upgrade -y -qq

###
_install()
{
    for pkg in "$@"; do
        echo "Installing $pkg..."
        apt-get install -y -qq "$pkg"
    done
}

_add_repo()
{
    for rep in "$@"; do
        echo "Adding repository $rep..."
        add-apt-repository -y "$rep"
    done
    echo "Running apt-get update..."
    apt-get update -qq
}

_install_zdevtools()
{
    # reviewboard
    _install python-setuptools
    easy_install -U RBTools # - if not done in primary environment
}

# build environment
_install_buildtools()
{
    # fpm - https://github.com/jordansissel/fpm
    _install ruby-dev; gem install fpm

    _install \
      make cmake gcc g++ patch automake autoconf bison flex bzip2 libtool unzip perl wget

    _install \
      libz-dev libncurses-dev libexpat-dev libpopt-dev libpcre3-dev \
      libreadline-dev libbz2-dev libaio-dev cloog-ppl libperl-dev

    _install dh-make build-essential devscripts fakeroot debootstrap pbuilder
}

_install_maven()
{
    # for java development
    _add_repo ppa:andrei-pozolotin/maven3
    _install ant maven3
}

# known versions: 7 8
_install_java()
{
    _add_repo ppa:webupd8team/java 
    for v in "$@"; do
        debconf-set-selections <<< "oracle-java${v}-installer shared/accepted-oracle-license-v1-1 select true"
        # hide the wget progress output
        _install oracle-java${ver}-installer 2>&1 | grep -v " ........ "
    done
    #OFF update-java-alternatives -s java-7-oracle
}

# consul
# - download via http://www.consul.io/downloads.html
#   /usr/local/bin/consul agent -server -bootstrap-expect 1 -data-dir /var/tmp/consul
_install_consul()
{
    zip="$1"_linux_amd64.zip
    url="https://dl.bintray.com/mitchellh/consul/""$zip"
    loc="/usr/local/bin"
    bin="$loc""/consul"
    if [ -x "$bin" ]; then
        echo "Consul: '$bin' already installed" 
        return
    else
      ( #  do the work in a subshell since we're CD'ing
        cd "$loc" && wget "$url" && unzip "$zip" && rm "$zip" && chmod 755 "$bin"
        [ ! -x "$bin" ] && echo "Consul: '$bin' install failed!"
      )
    fi
}

_install_mariadb_server() {
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQLPASS"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQLPASS"
    _install mariadb-server
    _mariadb_setup
}

_mariadb_setup()
{
    (
        pfrom=3306; pto=7306; file="/etc/mysql/my.cnf"
        echo "Replacing '$pfrom' with '$pto' in '$file'"
        perl -pi -e "s,$pfrom,$pto,g" "$file"
    )
    (
        fdir="/var/lib/mysql"; ddir="/opt/zimbra/mysql/data"
	if [ -d "$ddir" ]; then
            echo "Directory '$ddir' already exists!"
        else
            echo "Copying data from '$fdir' to '$ddir'"
            mkdir -p "$ddir" && cp -pr "$fdir"/* "$ddir"
            [ -e "$ddir"/mysqld.sock ] && rm "$ddir"/mysqld.sock
            ln -s "/var/run/mysqld/mysqld.sock" "$ddir"/mysqld.sock
        fi
    )
    service mysql restart
}
