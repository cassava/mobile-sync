mobile-sync
===========

**mobile-sync** is your backup system: lightweight, flexible, and powerful.
It consists of a shell script which uses various core binaries to facilitate
setting up a backup system, and in general it lives on the backup system,
hence the mobile prefix.

Conceptually, here's how it works:

 1. You define your what your *master* data is, and what should *mirror* your
    master.
 2. The mobile-sync script lives on the backup system, and consists of:
        `synclib.sh`, which is a group of helper functions, and
        `sync.sh`, which is your backup procedure definition.
 3. Whenever you want to back up, you run the `sync.sh` script.

## Examples
I like to have all my files backed up at least once.
But I don't have enough space on my hard drive to afford having a single master
for all my data. This is not a problem at all though.

The scheme of what is master and what is mirror is defined entirely on the
backup. Think of it as the backup being responsible for pulling the data,
rather than the master being responsible for pushing the data.

I have two external harddrives, let's call them *personal* and *media*.
The personal harddrive is encrypted and is formatted with the btrfs filesystem.
The media harddrive is not encrypted and is formatted with the NTFS filesystem.

### Example 1
On the personal harddrive (encrypted, btrfs), I have a folder structure like this:

    archives/
    backups/
    cloned/
    mirror/
    snapshots/
    sync.sh
    sync.time
    .synclib.sh

Because I want to take advantage of btrfs, I want to make snapshots of my
most important data. That is not everything though, so I make a snapshot only
of `mirror/`. The `cloned/` folder has some backups, but they are not
snapshotted. The `backups/` folder contains compressed backups. And finally,
the `archives/` folder is a master data source of some of my archived files.

This then, is how `sync.sh` looks like:

    #!/bin/sh

    # To help prevent screwing up data, I can restrict this script to only
    # run on a machine that has the hostname "atlas".
    host="atlas"

    # Normally, running as root is disallowed; however, in my case I need it
    # so I can mirror /root and /etc.
    root="required"

    # I like to have 3 seconds to see what is about to be run before it runs.
    timeout=3

    # If I set this, sync.log will contain a log of everything that happened.
    #logfile="sync.log"

    # This file contains the timestamp of the last time I ran sync.sh.
    timefile="sync.time"

    # Now that I have specified all the options, I can include the synclib.sh
    # library, which will parse arguments and do some checking (like hostname).
    . ./.synclib.sh

    ##########################################################################
    # SYNC FUNCTIONS AVAILABLE
    # See the library for more information.
    #
    # Following functions are available:
    #   synch       $output $input $parameters
    #   isynch      $output $input $parameters
    #   compress    $output $input
    #   ucompress   $output $input
    #   mountpoint  $result $uuid
    #
    # The following functions color output text
    #   info    :: BOLD Green ==> White
    #              mostly used by you
    #   message :: BOLD Blue -> White
    #              mostly used by other functions, not you
    #   error   :: BOLD Red ==> Error: White
    #              also really only for functions
    #   var     :: Yellow color for variables
    #   group   :: Blue color for a group
    #   host    :: Purple color for host
    #
    ##########################################################################

    # This is cool: it means that my master can be on an external drive,
    # and I can find its mountpoint. If I can't find it, then autofail. ;-)
    # In this case, it's not quite necessary, because I know we're on atlas,
    # I could have just forgone it completely and used /home.
    mountpoint home 1f04aca3-0c2f-47b9-bd76-194c8df55927
    info "HOME directory is mounted to $home"

    # Start Sync
    info "Starting sync from `host $host`..."
    message "Timeout is set to $timeout."

    info "Syncing from `group home`:"
    synch home/benmorgan                $home/benmorgan/    "--exclude-from=cassava.exclude --ignore-errors"
    synch home/virtual                  $home/virtual/

    info "Syncing from `group root`:"
    synch cloned/root                   /root/

    info "Syncing from `group websites`:"
    synch cloned/srv                    /srv/

    info "Backing up from `group system:`"
    ucompress backups/etc.tar.gz        /etc
    ucompress backups/mysql.tar.gz      /var/lib/mysql

    info "Creating snapshot `var $(date +"%Y-%m-%d")`..."
    btrfs subvolume snapshot -r mirror snapshots/$(date +"%Y-%m-%d")

    info "Done syncing from `host $host`."
    exit 0

Not too hard. You will want to read through the library to see what the
different functions do.

### Example 2
Coming soon...
