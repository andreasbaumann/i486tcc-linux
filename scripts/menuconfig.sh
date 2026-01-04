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

SCRIPT=`readlink -f "$0"`
BASE=`dirname ${SCRIPT}`/..

if test ! -x kconfig/mconf; then
	gcc -o kconfig/mconf kconfig/mconf.c kconfig/zconf.tab.c \
		kconfig/lxdialog/*.c -lcurses -DCURSES_LOC="<ncurses.h>" \
		-DKCONFIG_VERSION=1 \
		-DKBUILD_NO_NLS=1 -DPROJECT_NAME=\"i486tcclinux\"
fi
if test ! -x kconfig/conf; then
	gcc -o kconfig/conf kconfig/conf.c kconfig/zconf.tab.c \
		-DKCONFIG_VERSION=1 \
		-DKBUILD_NO_NLS=1 -DPROJECT_NAME=\"i486tcclinux\"
fi

KCONFIG_CONFIG=configs/config \
	kconfig/mconf configs/i486tcc-linux.kconfig

trap - 0

exit 0
 
