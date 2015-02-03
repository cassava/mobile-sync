# synclib.sh

# Version 2.5  (3. February 2015)
# Copyright (c) 2010-2015, Ben Morgan <neembi@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

_version="2.5"

# Set the colors for the terminal
cBOLD="\e[1m"
cESC="\e[0m"

cBLUE="\e[1;34m"
cRED="\e[1;31m"
cGREEN="\e[1;32m"
cWHITE="\e[1;37m"
cYELLOW="\e[1;33m"
cCYAN="\e[1;36m"
cMAGENTA="\e[1;35m"

# Top message
function info() {
    printf "$cBOLD$cGREEN==>$cWHITE $1 $cESC\n"
}

# Medium message
function message() {
    printf "$cBOLD$cBLUE->$cWHITE $1 $cESC\n"
}

# Error message
function error() {
    printf "$cBOLD$cRED==> ERROR:$cWHITE $1 $cESC\n"
}

function var() {
    printf "$cYELLOW$1$cWHITE\n"
}

function group() {
    printf "$cBLUE$1$cWHITE\n"
}

function host() {
    printf "$cMAGENTA$1$cWHITE\n"
}

function confirm() {
    local msg=$1  # message to print: "$msg [y/N] "

    printf "$cBOLD$cBLUE::$cWHITE $msg $cESC[y/N] "
    local ans
    read -r ans
    case $ans in
        y|yes|Y|Yes )
            return 0
            ;;
        * )
            return 1
            ;;
    esac
}

# Turn force temporarily on for the following command.
function force() {
    local force_bak=$force
    force=1
    $@
    force=$force_bak
}

# Compress a directory or file to the given location on this usb drive,
# IF the destination file does not already exist.
function ucompress() {
    output=$1 # output file to compress to
    input=$2  # input directory or file to compress

    if [[ $input -nt $startdir/$output ]]; then
        compress $1 $2
    else
        message "skipping: `var $input`"
    fi
}

# Compress a directory or file to the given location on this usb drive.
function compress() {
    local output=$1 # output file to compress to
    local input=$2  # input directory or file to compress

    message "compressing: `var $input` to $output"
    sleep $timeout
    tar caf $startdir/$output $input
    if [[ $? -ne 0 ]]; then
        error "Last command ended with an error."
        if [[ $force -eq 0 ]]; then
            exit 2
        fi
    fi
}

# Use rsync to keep two folders synchronized.
function synch() {
    local output=$1 # output location to sync to
    local input=$2  # input directory
    shift 2
    local params=$@ # additional parameters and options to rsync

    message "synchronizing: `var $input` to $output"
    printf "rsync -haui --delete $params $input $startdir/$output\n"
    sleep $timeout
    rsync -haui --delete $params $input $startdir/$output | tee -a $logfile
    if [[ $? -ne 0 ]]; then
        error "Last command ended with an error."
        if [[ $force -eq 0 ]]; then
            exit 2
        fi
    fi
}

# Use rsync to interactively keep destination synchronized.
# I personally do not like this function; it feels 'dirty'.
function isynch() {
    local output=$1 # output location to sync to
    local input=$2  # input directory
    shift 2
    local params=$@ # additional parameters and options to rsync

    message "Confirm synchronizing: `var $input` to $output..."
    sleep $read_timeout
    rsync -ruin $params $input $startdir/$output | sed -e "1 i FILES TO BE SYNCHRONIZED FROM ${input} TO ${output}:\n\n" | less -F
    if confirm "Are you sure you want to synchronize?"; then
        printf "rsync -rui $params $input $startdir/$output\n"
        sleep $timeout
        rsync -rui $params $input $startdir/$output | tee -a $logfile
        retval=$?

        message "The following has NOT been deleted at destination:"
        sleep $read_timeout
        rsync -ruin --delete $params $input $startdir/$output | sed -e "1 i FILES NOT DELETED FROM ${output}:\n\n" | tee -a $logfile | less

        if [[ $retval -ne 0 ]]; then
            error "Last command ended with an error."
            if [[ $force -eq 0 ]]; then
                exit 2
            fi
        fi
    else
        message "${cRED}Not synchronizing${cWHITE} `var $input` to $output.\n"
    fi
}

# Find the mount point of a filesystem via UUID.
function mountpoint() {
    local result=$1 # variable to store result
    local uuid=$2   # UUID of filesystem

    local mntpt=$(lsblk --output UUID,MOUNTPOINT | grep "$uuid" | sed "s/$uuid\s*//")
    if [[ -z $mntpt || ! -d $mntpt  ]]; then
        error "Cannot find mountpoint for filesystem with UUID $uuid!"
        exit 2
    fi
    eval $result="'$mntpt'"
}


# Requirements must be fulfilled:
#
# NOTE:
#    Make sure that you set the variables if you want to restrict usage to a single host.
#       hostname="hostname"
#    And if you need root access
#       root="required"
#    Or if you just want to allow it
#       root="allowed"
#
if [[ ! -z $host && $(hostname) != "$host" ]]; then
    error "Will only sync from `host $host`!"
    exit 1
elif [[ $(dirname $0) != "." ]]; then
    error "Run $(var `basename $0`) in it's own directory!"
    exit 1
fi

# Check rules concerning root usage
if [ $(id -u) -ne 0 ]; then
    if [[ $root == "required" ]]; then
        error "Need root privileges!"
        exit 1
    fi
else
    if [[ $root != "required" && $root != "allowed" ]]; then
        error "Refuse to run as root!"
        exit 1
    elif [[ $root == "allowed" ]]; then
        info "Warning: Running as root, though not required."
    fi
fi

# Declare variables
startdir=$(pwd)
force=0
if [[ -z $timeout ]]; then
    timeout=3
fi
if [[ -z $read_timeout ]]; then
    read_timeout=2
fi
if [[ -z $logfile ]]; then
    logfile="$startdir/sync.log"
fi
if [[ -z $timefile ]]; then
    timefile="$startdir/sync.time"
fi

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        -f|--force)
            force=1
            shift 1;;
        -t|--timeout)
            timeout=$2
            shift 2;;
        -r|--readtime)
            read_timeout=$2
            shift 2;;
        -l|--logfile)
            logfile=$2
            shift 2;;
        -h|--help)
            echo "synclib version $_version"
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "OPTIONS:"
            echo "  -f --force          force sync to continue after errors"
            echo "  -h --help           show this help message"
            echo "  -l --logfile <file> set logfile to the path given"
            echo "  -r --readtime <sec> set the reading timeout (in seconds) before starting less"
            echo "  -t --timeout <sec>  set timeout (in seconds) to wait before running a command"
            shift 1;;
        *)
            error "Unknown parameter"
            exit 1;;
    esac
done

date > $timefile
printf "\n\n$(date) :: synclib version $_version =====\n" >> $logfile
