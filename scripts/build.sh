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

CPUS=$(nproc)
#CPUS=1

. "${BASE}/configs/config"
. "${BASE}/configs/versions"

${BASE}/scripts/download.sh

echo "Building in base directory '$BASE'"

# stage 0
#########

cd "${BASE}/src/stage0" || exit 1

# stage 0 host, build a 64-bit cross-compiler for i386, the host might
# not have a packaged tcc at all or one not built for cross-compilation
# TODO: we get a little bit too many cross compilers, but currently
# we cannot easily build just the ones we want.

if [ ! -x "${BASE}/build/stage0/bin/i386-tcc" ]; then
	rm -rf "tinycc-${TINYCC_VERSION}"
	tar xf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz"
	cd "tinycc-${TINYCC_VERSION}" || exit 1
	patch -Np1 < "${BASE}/patches/tcc-asm.patch"
	./configure --enable-static --prefix="${BASE}/build/stage0" \
		--config-musl --enable-cross
	make -j$CPUS
	make -j$CPUS install
	cd .. || exit 1
else
	echo "stage0 tcc-i386 binary exists"
fi

# build a first C library which is used to build the stage 1 tcc
# against, and of course stage 0

if [ ! -f "${BASE}/build/stage0/lib/libc.a" ]; then
	rm -rf "musl-${MUSL_VERSION}"
	tar xf "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz"
	cd "musl-${MUSL_VERSION}" || exit 1
	patch -Np1 < "${BASE}/patches/musl-iconv-euc-kr.patch"
	patch -Np1 < "${BASE}/patches/musl-iconv-input-decoder.patch"
	patch -Np1 < "${BASE}/patches/musl-tcc.patch"
	CC="${BASE}/build/stage0/bin/i386-tcc" ./configure \
		--prefix="${BASE}/build/stage0" \
		--target=i386-linux-musl --disable-shared
	make -j$CPUS AR="${BASE}/build/stage0/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install
	cd .. || exit 1
else
	echo "stage0 musl C library exists"
fi


# build tcc with tcc from stage1 against musl from stage0, it should
# have no dependencies on the host anymore

cd "${BASE}/src/stage1" || exit 1

if [ ! -x "${BASE}/build/stage1/bin/i386-tcc" ]; then
	rm -rf "tinycc-${TINYCC_VERSION}"
	tar xf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz"
	cd "tinycc-${TINYCC_VERSION}" || exit 1
	patch -Np1 < "${BASE}/patches/tcc-asm.patch"
	patch -Np1 < "${BASE}/patches/tcc-stage1.patch"
	sed -i "s|@@BASE@@|${BASE}|g" Makefile configure config-extra.mak
	sed -i "s|@@TINYCC_VERSION@@|${TINYCC_VERSION}|g" Makefile configure config-extra.mak
	./configure --enable-static --prefix="${BASE}/build/stage1" \
		--cc="${BASE}/build/stage0/bin/i386-tcc" --config-musl \
		--ar="${BASE}/build/stage0/bin/i386-tcc -ar" \
		--enable-cross
	make -j$CPUS
	make -j$CPUS install
	ln -fs tcc/i386-libtcc1.a "${BASE}/build/stage1/lib/."
	cd .. || exit 1
else
	echo "stage1 tcc-i386 binary exists"
fi

# stage 1
#########

# rebuild musl with tcc from stage1

if [ ! -f "${BASE}/build/stage1/lib/libc.a" ]; then
	rm -rf "musl-${MUSL_VERSION}"
	tar xf "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz"
	cd "musl-${MUSL_VERSION}" || exit 1
	patch -Np1 < "${BASE}/patches/musl-tcc.patch"
	CC="${BASE}/build/stage1/bin/i386-tcc" ARCH=i386 \
	./configure \
		--prefix="${BASE}/build/stage1" \
		--target=i386-linux-musl --disable-shared
	make -j$CPUS AR="${BASE}/build/stage1/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install
	cd .. || exit 1
else
	echo "stage1 musl C library exists"
fi

# install kernel headers (we don't think musl does any trickery to
# them or depends on them being installed)

if [ ! -d "${BASE}/build/stage1/include/linux" ]; then
	rm -rf "linux-${LINUX_KERNEL_VERSION}"
	tar xf "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz"
	cd "linux-${LINUX_KERNEL_VERSION}" || exit 1
	CC=false make -j$CPUS ARCH=x86 INSTALL_HDR_PATH="${BASE}/build/stage1" headers_install
	cd .. || exit 1
else
	echo "stage1 kernel headers exist"
fi

# test if the stage 1 compiler is working

if [ ! -x "${BASE}/build/stage1/bin/test-stage1" ]; then
	${BASE}/build/stage1/bin/i386-tcc -static \
		-o "${BASE}/build/stage1/bin/test-stage1" "${BASE}/tests/test-stage1.c"
	"${BASE}/build/stage1/bin/test-stage1"
	# TODO: check output, make sure we get the right thing
else
	echo "Reached working stage 1 compiler"
fi

# Now we build the rest of stage 1

