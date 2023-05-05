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

