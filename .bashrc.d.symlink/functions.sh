###############################################################################
#
# Function definitions


tailf() {
    # tail -f with color (through batcat)
    tail -f $1 | batcat --paging=never -l log
}

installkernel() {
    # Install an ipython kernel.
    if ! pip list | grep ipykernel; then
        pip install ipykernel
    fi
    python -m ipykernel install --user --name $(basename $VIRTUAL_ENV) --display-name $(basename $VIRTUAL_ENV)
}

releasemsg() {
    # Outputs a message suitable for a release description. This script
    # optionally takes a FROM tag and a TO tag as command line parameter to
    # diff from. The release message will include commits from $FROM to $TO if
    # provided. FROM defaults to the latest tag on the *current* branch and TO
    # defaults to HEAD.
    if [ -z "$1" ]
    then
        FROM=$(git tag --sort=taggerdate | tail -n1)
    else
        FROM=$1
    fi

    if [ -z "$2" ]
    then
        TO=HEAD
    else
        TO=$2
    fi

    repo=$(git config --get remote.origin.url | cut -d : -f 2 | cut -d . -f 1)
    URL="https://github.com/${repo}/commit"
    git log --reverse $FROM..$TO --no-merges --format="- %s [%h]($URL/%h)"
}

secret() {
    attribute=$1
    value=$2

    password=$(secret-tool lookup "$attribute" "$value")
    exit_code=$?

    if [[ "$exit_code" != "0" ]];
    then
        echo "could not get password, error $exit_code"
        return 1
    else
        echo $password
    fi
}

ntfy() {
    curl -d "${1}" ntfy.sh/hdemers
}
