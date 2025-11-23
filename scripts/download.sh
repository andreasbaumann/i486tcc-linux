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

cd "${BASE}/downloads/" || exit 1

if [ ! -f "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz" ]; then
	git clone https://repo.or.cz/tinycc.git "tinycc-${TINYCC_VERSION}"
	git -C "tinycc-${TINYCC_VERSION}" checkout "${TINYCC_VERSION}"
	tar zcf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz" "tinycc-${TINYCC_VERSION}"
	rm -rf "tinycc-${TINYCC_VERSION}"
fi

if [ ! -f "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz" "https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz" "https://github.com/ibara/oksh/releases/download/oksh-${_OKSH_VERSION}/oksh-${_OKSH_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz" ]; then
	git clone git://git.suckless.org/sbase "sbase-${SBASE_VERSION}"
	git -C "sbase-${SBASE_VERSION}" checkout "${SBASE_VERSION}"
	tar zcf "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz" "sbase-${SBASE_VERSION}"
	rm -rf "sbase-${SBASE_VERSION}"
fi

if [ ! -f "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz" ]; then
	git clone git://git.suckless.org/ubase "ubase-${UBASE_VERSION}"
	git -C "ubase-${UBASE_VERSION}" checkout "${UBASE_VERSION}"
	tar zcf "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz" "ubase-${UBASE_VERSION}"
	rm -rf "ubase-${UBASE_VERSION}"
fi

if [ ! -f "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz" ]; then
	git clone git://git.suckless.org/smdev "smdev-${SMDEV_VERSION}"
	git -C "smdev-${SMDEV_VERSION}" checkout "${SMDEV_VERSION}"
	tar zcf "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz" "smdev-${SMDEV_VERSION}"
	rm -rf "smdev-${SMDEV_VERSION}"
fi

if [ ! -f "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz" ]; then
	git clone git://git.suckless.org/sinit "sinit-${SINIT_VERSION}"
	git -C "sinit-${SINIT_VERSION}" checkout "${SINIT_VERSION}"
	tar zcf "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz" "sinit-${SINIT_VERSION}"
	rm -rf "sinit-${SINIT_VERSION}"
fi

if [ ! -f "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz" ]; then
	git clone git://git.2f30.org/sdhcp "sdhcp-${SDHCP_VERSION}"
	git -C "sdhcp-${SDHCP_VERSION}" checkout "${SDHCP_VERSION}"
	tar zcf "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz" "sdhcp-${SDHCP_VERSION}"
	rm -rf "sdhcp-${SDHCP_VERSION}"
fi

if [ ! -f "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz" "https://github.com/sabotage-linux/netbsd-curses/archive/refs/tags/v${NETBSD_NCURSES_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz" "https://www.leonerd.org.uk/code/libtermkey/libtermkey-${LIBTERMKEY_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz" ]; then
	wget "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz" ]; then
	git clone https://github.com/martanne/vis.git "vis-${VIS_VERSION}"
	git -C "vis-${VIS_VERSION}" checkout "${VIS_VERSION}"
	tar zcf "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz" "vis-${VIS_VERSION}"
	rm -rf "vis-${VIS_VERSION}"
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
	git clone git://git.andreasbaumann.cc/abase.git "abase-${ABASE_VERSION}"
	git -C "abase-${ABASE_VERSION}" checkout "${ABASE_VERSION}"
	tar zcf "${BASE}/downloads/abase-${ABASE_VERSION}.tar.gz" "abase-${ABASE_VERSION}"
	rm -rf "abase-${ABASE_VERSION}"
fi