if [ "x${CONFIG_OKSH}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/oksh" ]; then
		rm -rf "oksh-${_OKSH_VERSION}"
		tar xf "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz"
		cd "oksh-${_OKSH_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure \
			--prefix="${BASE}/build/stage1" \
			--disable-shared --enable-static
		make -j$CPUS LDFLAGS=-static
		make -j$CPUS install
		ln -s oksh "${BASE}/build/stage1/bin/sh"
		cd .. || exit 1
	else
		echo "stage1 oksh exists"
	fi
fi

if [ "x${CONFIG_SBASE}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/sbase-box" ]; then
		rm -rf "sbase-${SBASE_VERSION}"
		tar xf "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz"
		cd "sbase-${SBASE_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/sbase-mkproto-misc-dir.patch"
		make -j$CPUS sbase-box CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
		make -j$CPUS sbase-box-install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 sbase exists"
	fi
fi

if [ "x${CONFIG_UBASE}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/ubase-box" ]; then
		rm -rf "ubase-${UBASE_VERSION}"
		tar xf "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz"
		cd "ubase-${UBASE_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/ubase-sysmacros.patch"
		make -j$CPUS ubase-box CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
		make -j$CPUS ubase-box-install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 ubase exists"
	fi
fi

if [ "x${CONFIG_SMDEV}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/smdev" ]; then
		rm -rf "smdev-${SMDEV_VERSION}"
		tar xf "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz"
		cd "smdev-${SMDEV_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/smdev-sysmacros.patch"
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
		make -j$CPUS install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 smdev exists"
	fi
fi

if [ "x${CONFIG_SINIT}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/sinit" ]; then
		rm -rf "sinit-${SINIT_VERSION}"
		tar xf "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz"
		cd "sinit-${SINIT_VERSION}" || exit 1
		cp "${BASE}/configs/sinit-config.h" config.h
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
		make -j$CPUS install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 smdev exists"
	fi
fi

if [ "x${CONFIG_SDHCP}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/sdhcp" ]; then
		rm -rf "sdhcp-${SDHCP_VERSION}"
		tar xf "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz"
		cd "sdhcp-${SDHCP_VERSION}" || exit 1
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
		make -j$CPUS install PREFIX="${BASE}/build/stage1"
		mv "${BASE}/build/stage1/sbin/sdhcp" "${BASE}/build/stage1/bin"
		rmdir "${BASE}/build/stage1/sbin"
		cd .. || exit 1
	else
		echo "stage1 sdhcp exists"
	fi
fi

# for vis, joe, sc
if [ "x${CONFIG_NETBSD_NCURSES}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/lib/libncurses.a" ]; then
		rm -rf "netbsd-curses-${NETBSD_NCURSES_VERSION}"
		tar xf "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz"
		cd "netbsd-curses-${NETBSD_NCURSES_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/netbsd-curses-attributes.patch"
		cd "nbperf" || exit 1
		make nbperf
		cd .. || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS='-static' make -j$CPUS all-static
		CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS='-static' make -j$CPUS install-static \
			PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 netbsd-curses exists"
	fi
fi

# for vis
if [ "x${CONFIG_LIBTERMKEY}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/lib/libtermkey.a" ]; then
		rm -rf "libtermkey-${LIBTERMKEY_VERSION}"
		tar xf "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz"
		cd "libtermkey-${LIBTERMKEY_VERSION}" || exit 1
		"${BASE}/build/stage1/bin/i386-tcc" -c termkey.c
		"${BASE}/build/stage1/bin/i386-tcc" -c driver-ti.c
		"${BASE}/build/stage1/bin/i386-tcc" -c driver-csi.c
		"${BASE}/build/stage1/bin/i386-tcc" -ar libtermkey.a termkey.o driver-ti.o driver-csi.o
		cp libtermkey.a "${BASE}/build/stage1/lib"
		cp termkey.h "${BASE}/build/stage1/include"
		cd .. || exit 1
	else
		echo "stage1 libtermkey exists"
	fi
fi

# for vi, kilo, tmux
if [ "x${CONFIG_LIBEVENT}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/lib/libevent.a" ]; then
		rm -rf "libevent-${LIBEVENT_VERSION}"
		tar xf "${BASE}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz"
		cd "libevent-${LIBEVENT_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--enable-static --disable-shared --disable-openssl \
			 --host="i386-linux-musl"		
		make -j$CPUS
		make -j$CPUS install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 libevent exists"
	fi
fi

if [ "x${CONFIG_VIS}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/vi" ]; then
		rm -rf "vis-${VIS_VERSION}"
		tar xf "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz"
		cd "vis-${VIS_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/vis-no-pkgconfig-for-ncurses.patch"
		LDFLAGS=-L"${BASE}/build/stage1/lib" \
		CFLAGS=-I"${BASE}/build/stage1/include" \
		CC="${BASE}/build/stage1/bin/i386-tcc"  \
		./configure --prefix="${BASE}/build/stage1" \
			--disable-lua
		make -j$CPUS LDFLAGS=-static
		cp vis "${BASE}/build/stage1/bin/vi"
		cd .. || exit 1
	else
		echo "stage1 vis exists"
	fi
fi

if [ "x${CONFIG_KILO}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/kilo" ]; then
		rm -rf "kilo-${KILO_VERSION}"
		tar xf "${BASE}/downloads/kilo-${KILO_VERSION}.tar.gz"
		cd "kilo-${KILO_VERSION}" || exit 1
		"${BASE}/build/stage1/bin/i386-tcc" \
			-o kilo kilo.c -static -Wall -W -pedantic -std=c99 \
			-I"${BASE}/build/stage1/include" \
			-L"${BASE}/build/stage1/lib"		
		cp kilo "${BASE}/build/stage1/bin/kilo"
		cd .. || exit 1
	else
		echo "stage1 kilo exists"
	fi
