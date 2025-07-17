#!/bin/oksh

SCRIPT=$(readlink -f "$0")
BASE=$(dirname ${SCRIPT})/..

echo "Cleaning up in base directory '$BASE'"

rm -rf "${BASE}/src/stage0"/*
rm -rf "${BASE}/src/stage1"/*
rm -rf "${BASE}/build/stage0"/*
rm -rf "${BASE}/build/stage1"/*
rm -rf "${BASE}/ramdisk.img"
rm -rf "${BASE}/ramdisk"/*
rm -rf "${BASE}/root.img"
rm -rf "${BASE}/root"/*
rm -rf "${BASE}"/floppy*
rm -rf "${BASE}/"{data.tar,bzImage,ramdisk.img,EOF}
rm -rf PAD
rm -f tools/bdftopcf tools/rdev tools/ucs2any

exit 0

