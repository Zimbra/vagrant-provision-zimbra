#!/bin/bash
# commands run to provision host after startup

# see also:
# http://wiki.eng.zimbra.com/index.php/ZimbraMaven#Jars_which_are_not_available_in_Maven
# - Zimbra patched jars files are in ZimbraCommon/jars-bootstrap in perforce
# - ant reset-all calls the 'maven-seed-local-repo' target
# - if/when modifying your Maven local repository (~/.m2/repository)
#   also check ZimbraServer/mvn.seed.properties (used by ant)
#   see also the mvn-local-jars shell script to populate the local repository

MYSQLPASS="zimbra"
P4CLIENTURL="http://cdist2.perforce.com/perforce/r15.1/bin.linux26x86_64/p4"
ZIMBRA_HOME="/opt/zimbra"

export DEBIAN_FRONTEND=noninteractive

prog=${0##*/}
dist=`lsb_release -is`
[ "$dist" != "Ubuntu" ] && echo "$prog is for Ubuntu, not '$dist'" && exit 1

echo()
{
    builtin echo `date --rfc-3339=s`: $prog "$@"
}

usage()
{
    for info in "$@"; do
        echo "$info"
    done
    cat <<EOF
Usage: $prog <[-b][-d][-r]>
  environment type (choose all desired zimbra related environments):
    -b  == build       ThirdParty FOSS (fpm,gcc,headers,libs,etc.)
    -d  == development Full ZCS builds (ant,java,maven,...)
    -r  == runtime     consul, mariadb, redis, memcached

  Note: runtime uses non-standard ZCS components (instead of
        building the components from ThirdParty)
EOF
}

[ "$#" -eq 0 ] && usage "an argument is required" && exit 1
while getopts "bdrh" opt; do
    case "$opt" in
        b) buildenv=1; echo "selecting environment: build" ;;
        d) devenv=1;   echo "selecting environment: development" ;;
        r) runenv=1;   echo "selecting environment: runtime" ;;
        h) usage && exit 0 ;;
        \?) errors=1 ;;
    esac
done
shift $((OPTIND-1))
[ -n "$errors" ] && usage "invalid arguments" && exit 3
[ "$#" -ne 0 ] && usage "invalid argument: $1" && exit 3

main()
{
    env_all_pre
    [ -n "$devenv" ] && env_dev
    [ -n "$devenv" -o -n "$runenv" ] && env_dev_run
    [ -n "$buildenv" ] && env_build
    env_all_post
}

# build+dev+run
env_all_pre()
{
    echo "checking: $ZIMBRA_HOME exists (may need to be writable for old builds)"
    if [ -n "$ZIMBRA_HOME" ]; then
        if [ ! -d "$ZIMBRA_HOME" ]; then
            echo "mkdir -p '$ZIMBRA_HOME'" && mkdir -p "$ZIMBRA_HOME"
            # perms of 1777 are debatable...
            if [ -n "$devenv" -o -n "$buildenv" ]; then
                echo "chmod 1777 '$ZIMBRA_HOME'" && chmod 1777 "$ZIMBRA_HOME"
            fi
        fi
    fi
}

env_all_post()
{
    echo "Running dist-upgrade..."
    apt-get update -qq && apt-get dist-upgrade -y -qq
}

# dev
env_dev()
{
    _install_ant_maven
    _install_zdevtools # reviewboard
}

# dev+run
env_dev_run()
{
    _install_java 8
    _install curl netcat memcached redis-server
    _install_mariadb_server
    _install_consul 0.5.0
}

# build
env_build()
{
    _install_buildtools # compilers, dev headers/libs, packaging, ...
}

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
        echo "Adding repository '$rep' ..."
        add-apt-repository -y "$rep"
    done
    echo "Running apt-get update -qq ..."
    apt-get update -qq
}

_install_p4client()
{
    # p4 client
    cd /usr/local/bin && wget -nv "$P4CLIENTURL" && chmod 755 p4
}

_install_zdevtools()
{
    _install_p4client
    _install python-setuptools && easy_install -U RBTools # reviewboard
}

# build environment
_install_buildtools()
{
    _install \
      make cmake gcc g++ patch automake autoconf bison flex bzip2 libtool unzip perl wget

    _install \
      libz-dev libncurses-dev libexpat-dev libpopt-dev libpcre3-dev \
      libreadline-dev libbz2-dev libaio-dev cloog-ppl libperl-dev

    # need jdk 1.7 to build openjdk
    _install_java 7

    _install_fpm
}

_install_ant_maven()
{
    # for java development
    _add_repo ppa:andrei-pozolotin/maven3
    _install ant maven3
}

# fpm 1.3.3 bug workaround
_fpm_133_workaround()
{
    fv=`fpm --version 2>/dev/null`
    [ "$fv" = "1.3.3" ] || return

    f="dir.rb"
    dfix="https://raw.githubusercontent.com/jordansissel/fpm/master/lib/fpm/package/$f"
    dest="/var/lib/gems/1.9.1/gems/fpm-1.3.3/lib/fpm/package"

    echo "workaround fpm $fv bug #808/#823 in '$dest/$f'"
    if [ ! -d "$dest" -o ! -r "$dest/$f" ]; then
        echo "file to replace: '$dest/$f' does not exist"
        return
    fi

    (
        cd "$dest" \
        && cp -p "$f" "${f}.ORIG" \
        && wget -nv -O "${f}.NEW" "$dfix" \
        && cp "${f}.NEW" "${f}"
    ) \
    && echo "replaced '$dest/$f' with '$dfix'" \
    || echo "ERROR: replace '$dest/$f' with '$dfix' FAILED" 1>&2
}

# fpm - https://github.com/jordansissel/fpm
_install_fpm()
{
    _install ruby-dev
    gem install fpm && _fpm_133_workaround

    _install build-essential # dh-make devscripts fakeroot debootstrap pbuilder
}

# known versions: 7 8
_install_java()
{
    _add_repo ppa:webupd8team/java
    for v in "$@"; do
        debconf-set-selections <<< "oracle-java${v}-installer shared/accepted-oracle-license-v1-1 select true"
        # hide the wget progress output
        _install oracle-java${v}-installer 2>&1 | grep --line-buffered -v " ........ "
    done
    #OFF update-java-alternatives -s java-7-oracle
}

# consul
# - download via http://www.consul.io/downloads.html
#   /usr/local/bin/consul agent -server -bootstrap-expect 1 -data-dir /var/tmp/consul
_install_consul()
{
    _install zip
    zip="$1"_linux_amd64.zip
    url="https://dl.bintray.com/mitchellh/consul/""$zip"
    loc="/usr/local/bin"
    bin="$loc""/consul"
    if [ -x "$bin" ]; then
        echo "consul: '$bin' already installed"
        return
    else
      ( #  do the work in a subshell since we're CD'ing
        cd "$loc" && wget -nv "$url" && unzip "$zip" && rm "$zip" && chmod 755 "$bin"
        [ ! -x "$bin" ] && echo "consul: '$bin' install failed!"
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

# call main
main
