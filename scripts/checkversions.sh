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
	NVOUT=`nvchecker -c "${BASE}/configs/nvchecker.toml" -e "${PACKAGE}" --logger json`
	CHECK_VERSION=`echo "${NVOUT}" | jq -r 'select(.event=="updated") | .version' 2>/dev/null`
	JQ_STATUS=$?
	STATE="UPD"
	if test ${JQ_STATUS} -ne 0 -o "x${CHECK_VERSION}" = "x"; then
		STATE="ERR"
	elif test "x${CHECK_VERSION}" = "x${HAS_VERSION}"; then
		STATE="OK "
	fi
	echo "${STATE} ${PACKAGE} ${HAS_VERSION} ${CHECK_VERSION}"
done

trap - 0

exit 0
