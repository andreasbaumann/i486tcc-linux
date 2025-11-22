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

#set -e

SCRIPT=`readlink -f "$0"`
BASE=`dirname ${SCRIPT}`/..

for line in `cat "${BASE}/configs/versions"`; do
	PACKAGE=`echo $line | cut -f 1 -d = | sed -s 's/_VERSION$//'`
	HAS_VERSION=`echo $line | cut -f 2 -d = | tr -d '"'`
	CHECK_VERSION=`nvchecker -c "${BASE}/configs/nvchecker.toml" -e "${PACKAGE}" --logger json | jq -r 'select(.event=="updated") | .version'`
	STATE="UPD"
	if test "x${CHECK_VERSION}" = "x${HAS_VERSION}"; then
		STATE="OK "
	fi
	echo "${STATE} ${PACKAGE} ${HAS_VERSION} ${CHECK_VERSION}"
done

trap - 0

exit 0
