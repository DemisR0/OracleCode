#!/bin/bash
# set | show readahead for a specific mount point
# Useful for things like NFS and if you do not know / care about the backing device
#
# To the extent possible under law, Red Hat, Inc. has dedicated all copyright
# to this software to the public domain worldwide, pursuant to the
# CC0 Public Domain Dedication. This software is distributed without any warranty.
# See <http://creativecommons.org/publicdomain/zero/1.0/>.
#

E_BADARGS=22
function myusage() {
echo "Usage: `basename $0` set|show <mount-point> [read-ahead-kb]"
}

if [ $# -gt 3 -o $# -lt 2 ]; then
   myusage
   exit $E_BADARGS
fi

MNT=${2%/}
BDEV=$(grep $MNT /proc/self/mountinfo | awk '{ print $3 }')

if [ $# -eq 3 -a $1 == "set" ]; then
   echo $3 > /sys/class/bdi/$BDEV/read_ahead_kb
elif [ $# -eq 2 -a $1 == "show" ]; then
   echo "$MNT $BDEV /sys/class/bdi/$BDEV/read_ahead_kb = "$(cat /sys/class/bdi/$BDEV/read_ahead_kb)
else
   myusage
   exit $E_BADARGS
fi
