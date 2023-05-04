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

rm -rf "${BASE}/ramdisk"
cp -R "${BASE}/root/stage1" "${BASE}/ramdisk"

# remove cross-compilers
# TODO: they should not be built in the first place
rm -f "${RAMDISK}"/bin/x86_64*tcc
rm -f "${RAMDISK}"/bin/tcc
rm -f "${RAMDISK}"/bin/arm*tcc
rm -f "${RAMDISK}"/bin/c67*tcc
rm -f "${RAMDISK}"/bin/riscv64*tcc
rm -f "${RAMDISK}"/bin/*win32*tcc
rm -rf "${RAMDISK}"/lib/tcc/x86_64*
rm -rf "${RAMDISK}"/lib/tcc/arm*
rm -rf "${RAMDISK}"/lib/tcc/riscv64*
rm -rf "${RAMDISK}"/lib/tcc/win32
rm -rf "${RAMDISK}"/lib/tcc/libtcc1.a
rm -rf "${RAMDISK}"/lib/tcc/bt-*.o
rm -rf "${RAMDISK}"/lib/tcc/bcheck.o

# remove the kernel and the /boot directory
rm -rf "${RAMDISK}"/boot

# remove some unneeded development stuff
rm -rf "${RAMDISK}"/lib/pkgconfig

# no HTML or info documentation
rm -rf "${RAMDISK}"/share/info
rm -rf "${RAMDISK}"/share/doc

# make sure mount points exist
test -d "${RAMDISK}"/dev || mkdir "${RAMDISK}"/dev
test -d "${RAMDISK}"/dev/pts || mkdir "${RAMDISK}"/dev/pts
test -d "${RAMDISK}"/proc || mkdir "${RAMDISK}"/proc
test -d "${RAMDISK}"/sys || mkdir "${RAMDISK}"/sys
test -d "${RAMDISK}"/tmp || mkdir "${RAMDISK}"/tmp
test -d "${RAMDISK}"/var || mkdir "${RAMDISK}"/var
test -d "${RAMDISK}"/var/run || mkdir "${RAMDISK}"/var/run

# copy locally adapted scripts
test -d "${RAMDISK}/root" || mkdir "${RAMDISK}/root"
cp "${LOCAL}"/root/.profile "${RAMDISK}/root"
test -d "${RAMDISK}/bin" || mkdir "${RAMDISK}/bin"
cp -dR "${LOCAL}"/bin/* "${RAMDISK}/bin"
test -d "${RAMDISK}/etc" || mkdir "${RAMDISK}/etc"
cp -dR "${LOCAL}"/etc/* "${RAMDISK}/etc"

# default passwd is SHA-256 or SHA-512 which can take a minute to verify
# on old machines! We are using unsafe MD5 crypt1, beware of hacks!
HASH=$(openssl passwd -1 -salt '5RPVAd' 'xx')
echo "root:${HASH}:17718::::::" >"${RAMDISK}/etc/shadow"

# package ramdisk directory with cpio and compress it with xz
cd "${RAMDISK}"
find . | cpio -H newc -o -R root:root | xz --check=crc32 > ../ramdisk.img
cd ..

du -hs "${BASE}/ramdisk"
ls -h ramdisk.img

trap - 0

exit 0
 
