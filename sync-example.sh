#!/bin/sh
# sync-example.sh

# This script shows you how you might use synclib.sh to efficiently
# makes backups from a computer onto another medium.

# OPTIONS:
# It is important that these options are specified before sourcing synclib.sh!

# host (required)
# This script will fail to run on any other host then the one specified.
host="mercury"

# root (optional, default=disallowed)
# Possible values for root are: allowed, required, disallowed.
#root="disallowed"

# timeout (optional, default=3)
# Set the timeout (in seconds) given before executing a command.
#timeout=3

# read_timeout (optional, default=2)
# Set the timeout (in seconds) given to allow reading of message before less.
#read_timeout=2

# logfile (optional, default=sync.log)
#logfile="sync.log"

# Include dependancy, which will parse arguments and do some checking.
. synclib.sh

##########################################################################
# SYNC FUNCTIONS AVAILABLE
#
# Following functions are available:
#   synch     $output $input $parameters
#   isynch    $output $input $parameters
#   compress  $output $input
#   ucompress $outupt $input
#
# The following functions color output text
#   info    :: BOLD Green ==> White
#              mostly used by you
#   message :: BOLD Blue  ->  White
#              mostly used by other functions, not you
#   error   :: BOLD Red ==> Error: White
#              also really only for functions
#   var     :: Yellow color for variables
#   group   :: Blue color for a group
#   host    :: Purple color for host
#
##########################################################################

# Start Sync
info "Starting sync from `host $host`..."
message "Timeout is set to $timeout."

info "Syncing from `group home`:"
synch home/benmorgan                /home/benmorgan/    "--exclude-from=benmorgan.exclude --ignore-errors"
synch home/cassava                  /home/cassava/
synch home/virtual                  /home/virtual/

info "Backing up from `group home`:"
ucompress backups/container         /home/benmorgan/personal/.container

info "Syncing from `group root`:"
synch root                          /root/

info "Syncing from `group websites`:"
synch srv                           /srv/

info "Backing up from `group system:`"
ucompress backups/etc.tar.gz         /etc
ucompress backups/mysql.tar.gz       /var/lib/mysql

info "Done syncing from `host $host`."
exit 0
