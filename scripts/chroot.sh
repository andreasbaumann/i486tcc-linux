#!/bin/oksh

ROOT="$1"
if [ "${ROOT}" = "" ]; then
    echo "No chroot directory specified"
    exit 1
fi

trap "umount ${ROOT}/{dev/pts,dev,proc,sys,tmp}" EXIT

test -d "${ROOT}"/dev || mkdir "${ROOT}"/dev
test -d "${ROOT}"/dev/pts || mkdir "${ROOT}"/dev/pts
test -d "${ROOT}"/proc || mkdir "${ROOT}"/proc
test -d "${ROOT}"/sys || mkdir "${ROOT}"/sys
test -d "${ROOT}"/tmp || mkdir "${ROOT}"/tmp
mount -t devtmpfs udev -o mode=0755,nosuid "${ROOT}"/dev
mount -t devpts devpts -o mode=0620,gid=5,nosuid,noexec "${ROOT}"/dev/pts
mount -t proc proc -o nosuid,noexec,nodev "${ROOT}"/proc
mount -t sysfs sys -o nosuid,noexec,nodev,ro "${ROOT}"/sys
mount -t tmpfs tmp -o nosuid,noexec,nodev,mode=775,size=2M "${ROOT}"/tmp

linux32 chroot "${ROOT}" /bin/env -i PATH=/bin MANPATH=/share/man PS1='chroot# ' TERM="${TERM}" /bin/sh 
