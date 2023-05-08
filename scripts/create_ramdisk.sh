#!/bin/oksh

abort( )
{
	echo >&2 '
***************
*** ABORTED ***
***************
'
	echo "An error occurred. Exiting..." >&2
	exit 1
}

trap 'abort' 0

set -e

SCRIPT=$(readlink -f "$0")
BASE=$(dirname ${SCRIPT})/..

RAMDISK="${BASE}"/ramdisk
LOCAL="${BASE}"/local

rm -rf "${RAMDISK}"
mkdir "${RAMDISK}"

# the ramdisk init script
cp "${BASE}"/local/init "${RAMDISK}"

# the kernel modules
mkdir "${RAMDISK}/lib"
cp -R "${BASE}/build/stage1/lib/modules" "${RAMDISK}/lib"

# make sure mount points exist
test -d "${RAMDISK}"/dev || mkdir "${RAMDISK}"/dev
test -d "${RAMDISK}"/dev/pts || mkdir "${RAMDISK}"/dev/pts
test -d "${RAMDISK}"/proc || mkdir "${RAMDISK}"/proc
test -d "${RAMDISK}"/sys || mkdir "${RAMDISK}"/sys
#~ test -d "${RAMDISK}"/tmp || mkdir "${RAMDISK}"/tmp
#~ test -d "${RAMDISK}"/var || mkdir "${RAMDISK}"/var
#~ test -d "${RAMDISK}"/var/run || mkdir "${RAMDISK}"/var/run

# just copy the stuff needed by '/init'
test -d "${RAMDISK}/bin" || mkdir "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/oksh "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/sh "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/ubase-box "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/mount "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/insmod "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/switch_root "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/sbase-box "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/mkdir "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/sdhcp "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/abase-box "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/ifconfig "${RAMDISK}/bin"
cp -dR "${BASE}/build/stage1"/bin/nbd-client "${RAMDISK}/bin"

# mount calls setmntent which want to write to '/etc/fstab'?
test -d "${RAMDISK}/etc" || mkdir "${RAMDISK}/etc"
cp "${BASE}/local"/etc/fstab "${RAMDISK}/etc"

# package ramdisk directory with cpio and compress it with xz
cd "${RAMDISK}"
find . | cpio -H newc -o -R root:root | xz --check=crc32 > ../ramdisk.img
cd ..

du -hs "${BASE}/ramdisk"
ls -h ramdisk.img

trap - 0

exit 0
 
