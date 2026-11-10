#!/bin/oksh

GITWRAP_DIR=""

abort( )
{
	if [ -n "${GITWRAP_DIR}" ]; then
		rm -rf "${GITWRAP_DIR}"
	fi
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

# git.suckless.org and git.2f30.org currently fail every TLS 1.3 handshake;
# this shim resolves nvchecker's git-ls-remote checks against those two
# hosts over TLS 1.2 instead, passing all other git calls straight through
# (see scripts/nvchecker-git-wrapper). nvchecker always invokes the literal
# command name "git", so expose the shim under that name via a throwaway
# tempdir prepended to PATH.
GITWRAP_DIR=`mktemp -d`
ln -s "${BASE}/scripts/nvchecker-git-wrapper" "${GITWRAP_DIR}/git"
PATH="${GITWRAP_DIR}:${PATH}"

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

rm -rf "${GITWRAP_DIR}"

trap - 0

exit 0
