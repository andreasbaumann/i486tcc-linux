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

. "${BASE}/configs/versions"

echo "Downloading software to '$BASE'/downloads"

if [ ! -f "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone https://repo.or.cz/tinycc.git "tinycc-${TINYCC_VERSION}"
	git -C "tinycc-${TINYCC_VERSION}" checkout "${TINYCC_VERSION}"
	tar zcf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz" "tinycc-${TINYCC_VERSION}"
	rm -rf "tinycc-${TINYCC_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz" "https://musl.libc.org/releases/musl-1.2.3.tar.gz"
fi

if [ ! -f "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz" "https://github.com/ibara/oksh/releases/download/oksh-${_OKSH_VERSION}/oksh-${_OKSH_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.suckless.org/sbase "sbase-${SBASE_VERSION}"
	git -C "sbase-${SBASE_VERSION}" checkout "${SBASE_VERSION}"
	tar zcf "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz" "sbase-${SBASE_VERSION}"
	rm -rf "sbase-${SBASE_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.suckless.org/ubase "ubase-${UBASE_VERSION}"
	git -C "ubase-${UBASE_VERSION}" checkout "${UBASE_VERSION}"
	tar zcf "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz" "ubase-${UBASE_VERSION}"
	rm -rf "ubase-${UBASE_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.suckless.org/smdev "smdev-${SMDEV_VERSION}"
	git -C "smdev-${SMDEV_VERSION}" checkout "${SMDEV_VERSION}"
	tar zcf "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz" "smdev-${SMDEV_VERSION}"
	rm -rf "smdev-${SMDEV_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.suckless.org/sinit "sinit-${SINIT_VERSION}"
	git -C "sinit-${SINIT_VERSION}" checkout "${SINIT_VERSION}"
	tar zcf "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz" "sinit-${SINIT_VERSION}"
	rm -rf "sinit-${SINIT_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.2f30.org/sdhcp "sdhcp-${SDHCP_VERSION}"
	git -C "sdhcp-${SDHCP_VERSION}" checkout "${SDHCP_VERSION}"
	tar zcf "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz" "sdhcp-${SDHCP_VERSION}"
	rm -rf "sdhcp-${SDHCP_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz" "https://github.com/sabotage-linux/netbsd-curses/archive/refs/tags/v${NETBSD_NCURSES_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz" "https://www.leonerd.org.uk/code/libtermkey/libtermkey-${LIBTERMKEY_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	wget "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
	cd ..
fi

if [ ! -f "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone https://github.com/martanne/vis.git "vis-${VIS_VERSION}"
	git -C "vis-${VIS_VERSION}" checkout "${VIS_VERSION}"
	tar zcf "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz" "vis-${VIS_VERSION}"
	rm -rf "vis-${VIS_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/tmux-${TMUX_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/tmux-${TMUX_VERSION}.tar.gz" "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/zlib-${ZLIB_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/zlib-${ZLIB_VERSION}.tar.gz" "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"

fi

if [ ! -f "${BASE}/downloads/mandoc-${MANDOC_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/mandoc-${MANDOC_VERSION}.tar.gz" "https://mdocml.bsd.lv/snapshots/mandoc-${MANDOC_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/abase-${ABASE_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.andreasbaumann.cc/abase.git "abase-${ABASE_VERSION}"
	git -C "abase-${ABASE_VERSION}" checkout "${ABASE_VERSION}"
	tar zcf "${BASE}/downloads/abase-${ABASE_VERSION}.tar.gz" "abase-${ABASE_VERSION}"
	rm -rf "abase-${ABASE_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/nbd-${NBD_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/nbd-${NBD_VERSION}.tar.gz" "https://github.com/NetworkBlockDevice/nbd/releases/download/nbd-${NBD_VERSION}/nbd-${NBD_VERSION}.tar.xz"
fi

if [ ! -f "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" "https://github.com/michaelforney/samurai/releases/download/${SAMURAI_VERSION}/samurai-${SAMURAI_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" "https://github.com/michaelforney/samurai/releases/download/${SAMURAI_VERSION}/samurai-${SAMURAI_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/joe-${JOE_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/joe-${JOE_VERSION}.tar.gz" "https://netcologne.dl.sourceforge.net/project/joe-editor/JOE%20sources/joe-${JOE_VERSION}/joe-${JOE_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.andreasbaumann.cc/uflbbl.git "uflbbl-${UFLBBL_VERSION}"
	git -C "uflbbl-${UFLBBL_VERSION}" checkout "${UFLBBL_VERSION}"
	tar zcf "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz" "uflbbl-${UFLBBL_VERSION}"
	rm -rf "uflbbl-${UFLBBL_VERSION}"
	cd ..
fi

if [ ! -f "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${LINUX_KERNEL_VERSION}.tar.gz"
fi

trap - 0

exit 0