fi

if [ "x${CONFIG_TMUX}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/tmux" ]; then
		rm -rf "tmux-${TMUX_VERSION}"
		tar xf "${BASE}/downloads/tmux-${TMUX_VERSION}.tar.gz"
		cd "tmux-${TMUX_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--enable-static \
			 --host="i386-linux-musl"		
		make -j$CPUS LIBS="-lncursesw -levent_core -lterminfo"
		make -j$CPUS install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 tmux exists"
	fi
fi

# for mandoc
if [ "x${CONFIG_ZLIB}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/lib/libz.a" ]; then
		rm -rf "zlib-${ZLIB_VERSION}"
		tar xf "${BASE}/downloads/zlib-${ZLIB_VERSION}.tar.gz"
		cd "zlib-${ZLIB_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--static
		make -j$CPUS
		make -j$CPUS install PREFIX="${BASE}/build/stage1"
		# TOOD: do we need command line tools for ZIP?
		#~ cd contrib/minizip
		#~ make CC=/data/work/i486/build/stage1/bin/i386-tcc CFLAGS=-static
		#~ cp minizip /data/work/i486/build/stage1/bin/zip
		#~ cp miniunz /data/work/i486/build/stage1/bin/unzip
		cd .. || exit 1
	else
		echo "stage1 zlib exists"
	fi
fi

if [ "x${CONFIG_MANDOC}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/man" ]; then
		rm -rf "mandoc-${MANDOC_VERSION}"
		tar xf "${BASE}/downloads/mandoc-${MANDOC_VERSION}.tar.gz"
		cd "mandoc-${MANDOC_VERSION}" || exit 1
		cat >configure.local <<EOF
			PREFIX=${BASE}/build/stage1
			BINDIR=/bin
			SBINDIR=/bin
			MANDIR=/share
			CC="${BASE}/build/stage1/bin/i386-tcc"
			CFLAGS="-static -I${BASE}/build/stage1/include"
			LDFLAGS="-static -L${BASE}/build/stage1/lib"
			BINM_PAGER=more
EOF
		# TODO: can we patch out zlib support? Or patch in xz support?
		./configure
		make -j$CPUS
		make -j$CPUS install DESTDIR="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 mandoc exists"
	fi
fi

if [ "x${CONFIG_ABASE}" = "xy" ]; then
	if [ ! -x "${BASE}/build/stage1/bin/abase-box" ]; then
		rm -rf "abase-${ABASE_VERSION}"
		tar xf "${BASE}/downloads/abase-${ABASE_VERSION}.tar.gz"
		cd "abase-${ABASE_VERSION}" || exit 1
		make -j$CPUS abase-box CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
		make -j$CPUS abase-box-install PREFIX="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 abase exists"
	fi
fi

if [ "x${CONFIG_NBD}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/nbd-client" ]; then
		rm -rf "nbd-${NBD_VERSION}"
		tar xf "${BASE}/downloads/nbd-${NBD_VERSION}.tar.gz"
		cd "nbd-${NBD_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--enable-static --disable-shared \
			--without-gnutls --without-libnl \
			--host="i386-linux-musl"
		make -j$CPUS V=1 nbd-client
		# libtool links wrongly dynamically with static archives?
		${BASE}/build/stage1/bin/i386-tcc -static -g \
			-DNOTLS -DPROG_NAME=\"nbd-client\" \
			-o nbd-client nbd_client-nbd-client.o ./.libs/libcliserv.a ./.libs/libnbdclt.a
		cp nbd-client "${BASE}/build/stage1/bin/."
		cd .. || exit 1
	else
		echo "stage1 nbd-client exists"
	fi
fi

if [ "x${CONFIG_SAMURAI}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/samu" ]; then
		rm -rf "samurai-${SAMURAI_VERSION}"
		tar xf "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz"
		cd "samurai-${SAMURAI_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static \
		make -j$CPUS samu
		make -j$CPUS install DESTDIR="${BASE}/build/stage1" PREFIX=/
		cd .. || exit 1
	else
		echo "stage1 samurai exists"
	fi
fi

if [ "x${CONFIG_MUON}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/muon" ]; then
		rm -rf "muon-${MUON_VERSION}"
		tar xf "${BASE}/downloads/muon-${MUON_VERSION}.tar.gz"
		cd "muon-${MUON_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static \
		./bootstrap.sh build
		# building muon needs too many 3rdparty libraries, maybe bootstrapped muon is enough?
		cp build/muon-bootstrap "${BASE}/build/stage1/bin/muon"
#		build/muon-bootstrap setup build
#		build/muon-bootstrap -C build samu
#		build/muon-bootstrap -C build test
#		build/muon-bootstrap -C build install
		cd .. || exit 1
	else
		echo "stage1 muon exists"
	fi
fi

if [ "x${CONFIG_JOE}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/joe" ]; then
		rm -rf "joe-${JOE_VERSION}"
		tar xf "${BASE}/downloads/joe-${JOE_VERSION}.tar.gz"
		cd "joe-${JOE_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--enable-static --disable-shared \
			--host="i386-linux-musl"
		make -j$CPUS LDFLAGS=-static
		make -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 joe exists"
	fi
