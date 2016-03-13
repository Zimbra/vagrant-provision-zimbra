if [[ -n "$PATH" ]]; then
    export PATH="/opt/zimbra/bin:$PATH"
fi

if type -P javac; then
    export JAVA_HOME=$(dirname $(dirname $(readlink -f $(type -P javac))))
fi
