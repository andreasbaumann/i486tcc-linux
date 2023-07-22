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

ROOT="${BASE}"/root
LOCAL="${BASE}"/local

mountpoint -q "${ROOT}" && sudo umount "${ROOT}"
test -f /dev/loop0 && losetup -d /dev/loop0
test -d "${ROOT}" && rmdir "${ROOT}"
test -f root.img && rm -f root.img

dd if=/dev/zero of=root.img bs=512 count=128520
chmod 666 root.img
losetup /dev/loop0 root.img
mke2fs /dev/loop0
mkdir "${BASE}/root"
sudo mount /dev/loop0 "${BASE}/root"
sudo chmod 777 "${BASE}/root"
sudo rmdir "${BASE}/root/lost+found"

cp -R "${BASE}/build/stage1"/* "${BASE}/root"

# remove cross-compilers
# TODO: they should not be built in the first place
rm -f "${ROOT}"/bin/x86_64*tcc
rm -f "${ROOT}"/bin/tcc
rm -f "${ROOT}"/bin/arm*tcc
rm -f "${ROOT}"/bin/c67*tcc
rm -f "${ROOT}"/bin/riscv64*tcc
rm -f "${ROOT}"/bin/*win32*tcc
rm -rf "${ROOT}"/lib/tcc/x86_64*
rm -rf "${ROOT}"/lib/tcc/arm*
rm -rf "${ROOT}"/lib/tcc/riscv64*
rm -rf "${ROOT}"/lib/tcc/win32
rm -rf "${ROOT}"/lib/tcc/libtcc1.a
rm -rf "${ROOT}"/lib/tcc/bt-*.o
rm -rf "${ROOT}"/lib/tcc/bcheck.o

# remove some unneeded development stuff
rm -rf "${ROOT}"/lib/pkgconfig

# no HTML or info documentation
rm -rf "${ROOT}"/share/info
rm -rf "${ROOT}"/share/doc

# make sure mount points exist
test -d "${ROOT}"/dev || mkdir "${ROOT}"/dev
test -d "${ROOT}"/dev/pts || mkdir "${ROOT}"/dev/pts
test -d "${ROOT}"/proc || mkdir "${ROOT}"/proc
test -d "${ROOT}"/sys || mkdir "${ROOT}"/sys
test -d "${ROOT}"/tmp || mkdir "${ROOT}"/tmp
test -d "${ROOT}"/var || mkdir "${ROOT}"/var
test -d "${ROOT}"/var/run || mkdir "${ROOT}"/var/run
test -d "${ROOT}"/mnt || mkdir "${ROOT}"/mnt

# copy locally adapted scripts
test -d "${ROOT}/root" || mkdir "${ROOT}/root"
cp "${LOCAL}"/root/.profile "${ROOT}/root"
cp "${LOCAL}"/root/.xserverrc "${ROOT}/root"
cp "${LOCAL}"/root/.xinitrc "${ROOT}/root"
test -d "${ROOT}/bin" || mkdir "${ROOT}/bin"
cp -dR "${LOCAL}"/bin/* "${ROOT}/bin"
test -d "${ROOT}/etc" || mkdir "${ROOT}/etc"
cp -dR "${LOCAL}"/etc/* "${ROOT}/etc"
test -d "${ROOT}/share" || mkdir "${ROOT}/share"
cp -dR "${LOCAL}"/share/* "${ROOT}/share"

# copy ramdisk, boot loader and kernel to /boot
cp ramdisk.img "${ROOT}/boot"
cp "${BASE}/build/stage1/boot/bzImage" "${ROOT}/boot"
cp "${BASE}/build/stage1/boot/boot.img" "${ROOT}/boot"

# default passwd is SHA-256 or SHA-512 which can take a minute to verify
# on old machines! We are using unsafe MD5 crypt1, beware of hacks!
HASH=$(openssl passwd -1 -salt '5RPVAd' 'xx')
echo "root:${HASH}:17718::::::" >"${ROOT}/etc/shadow"

du -hs "${BASE}/root"
ls -h root.img

sudo umount "${BASE}/root"
losetup -d /dev/loop0

trap - 0

exit 0
 