fi

if [ "x${CONFIG_SC}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/sc" ]; then
		rm -rf "sc-${SC_VERSION}"
		tar xf "${BASE}/downloads/sc-${SC_VERSION}.tar.gz"
		cd "sc-${SC_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		LDFLAGS=-L"${BASE}/build/stage1/lib -fla" \
		CFLAGS=-I"${BASE}/build/stage1/include" \
		./configure
		sed -i 's/^DEFINES=.*/DEFINES= -DHAVE_STRLCPY -DHAVE_STRLCAT  -DHAVE_ATTR_T -DHAVE_ATTR_GET -DHAVE_CURSES_KEYNAME -DHAVE_ISFINITE -DNO_ATTR_GET -DHAVE_STDBOOL_H/g' Makefile
		make -j$CPUS LDFLAGS=-static \
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		CFLAGS=-I"${BASE}/build/stage1/include" \
		LIB_CURSES="-static ${BASE}/build/stage1/lib/libcurses.a ${BASE}/build/stage1/lib/libtermcap.a"
		make -j$CPUS prefix="${BASE}/build/stage1" install
		cd .. || exit 1
	else
		echo "stage1 sc exists"
	fi
fi

if [ "x${CONFIG_DROPBEAR}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/dropbearmulti" ]; then
		rm -rf "dropbear-${DROPBEAR_VERSION}"
		tar xf "${BASE}/downloads/dropbear-${DROPBEAR_VERSION}.tar.bz2"
		cd "dropbear-${DROPBEAR_VERSION}" || exit
		patch -Np1 < "${BASE}/patches/dropbear-path.patch"
		patch -Np1 < "${BASE}/patches/dropbear-static-assert.patch"
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--enable-static \
			--host="i386-linux-musl"
		make -j$CPUS STATIC=1 MULTI=1 SCPPROGRESS=1 PROGRAMS="dropbear dbclient dropbearkey scp ssh"
		cp dropbearmulti "${BASE}/build/stage1/bin/."
		make -j$CPUS inst_dropbearmulti
		rm -f "${BASE}/build/stage1/sbin/dropbear"
		for i in dbclient dropbearkey dropbear scp ssh; do
			ln -sf dropbearmulti "${BASE}/build/stage1/bin/${i}"
		done
		# generate keys on the host (as this one has more power than
		# the 486, this works on this set of ISAs if the host is AMD64/x86
		# (otherwise we have to build either a host version of dropbear and
		# hope the key formats are platform independent or we use qemu-img
		# to generate the keys). Generating them here is also a security issue
		# as host keys are supposed to be built on each unique host!
		mkdir "${BASE}/build/stage1/etc/dropbear"
		"${BASE}/build/stage1/bin/dropbearkey" -t rsa -f "${BASE}/build/stage1/etc/dropbear/dropbear_rsa_host_key"
		"${BASE}/build/stage1/bin/dropbearkey" -t ecdsa -f "${BASE}/build/stage1//etc/dropbear/dropbear_ecdsa_host_key"
		"${BASE}/build/stage1/bin/dropbearkey" -t ed25519 -f "${BASE}/build/stage1//etc/dropbear/dropbear_ed25519_host_key"
		cd .. || exit 1
	else
		echo "stage1 dropbear exists"
	fi
fi

if [ "x${CONFIG_TINYXLIB}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/lib/libX11.a" ]; then
		rm -rf "tinyxlib-${TINYXLIB_VERSION}"
		tar xf "${BASE}/downloads/tinyxlib-${TINYXLIB_VERSION}.tar.gz"
		cd "tinyxlib-${TINYXLIB_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/tinyxlib-tcc.patch"	
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" \
			COMPFLAGS="-Os -march=i486 -Wall -D_XOPEN_SOURCE=600 -D_BSD_SOURCE -D_GNU_SOURCE -fno-strength-reduce -nostdlib -fno-strict-aliasing  -I. -ffunction-sections -fdata-sections" \
			LDFLAGS=""
		mkdir -p "${BASE}/build/stage1/share/X11"
		make -j$CPUS DESTDIR="${BASE}/build/stage1" PREDIR=/ -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 tinyxlib exists"
	fi
fi

if [ "x${CONFIG_TINYXSERVER}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/Xfbdev" ]; then
		rm -rf "tinyxserver-${TINYXSERVER_VERSION}"
		tar xf "${BASE}/downloads/tinyxserver-${TINYXSERVER_VERSION}.tar.gz"
		cd "tinyxserver-${TINYXSERVER_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/tinyxserver-tcc.patch"	
		make -j$CPUS BASE="${BASE}" core Xfbdev xinit
		make -j$CPUS BASE="${BASE}" DESTDIR="${BASE}/build/stage1" PREDIR=/ -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 Xfbdev exists"
	fi
fi

