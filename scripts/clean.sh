#!/bin/oksh

SCRIPT=$(readlink -f "$0")
BASE=$(dirname ${SCRIPT})/..

echo "Cleaning up in base directory '$BASE'"

rm -rf "${BASE}/src/stage0"/*
rm -rf "${BASE}/src/stage1"/*
rm -rf "${BASE}/root/stage0"/*
rm -rf "${BASE}/root/stage1"/*
rm -rf "${BASE}/randisk.img"
rm -rf "${BASE}/randisk/"/*
rm -rf "${BASE}"/floppy*
rm -rf "${BASE}/"{data.tar,bzImage,ramdisk.img,EOF}

exit 0