if [ ! -f "${BASE}/downloads/nbd-${NBD_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/nbd-${NBD_VERSION}.tar.gz" "https://github.com/NetworkBlockDevice/nbd/releases/download/nbd-${NBD_VERSION}/nbd-${NBD_VERSION}.tar.xz"
fi

if [ ! -f "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" "https://github.com/michaelforney/samurai/releases/download/${SAMURAI_VERSION}/samurai-${SAMURAI_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/muon-${MUON_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/muon-${MUON_VERSION}.tar.gz" "https://github.com/muon-build/muon/archive/refs/tags/${MUON_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz" "https://github.com/michaelforney/samurai/releases/download/${SAMURAI_VERSION}/samurai-${SAMURAI_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/joe-${JOE_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/joe-${JOE_VERSION}.tar.gz" "https://netcologne.dl.sourceforge.net/project/joe-editor/JOE%20sources/joe-${JOE_VERSION}/joe-${JOE_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/tinyxlib-${TINYXLIB_VERSION}.tar.gz" ]; then
	git clone https://github.com/idunham/tinyxlib.git "tinyxlib-${TINYXLIB_VERSION}"
	git -C "tinyxlib-${TINYXLIB_VERSION}" checkout "${TINYXLIB_VERSION}"
	tar zcf "${BASE}/downloads/tinyxlib-${TINYXLIB_VERSION}.tar.gz" "tinyxlib-${TINYXLIB_VERSION}"
	rm -rf "tinyxlib-${TINYXLIB_VERSION}"
fi

if [ ! -f "${BASE}/downloads/tinyxserver-${TINYXSERVER_VERSION}.tar.gz" ]; then
	git clone https://github.com/idunham/tinyxserver.git "tinyxserver-${TINYXSERVER_VERSION}"
	git -C "tinyxserver-${TINYXSERVER_VERSION}" checkout "${TINYXSERVER_VERSION}"
	tar zcf "${BASE}/downloads/tinyxserver-${TINYXSERVER_VERSION}.tar.gz" "tinyxserver-${TINYXSERVER_VERSION}"
	rm -rf "tinyxserver-${TINYXSERVER_VERSION}"
fi

if [ ! -f "${BASE}/downloads/rxvt-${RXVT_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/rxvt-${RXVT_VERSION}.tar.gz" \
		"https://sourceforge.net/projects/rxvt/files/rxvt/${RXVT_VERSION}/rxvt-${RXVT_VERSION}.tar.gz/download"
fi

if [ ! -f "${BASE}/downloads/xhost-${XHOST_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/xhost-${XHOST_VERSION}.tar.gz" \
		"https://www.x.org/archive/individual/app/xhost-${XHOST_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/xauth-${XAUTH_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/xauth-${XAUTH_VERSION}.tar.gz" \
		"https://www.x.org/archive/individual/app/xauth-${XAUTH_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/meh-${MEH_VERSION}.tar.gz" ]; then
	git clone https://github.com/andreasbaumann/meh.git "meh-${MEH_VERSION}"
	git -C "meh-${MEH_VERSION}" checkout "${MEH_VERSION}"
	tar zcf "${BASE}/downloads/meh-${MEH_VERSION}.tar.gz" "meh-${MEH_VERSION}"
	rm -rf "meh-${MEH_VERSION}"
fi

if [ ! -f "${BASE}/downloads/slock-${SLOCK_VERSION}.tar.gz" ]; then
	git clone git://git.suckless.org/slock "slock-${SLOCK_VERSION}"
	git -C "slock-${SLOCK_VERSION}" checkout "${SLOCK_VERSION}"
	tar zcf "${BASE}/downloads/slock-${SLOCK_VERSION}.tar.gz" "slock-${SLOCK_VERSION}"
	rm -rf "slock-${SLOCK_VERSION}"
fi

if [ ! -f "${BASE}/downloads/bdftopcf-${BDFTOPCF_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/bdftopcf-${BDFTOPCF_VERSION}.tar.gz" \
		"https://xorg.freedesktop.org/archive/individual/util/bdftopcf-${BDFTOPCF_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/font-cursor-misc-${FONT_CURSOR_MISC_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/font-cursor-misc-${FONT_CURSOR_MISC_VERSION}.tar.gz" \
		"https://www.x.org/archive/individual/font/font-cursor-misc-${FONT_CURSOR_MISC_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/font-misc-misc-${FONT_MISC_MISC_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/font-misc-misc-${FONT_MISC_MISC_VERSION}.tar.gz" \
		"https://www.x.org/archive/individual/font/font-misc-misc-${FONT_MISC_MISC_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/font-util-${FONT_UTIL_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/font-util-${FONT_UTIL_VERSION}.tar.gz" \
		"https://www.x.org/archive/individual/font/font-util-${FONT_UTIL_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/lua-${LUA_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/lua-${LUA_VERSION}.tar.gz" \
		"https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/notion-${NOTION_VERSION}.tar.gz" ]; then
	git clone https://github.com/raboof/notion.git "notion-${NOTION_VERSION}"
	git -C "notion-${NOTION_VERSION}" checkout "${NOTION_VERSION}"
	tar zcf "${BASE}/downloads/notion-${NOTION_VERSION}.tar.gz" "notion-${NOTION_VERSION}"
	rm -rf "notion-${NOTION_VERSION}"
fi

if [ ! -f "${BASE}/downloads/wordgrinder-${WORDGRINDER_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/wordgrinder-${WORDGRINDER_VERSION}.tar.gz" \
		"https://github.com/davidgiven/wordgrinder/archive/refs/tags/${WORDGRINDER_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/sc-${SC_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/sc-${SC_VERSION}.tar.gz" \
		"https://github.com/n-t-roff/sc/archive/refs/tags/${SC_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz" ]; then
	git clone git://git.andreasbaumann.cc/uflbbl.git "uflbbl-${UFLBBL_VERSION}"
	git -C "uflbbl-${UFLBBL_VERSION}" checkout "${UFLBBL_VERSION}"
	tar zcf "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz" "uflbbl-${UFLBBL_VERSION}"
	rm -rf "uflbbl-${UFLBBL_VERSION}"
fi

if [ ! -f "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${LINUX_KERNEL_VERSION}.tar.gz"
fi

if [ ! -f "${BASE}/downloads/dropbear-${DROPBEAR_VERSION}.tar.bz2" ]; then
	wget -O "${BASE}/downloads/dropbear-${DROPBEAR_VERSION}.tar.bz2" "https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"
fi

if [ ! -f "${BASE}/downloads/mutt-${MUTT_VERSION}.tar.gz" ]; then
	git clone https://gitlab.com/muttmua/mutt "mutt-${MUTT_VERSION}"
	MUTT_TAG_VERSION=`echo "${MUTT_VERSION}" | tr '.' '-'`
	git -C "mutt-${MUTT_VERSION}" checkout "mutt-${MUTT_TAG_VERSION}-rel"
	tar zcf "${BASE}/downloads/mutt-${MUTT_VERSION}.tar.gz" "mutt-${MUTT_VERSION}"
	rm -rf "mutt-${MUTT_VERSION}"
fi

if [ ! -f "${BASE}/downloads/fbset-${FBSET_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/fbset-${FBSET_VERSION}.tar.gz" "https://src.fedoraproject.org/repo/pkgs/fbset/fbset-2.1.tar.gz/e547cfcbb8c1a4f2a6b8ba4acb8b7164/fbset-2.1.tar.gz"
fi

if [ ! -f "${BASE}/downloads/lbforth-${LBFORTH_VERSION}.tar.gz" ]; then
	git clone https://github.com/DosWorld/lbforth.git "lbforth-${LBFORTH_VERSION}"
	git -C "lbforth-${LBFORTH_VERSION}" checkout "${LBFORTH_VERSION}"
	tar zcf "${BASE}/downloads/lbforth-${LBFORTH_VERSION}.tar.gz" "lbforth-${LBFORTH_VERSION}"
	rm -rf "lbforth-${LBFORTH_VERSION}"
fi

if [ ! -f "${BASE}/downloads/sqlite-${SQLITE_VERSION}.zip" ]; then
	MAJOR_SQLITE_VERSION=`echo "${SQLITE_VERSION}" | cut -d . -f 1`
	MINOR_SQLITE_VERSION=`echo "${SQLITE_VERSION}" | cut -d . -f 2`
	PATCH_SQLITE_VERSION=`echo "${SQLITE_VERSION}" | cut -d . -f 3`
	_SQLITE_VERSION=`expr ${MAJOR_SQLITE_VERSION} \* 1000000 + ${MINOR_SQLITE_VERSION} \* 10000 + ${PATCH_SQLITE_VERSION}`
	wget -O "${BASE}/downloads/sqlite-${SQLITE_VERSION}.zip" "https://www.sqlite.org/2025/sqlite-src-${_SQLITE_VERSION}.zip"
fi

cd .. || exit 1

trap - 0

exit 0