if [ "x${CONFIG_TINYXSERVER}" = "xy" ]; then
	if [ ! -f "${BASE}/tools/bdftopcf" ]; then
		rm -rf "bdftopcf-${BDFTOPCF_VERSION}"
		tar xf "${BASE}/downloads/bdftopcf-${BDFTOPCF_VERSION}.tar.gz"
		cd "bdftopcf-${BDFTOPCF_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/bdftopcf-tcc.patch"
		"${BASE}/build/stage1/bin/i386-tcc" -static -I. -DPACKAGE_STRING='"bdftopdf ${BDFTOPCF_VERSION}"' -o "${BASE}/tools/bdftopcf" *.c
		cd .. || exit 1
	else
		echo "tool bdftopcf exists"
	fi

	if [ ! -f "${BASE}/tools/ucs2any" ]; then
		rm -rf "font-util-${FONT_UTIL_VERSION}"
		tar xf "${BASE}/downloads/font-util-${FONT_UTIL_VERSION}.tar.gz"
		cd "font-util-${FONT_UTIL_VERSION}" || exit
		"${BASE}/build/stage1/bin/i386-tcc" -static -I. -o "${BASE}/tools/ucs2any" ucs2any.c
		cd .. || exit 1
	else
		echo "tool bdftopcf exists"
	fi
fi

# generate fonts and install them
if [ "x${CONFIG_TINYXSERVER}" = "xy" ]; then
	if [ ! -d "${BASE}/build/stage1/share/X11/fonts" ]; then
		rm -rf "font-cursor-misc-${FONT_CURSOR_MISC_VERSION}"
		rm -rf "font-misc-misc-${FONT_MISC_MISC_VERSION}"
		rm -rf "font-util-${FONT_UTIL_VERSION}"
		tar xf "${BASE}/downloads/font-cursor-misc-${FONT_CURSOR_MISC_VERSION}.tar.gz"
		tar xf "${BASE}/downloads/font-misc-misc-${FONT_MISC_MISC_VERSION}.tar.gz"
		tar xf "${BASE}/downloads/font-util-${FONT_UTIL_VERSION}.tar.gz"
		mkdir -p "${BASE}/build/stage1/share/X11/fonts"
		cp -dR "${BASE}/local/share/X11/fonts/"* "${BASE}/build/stage1/share/X11/fonts/."
		"${BASE}/tools/bdftopcf" -t "font-cursor-misc-${FONT_CURSOR_MISC_VERSION}/cursor.bdf" | gzip -n -9 > "${BASE}/build/stage1/share/X11/fonts/cursor.pcf.gz"
		"${BASE}/tools/ucs2any" "font-misc-misc-${FONT_MISC_MISC_VERSION}/6x13.bdf" "${BASE}/src/stage1/font-util-1.4.1/map-ISO8859-1" ISO8859-1
		"${BASE}/tools/bdftopcf" -t "6x13-ISO8859-1.bdf" | gzip -n -9 > "${BASE}/build/stage1/share/X11/fonts/6x13-ISO8859-1.pcf.gz"
	else
		echo "stage1 X11 fonts exist"
	fi
fi

if [ "x${CONFIG_RXVT}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/rxvt" ]; then
		rm -rf "rxvt-${RXVT_VERSION}"
		tar xf "${BASE}/downloads/rxvt-${RXVT_VERSION}.tar.gz"
		cd "rxvt-${RXVT_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/rxvt-font.patch"
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --enable-static --prefix="${BASE}/build/stage1" \
			--x-includes="${BASE}/build/stage1/include" \
			--x-libraries="${BASE}/build/stage1/lib"
		sed -i 's/.*PTYS_ARE_PTMX.*/#define PTYS_ARE_PTMX 1/' config.h
		make -j$CPUS LDFLAGS="-static"
		make -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 rxvt exists"
	fi
fi

if [ "x${CONFIG_XAUTH}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/xauth" ]; then
		rm -rf "xauth-${XAUTH_VERSION}"
		tar xf "${BASE}/downloads/xauth-${XAUTH_VERSION}.tar.gz"
		cd "xauth-${XAUTH_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/xauth-ipv6.patch"
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--x-includes="${BASE}/build/stage1/include" \
			--x-libraries="${BASE}/build/stage1/lib" \
			--host="i386-linux-musl"
		make -j$CPUS LDFLAGS="-static"
		make -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 xauth exists"
	fi
fi

if [ "x${CONFIG_XHOST}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/xhost" ]; then
		rm -rf "xhost-${XHOST_VERSION}"
		tar xf "${BASE}/downloads/xhost-${XHOST_VERSION}.tar.gz"
		cd "xhost-${XHOST_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/xhost-ipv6.patch"
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--x-includes="${BASE}/build/stage1/include" \
			--x-libraries="${BASE}/build/stage1/lib" \
			--host="i386-linux-musl"
		make -j$CPUS LDFLAGS="-static"
		make -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 xhost exists"
	fi
fi

if [ "x${CONFIG_MEH}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/meh" ]; then
		rm -rf "meh-${MEH_VERSION}"
		tar xf "${BASE}/downloads/meh-${MEH_VERSION}.tar.gz"
		cd "meh-${MEH_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/meh-tcc.patch"
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" \
			CFLAGS="-Os -I${BASE}/build/stage1/include" \
			LDFLAGS="-static" \
			LIBS="${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libX11.a"
		make -j$CPUS DESTDIR="${BASE}/build/stage1" PREFIX="" install
		cd .. || exit 1
	else
		echo "stage1 meh exists"
	fi
fi

if [ "x${CONFIG_SLOCK}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/slock" ]; then
		rm -rf "slock-${SLOCK_VERSION}"
		tar xf "${BASE}/downloads/slock-${SLOCK_VERSION}.tar.gz"
		cd "slock-${SLOCK_VERSION}" || exit 1
		cp "${BASE}/configs/slock-config.h" config.h
		patch -Np1 < "${BASE}/patches/slock-tcc.patch"
		patch -Np1 < "${BASE}/patches/slock-no-xrandr.patch"
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" \
			VERSION="${SLOCK_VERSION}" \
			CFLAGS="-Os -DVERSION= -I${BASE}/build/stage1/include" \
			LDFLAGS="-static ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libX11.a"
		make -j$CPUS DESTDIR="${BASE}/build/stage1" PREFIX="" install
		cd .. || exit 1
	else
		echo "stage1 slock exists"
	fi
fi

# for notion
if [ "x${CONFIG_LUA}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/lua" ]; then
		rm -rf "lua-${LUA_VERSION}"
		tar xf "${BASE}/downloads/lua-${LUA_VERSION}.tar.gz"
		cd "lua-${LUA_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/lua51-no-readline.patch"
		make -j$CPUS linux CC="${BASE}/build/stage1/bin/i386-tcc" \
			MYLDFLAGS=-static AR="${BASE}/build/stage1/bin/i386-tcc -ar" RANLIB=echo
		make -j$CPUS install INSTALL_TOP="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 lua exists"
	fi
fi

if [ "x${CONFIG_NOTION}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/notion" ]; then
		rm -rf "notion-${NOTION_VERSION}"
		tar xf "${BASE}/downloads/notion-${NOTION_VERSION}.tar.gz"
		cd "notion-${NOTION_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/notion-minimal.patch"
		sed -i "s|@@BASE@@|${BASE}|g" \
			mod_sm/Makefile notion/Makefile \
			libextl/system-autodetect.mk
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		make INCLUDE="-I${BASE}/src/stage1/notion-${NOTION_VERSION}" \
			X11_INCLUDES="-I${BASE}/build/stage1/include" \
			X11_LIBS="${BASE}/build/stage1/lib/libX11.a ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libSM.a ${BASE}/build/stage1/lib/libICE.a ${BASE}/build/stage1/lib/libX11.a ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libXinerama.a" \
			XRANDR_LDLIBS="" \
			USE_XFT=0 \
			LUA_DIR="${BASE}/build/stage1" \
			LUA_INCLUDES="-I${BASE}/build/stage1/include" \
			LUA_LIBS="${BASE}/build/stage1/lib/liblua.a" \
			LUA="${BASE}/build/stage1/bin/lua" \
			LUAC="${BASE}/build/stage1/bin/luac" \
			PRELOAD_MODULES=1 \
			LUA_VERSION=5.1 PREFIX=/ ETCDIR=/etc/notion
		# remove wrongly dynamically linked binaries and rebuild them
		rm notion/notion mod_notionflux/notionflux/notionflux utils/ion-completefile/ion-completefile utils/ion-statusd/ion-statusd
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		LDFLAGS="-static" \
		make INCLUDE="-I${BASE}/src/stage1/notion-${NOTION_VERSION}" \
			X11_INCLUDES="-I${BASE}/build/stage1/include" \
			X11_LIBS="${BASE}/build/stage1/lib/libX11.a ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libSM.a ${BASE}/build/stage1/lib/libICE.a ${BASE}/build/stage1/lib/libX11.a ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libXinerama.a" \
			XRANDR_LDLIBS="" \
			USE_XFT=0 \
			LUA_DIR="${BASE}/build/stage1" \
			LUA_INCLUDES="-I${BASE}/build/stage1/include" \
			LUA_LIBS="${BASE}/build/stage1/lib/liblua.a" \
			LUA="${BASE}/build/stage1/bin/lua" \
			LUAC="${BASE}/build/stage1/bin/luac" \
			PRELOAD_MODULES=1 \
			LUA_VERSION=5.1 PREFIX=/ ETCDIR=/etc/notion
		make -j$CPUS DESTDIR="${BASE}/build/stage1" PRELOAD_MODULES=1 PREFIX=/ -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 notion exists"
	fi
fi

if [ "x${CONFIG_MUTT}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/mutt" ]; then
		rm -rf "mutt-${MUTT_VERSION}"
		tar xf "${BASE}/downloads/mutt-${MUTT_VERSION}.tar.gz"
		cd "mutt-${MUTT_VERSION}" || exit 1
		autoreconf -fiv
		LDFLAGS="-static ${BASE}/build/stage1/lib/libcurses.a ${BASE}/build/stage1/lib/libtermcap.a" \
		CC="${BASE}/build/stage1/bin/i386-tcc" ./configure \
			--prefix="${BASE}/build/stage1" \
			--target=i386-linux-musl \
			--with-curses="${BASE}/build/stage1"
		make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc"
		make -j$CPUS install INSTALL_TOP="${BASE}/build/stage1"
		cd .. || exit 1
	else
		echo "stage1 mutt exists"
	fi
fi

if [ "x${CONFIG_FBSET}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/fbset" ]; then
		rm -rf "fbset-${FBSET_VERSION}"
		tar xf "${BASE}/downloads/fbset-${FBSET_VERSION}.tar.gz"
		cd "fbset-${FBSET_VERSION}" || exit 1
		patch -Np1 < "${BASE}/patches/fbset-tcc.patch"
		make -j1 CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS="-static"
		install fbset "${BASE}/build/stage1/bin"
		cd .. || exit 1
	else
		echo "stage1 fbset exists"
	fi
fi

if [ "x${CONFIG_LBFORTH}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/lbforth" ]; then
		rm -rf "lbforth-${LBFORTH_VERSION}"
		tar xf "${BASE}/downloads/lbforth-${LBFORTH_VERSION}.tar.gz"
		cd "lbforth-${LBFORTH_VERSION}/SRC" || exit 1
		"${BASE}/build/stage1/bin/i386-tcc" -static -DBITS32 -o lbforth lbforth.c
		cp "lbforth" "${BASE}/build/stage1/bin"
		cd ../.. || exit 1
	else
		echo "stage1 lbforth exists"
	fi
fi

if [ "x${CONFIG_SQLITE}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/sqlite3" ]; then
		MAJOR_SQLITE_VERSION=`echo "${SQLITE_VERSION}" | cut -d . -f 1`
		MINOR_SQLITE_VERSION=`echo "${SQLITE_VERSION}" | cut -d . -f 2`
		PATCH_SQLITE_VERSION=`echo "${SQLITE_VERSION}" | cut -d . -f 3`
		_SQLITE_VERSION=`expr ${MAJOR_SQLITE_VERSION} \* 1000000 + ${MINOR_SQLITE_VERSION} \* 10000 + ${PATCH_SQLITE_VERSION} \* 100`
		rm -rf "sqlite-src-${_SQLITE_VERSION}"
		unzip -q "${BASE}/downloads/sqlite-${SQLITE_VERSION}.zip"
		cd "sqlite-src-${_SQLITE_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" ./configure \
			--enable-static --prefix="${BASE}/build/stage0" \
			--disable-shared --disable-readline \
			--static-cli-shell --disable-tcl                    
		make
		cp "sqlite3" "${BASE}/build/stage1/bin"
		cd .. || exit 1
	else
		echo "stage1 sqlite3 exists"
	fi
fi

if [ "x${CONFIG_NASM}" = "xy" ]; then
	if [ ! -f "${BASE}/build/stage1/bin/nasm" ]; then
		rm -rf "nasm-${NASM_VERSION}.tar.xz"
		tar xf "${BASE}/downloads/nasm-${NASM_VERSION}.tar.xz"
		cd "nasm-${NASM_VERSION}" || exit 1
		CC="${BASE}/build/stage1/bin/i386-tcc" \
		./configure --prefix="${BASE}/build/stage1" \
			--host="i386-linux-musl"
		make -j$CPUS LDFLAGS="-static"
		make -j$CPUS install
		cd .. || exit 1
	else
		echo "stage1 xhost exists"
	fi
fi

#~ if [ "x${CONFIG_WORDGRINDER}" = "xy" ]; then
#~ if [ ! -f "${BASE}/build/stage1/bin/wg" ]; then
	#~ rm -rf "wordgrinder-${WORDGRINDER_VERSION}"
	#~ tar xf "${BASE}/downloads/wordgrinder-${WORDGRINDER_VERSION}.tar.gz"
	#~ cd "wordgrinder-${WORDGRINDER_VERSION}" || exit 1
	#~ patch -Np1 < "${BASE}/patches/wordgrinder-tcc.patch"
	#~ sed -i "s|@@BASE@@|${BASE}|g" Makefile src/c/emu/lpeg/makefile
	#~ make -j$CPUS \
		#~ LUA_PACKAGE="--cflags={-I${BASE}/build/stage1/include} --libs={${BASE}/build/stage1/lib/liblua.a}" \
		#~ CURSES_PACKAGE="--cflags={-I${BASE}/build/stage1/include} --libs={${BASE}/build/stage1/lib/libncurses.a ${BASE}/build/stage1/lib/libtermcap.a}" \
		#~ XFT_PACKAGE="none" \
		#~ NINJA="${BASE}/build/stage1/bin/samu" \
		#~ CC="${BASE}/build/stage1/bin/i386-tcc" \
		#~ LDFLAGS="-static"
	#~ make -j$CPUS install PREFIX= DESTDIR="${BASE}/build/stage1"
	#~ cd .. || exit 1
#~ else
	#~ echo "stage1 lua exists"
#~ fi
#~ fi

# TODO FROM HERE

# TODO: have some way to deal with dependencies and with the user
# choosing what he wants to have in the final system or/and on
# the ramdisk
# TODO: we also have to think about whether build artifacts are
# the same per stage (for instance ramdisk binaries are static
# and crunched, final binaries on the hard disk maybe dynamic
# and "normal"..?

#~ cd ../less
#~ CC=/data/work/i486/build/stage1/bin/i386-tcc ./configure --prefix=/data/work/i486/build/stage1
#~ make LDFLAGS=-static
#~ make install PREFIX=/data/work/i486/build/stage1

#~ cd ../screen
#~ ./autogen.sh
#~ CC=/data/work/i486/build/stage1/bin/i386-tcc CFLAGS='-march=i486 -mcpu=i486' ./configure --prefix=/data/work/i486/build/stage1
#~ make LDFLAGS=-static

#~ cd ../lynx
#~ CC=/data/work/i486/build/stage1/bin/i386-tcc CFLAGS='-march=i486 -mcpu=i486' ./configure --prefix=/data/work/i486/build/stage1

#~ cd ../perp
#~ cd lasagna
#~ make CC=/data/work/i486/build/stage1/bin/i386-tcc 
#~ cd ..
#~ make CC=/data/work/i486/build/stage1/bin/i386-tcc LDFLAGS="-static ../lasagna/libasagna.a"
#~ make install

#~ cd ../strace
#~ CC=/data/work/i486/build/stage1/bin/i386-tcc ./configure --prefix=/data/work/i486/build/stage1 --enable-mpers=no --disable-dependency-tracking
#~ make
#~ # TODO: rtnl_link.c:968: error: Unexpected size of ivg.ivg_64(16 expected)

#~ cd ../editline
#~ ./autogen.sh
#~ CC=/data/work/i486/build/stage1/bin/i386-tcc ./configure --prefix=/data/work/i486/build/stage1 --enable-static
#~ make LDFLAGS=-static
#~ make install

#~ cd ../iproute2
#~ PKG_CONFIG=false CC=/data/work/i486/build/stage1/bin/i386-tcc \
	#~ ./configure --prefix=/data/work/i486/build/stage1
#~ make LDFLAGS=-static CC=/data/work/i486/build/stage1/bin/i386-tcc
#~ make install DESTDIR=/data/work/i486/build/stage1 PREFIX=/

# END TODO

# we cannot build the kernel with tcc (tccboot times are long gone), so
# we build it with gcc. Luckily we don't need a cross-compiler for that
# on x86_64, we can just use the hosts gcc.

if [ ! -f "${BASE}/build/stage1/boot/bzImage" ]; then
	echo "Building the Linux kernel.."
	rm -rf "linux-${LINUX_KERNEL_VERSION}"
	tar xf "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz"
	cd "linux-${LINUX_KERNEL_VERSION}" || exit 1
	# this configuration is based on tinyconfig, then enabling things as
	# specified in the README
	cp "${BASE}/configs/linux-config" .config
	make -j$CPUS bzImage
	test -d "${BASE}/build/stage1/boot" || mkdir "${BASE}/build/stage1/boot"
	cp arch/i386/boot/bzImage "${BASE}/build/stage1/boot"
	make -j$CPUS modules
	rm -rf "${BASE}/build/stage1/lib/modules"
	mkdir "${BASE}/build/stage1/lib/modules"
	find . -name '*.ko' | xargs tar -cf - | tar -C "${BASE}/build/stage1/lib/modules" -xf -
	cd .. || exit 1
else
	echo "stage1 kernel exists"
fi

# floppy boot loader

if [ ! -f "${BASE}/build/stage1/boot/boot.img" ]; then
	rm -rf "uflbbl-${UFLBBL_VERSION}"
	tar xf "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz"
	cd "uflbbl-${UFLBBL_VERSION}" || exit 1
	patch -Np1 < "${BASE}/patches/uflbbl-boot-options.patch"
	patch -Np1 < "${BASE}/patches/uflbbl-debug.patch"
	cd src
	nasm -o boot.img boot.asm
	cp boot.img "${BASE}/build/stage1/boot/boot.img"
	cd .. || exit 1
else
	echo "stage1 uflbbl exists"
fi

cd ../.. || exit 1

# ramdisk

if [ ! -f "${BASE}/ramdisk.img" ]; then
	echo "Creating ramdisk.."
	${BASE}/scripts/create_ramdisk.sh
else
	echo "ramdisk image exists"
fi

# root file system

if [ ! -f "${BASE}/root.img" ]; then
	echo "Creating root image.."
	${BASE}/scripts/create_root.sh
else
	echo "root image exists"
fi

# tools on the host (assuming we use i386 code compiled with tcc and run
# on a AMD64/i386 host)

cd "${BASE}" || exit 1

if [ ! -x "${BASE}/tools/rdev" ]; then
	"${BASE}/build/stage1/bin/i386-tcc" -static -o tools/rdev tools/rdev.c
else
	echo "tool rdev exists"
fi

# create boot floppies

if [ ! -f "${BASE}/floppy.img" ]; then
	touch EOF
	cp "${BASE}/build/stage1/boot/bzImage" .
	# old way of setting video mode on boot into real mode (0x317)
	tools/rdev -v bzImage 792
	tar cvf data.tar -b1 bzImage ramdisk.img EOF
	cat "${BASE}/build/stage1/boot/boot.img" data.tar > "${BASE}/floppy.img"
	split -d -b 1474560 floppy.img floppy
	LASTFILE=`ls floppy?? | sort | tail -n 1`
	FILESIZE=`wc -c < "${LASTFILE}"`
	PADSIZE=`echo "1474560-${FILESIZE}" | bc`
	if [ "${PADSIZE}" -gt 0 ]; then
		dd if=/dev/zero count=1 bs="${PADSIZE}" > PAD
		cat "${LASTFILE}" PAD > "${LASTFILE}-padded"
		mv "${LASTFILE}-padded" "${LASTFILE}"
	fi
	for floppy in `ls floppy??`; do
		mv "${floppy}" "${floppy}.img"
	done
fi

trap - 0

exit 0
 
