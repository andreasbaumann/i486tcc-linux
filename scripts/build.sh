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

#CPUS=$(nproc)
CPUS=1

. "${BASE}/configs/versions"

${BASE}/scripts/download.sh

echo "Building in base directory '$BASE'"

# stage 0
#########

cd "${BASE}/src/stage0"

# stage 0 host, build a 64-bit cross-compiler for i386, the host might
# not have a packaged tcc at all or one not built for cross-compilation
# TODO: we get a little bit too many cross compilers, but currently
# we cannot easily build just the ones we want.

if [ ! -x "${BASE}/build/stage0/bin/i386-tcc" ]; then
	rm -rf "tinycc-${TINYCC_VERSION}"
	tar xf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz"
	cd "tinycc-${TINYCC_VERSION}"
	patch -Np1 < "${BASE}/patches/tcc-asm.patch"
	./configure --enable-static --prefix="${BASE}/build/stage0" \
		--config-musl --enable-cross
	make -j$CPUS
	make -j$CPUS install
	cd ..
else
	echo "stage0 tcc-i386 binary exists"
fi

# build a first C library which is used to build the stage 1 tcc
# against, and of course stage 0

if [ ! -f "${BASE}/build/stage0/lib/libc.a" ]; then
	rm -rf "musl-${MUSL_VERSION}"
	tar xf "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz"
	cd "musl-${MUSL_VERSION}"
	patch -Np1 < "${BASE}/patches/musl-tcc.patch"
	CC="${BASE}/build/stage0/bin/i386-tcc" ./configure \
		--prefix="${BASE}/build/stage0" \
		--target=i386-linux-musl --disable-shared
	make -j$CPUS AR="${BASE}/build/stage0/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install
	cd ..
else
	echo "stage0 musl C library exists"
fi

# build tcc with tcc from stage1 against musl from stage0, it should
# have no dependencies on the host anymore

cd "${BASE}/src/stage1"

if [ ! -x "${BASE}/build/stage1/bin/i386-tcc" ]; then
	rm -rf "tinycc-${TINYCC_VERSION}"
	tar xf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz"
	cd "tinycc-${TINYCC_VERSION}"
	patch -Np1 < "${BASE}/patches/tcc-asm.patch"
	patch -Np1 < "${BASE}/patches/tcc-stage1.patch"
	sed -i "s|@@BASE@@|${BASE}|g" Makefile configure config-extra.mak
	sed -i "s|@@TINYCC_VERSION@@|${TINYCC_VERSION}|g" Makefile configure config-extra.mak
	./configure --enable-static --prefix="${BASE}/build/stage1" \
		--cc="${BASE}/build/stage0/bin/i386-tcc" --config-musl \
		--enable-cross
	make -j$CPUS
	make -j$CPUS install
	ln -fs tcc/i386-libtcc1.a "${BASE}/build/stage1/lib/."
	cd ..
else
	echo "stage1 tcc-i386 binary exists"
fi

# stage 1
#########

# rebuild musl with tcc from stage1

if [ ! -f "${BASE}/build/stage1/lib/libc.a" ]; then
	rm -rf "musl-${MUSL_VERSION}"
	tar xf "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz"
	cd "musl-${MUSL_VERSION}"
	patch -Np1 < "${BASE}/patches/musl-tcc.patch"
	CC="${BASE}/build/stage1/bin/i386-tcc" ARCH=i386 \
	./configure \
		--prefix="${BASE}/build/stage1" \
		--target=i386-linux-musl --disable-shared
	make -j$CPUS AR="${BASE}/build/stage1/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install
	cd ..
else
	echo "stage1 musl C library exists"
fi

# install kernel headers (we don't think musl does any trickery to
# them or depends on them being installed)

if [ ! -d "${BASE}/build/stage1/include/linux" ]; then
	rm -rf "linux-${LINUX_KERNEL_VERSION}"
	tar xf "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz"
	cd "linux-${LINUX_KERNEL_VERSION}"
	CC=false make -j$CPUS ARCH=x86 INSTALL_HDR_PATH="${BASE}/build/stage1" headers_install
	cd ..
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

if [ ! -x "${BASE}/build/stage1/bin/oksh" ]; then
	rm -rf "oksh-${_OKSH_VERSION}"
	tar xf "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz"
	cd "oksh-${_OKSH_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure \
		--prefix="${BASE}/build/stage1" \
		--disable-shared --enable-static
	make -j$CPUS LDFLAGS=-static
	make -j$CPUS install
	ln -s oksh "${BASE}/build/stage1/bin/sh"
	cd ..
else
	echo "stage1 oksh exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/sbase-box" ]; then
	rm -rf "sbase-${SBASE_VERSION}"
	tar xf "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz"
	cd "sbase-${SBASE_VERSION}"
	make -j$CPUS sbase-box CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS sbase-box-install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 sbase exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/ubase-box" ]; then
	rm -rf "ubase-${UBASE_VERSION}"
	tar xf "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz"
	cd "ubase-${UBASE_VERSION}"
	patch -Np1 < "${BASE}/patches/ubase-sysmacros.patch"
	make -j$CPUS ubase-box CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS ubase-box-install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 ubase exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/smdev" ]; then
	rm -rf "smdev-${SMDEV_VERSION}"
	tar xf "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz"
	cd "smdev-${SMDEV_VERSION}"
	patch -Np1 < "${BASE}/patches/smdev-sysmacros.patch"
	make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 smdev exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/sinit" ]; then
	rm -rf "sinit-${SINIT_VERSION}"
	tar xf "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz"
	cd "sinit-${SINIT_VERSION}"
	cp "${BASE}/configs/sinit-config.h" config.h
	make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 smdev exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/sdhcp" ]; then
	rm -rf "sdhcp-${SDHCP_VERSION}"
	tar xf "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz"
	cd "sdhcp-${SDHCP_VERSION}"
	make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS install PREFIX="${BASE}/build/stage1"
	mv "${BASE}/build/stage1/sbin/sdhcp" "${BASE}/build/stage1/bin"
	rmdir "${BASE}/build/stage1/sbin"
	cd ..
else
	echo "stage1 sdhcp exists"
fi

# for vi
if [ ! -f "${BASE}/build/stage1/lib/libncurses.a" ]; then
	rm -rf "netbsd-curses-${NETBSD_NCURSES_VERSION}"
	tar xf "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz"
	cd "netbsd-curses-${NETBSD_NCURSES_VERSION}"
	patch -Np1 < "${BASE}/patches/netbsd-curses-attributes.patch"
	CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS='-static' make -j$CPUS all-static
	CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS='-static' make -j$CPUS install-static \
		PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 netbsd-curses exists"
fi

# for vis
if [ ! -f "${BASE}/build/stage1/lib/libtermkey.a" ]; then
	rm -rf "libtermkey-${LIBTERMKEY_VERSION}"
	tar xf "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz"
	cd "libtermkey-${LIBTERMKEY_VERSION}"
	"${BASE}/build/stage1/bin/i386-tcc" -c termkey.c
	"${BASE}/build/stage1/bin/i386-tcc" -c driver-ti.c
	"${BASE}/build/stage1/bin/i386-tcc" -c driver-csi.c
	"${BASE}/build/stage1/bin/i386-tcc" -ar libtermkey.a termkey.o driver-ti.o driver-csi.o
	cp libtermkey.a "${BASE}/build/stage1/lib"
	cp termkey.h "${BASE}/build/stage1/include"
	cd ..
else
	echo "stage1 libtermkey exists"
fi

# for vi, tmux
if [ ! -f "${BASE}/build/stage1/lib/libevent.a" ]; then
	rm -rf "libevent-${LIBEVENT_VERSION}"
	tar xf "${BASE}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz"
	cd "libevent-${LIBEVENT_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/build/stage1" \
		--enable-static --disable-shared --disable-openssl
	make -j$CPUS
	make -j$CPUS install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 libevent exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/vi" ]; then
	rm -rf "vis-${VIS_VERSION}"
	tar xf "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz"
	cd "vis-${VIS_VERSION}"
	patch -Np1 < "${BASE}/patches/vis-no-pkgconfig-for-ncurses.patch"
	LDFLAGS=-L"${BASE}/build/stage1/lib" \
	CFLAGS=-I"${BASE}/build/stage1/include" \
	CC="${BASE}/build/stage1/bin/i386-tcc"  \
	./configure --prefix="${BASE}/build/stage1" \
		--disable-lua
	make -j$CPUS LDFLAGS=-static
	cp vis "${BASE}/build/stage1/bin/vi"
	cd ..
else
	echo "stage1 vis exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/tmux" ]; then
	rm -rf "tmux-${TMUX_VERSION}"
	tar xf "${BASE}/downloads/tmux-${TMUX_VERSION}.tar.gz"
	cd "tmux-${TMUX_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/build/stage1" \
		--enable-static
	make -j$CPUS LIBS="-lncursesw -levent_core -lterminfo"
	make -j$CPUS install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 tmux exists"
fi

# for mandoc
if [ ! -f "${BASE}/build/stage1/lib/libz.a" ]; then
	rm -rf "zlib-${ZLIB_VERSION}"
	tar xf "${BASE}/downloads/zlib-${ZLIB_VERSION}.tar.gz"
	cd "zlib-${ZLIB_VERSION}"
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
	cd ..
else
	echo "stage1 zlib exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/man" ]; then
	rm -rf "mandoc-${MANDOC_VERSION}"
	tar xf "${BASE}/downloads/mandoc-${MANDOC_VERSION}.tar.gz"
	cd "mandoc-${MANDOC_VERSION}"
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
	cd ..
else
	echo "stage1 mandoc exists"
fi

if [ ! -x "${BASE}/build/stage1/bin/abase-box" ]; then
	rm -rf "abase-${ABASE_VERSION}"
	tar xf "${BASE}/downloads/abase-${ABASE_VERSION}.tar.gz"
	cd "abase-${ABASE_VERSION}"
	make -j$CPUS abase-box CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS abase-box-install PREFIX="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 abase exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/nbd-client" ]; then
	rm -rf "nbd-${NBD_VERSION}"
	tar xf "${BASE}/downloads/nbd-${NBD_VERSION}.tar.gz"
	cd "nbd-${NBD_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/build/stage1" \
		--enable-static --disable-shared \
		--without-gnutls --without-libnl
	make -j$CPUS V=1 nbd-client
	# libtool links wrongly dynamically with static archives?
	${BASE}/build/stage1/bin/i386-tcc -static -g \
		-DNOTLS -DPROG_NAME=\"nbd-client\" \
		-o nbd-client nbd_client-nbd-client.o ./.libs/libcliserv.a ./.libs/libnbdclt.a
	cp nbd-client "${BASE}/build/stage1/bin/."
	cd ..
else
	echo "stage1 nbd-client exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/samu" ]; then
	rm -rf "samurai-${SAMURAI_VERSION}"
	tar xf "${BASE}/downloads/samurai-${SAMURAI_VERSION}.tar.gz"
	cd "samurai-${SAMURAI_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" LDFLAGS=-static \
	make -j$CPUS samu
	make -j$CPUS install DESTDIR="${BASE}/build/stage1" PREFIX=/
	cd ..
else
	echo "stage1 samurai exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/joe" ]; then
	rm -rf "joe-${JOE_VERSION}"
	tar xf "${BASE}/downloads/joe-${JOE_VERSION}.tar.gz"
	cd "joe-${JOE_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/build/stage1" \
		--enable-static --disable-shared
	make -j$CPUS LDFLAGS=-static
	make -j$CPUS install
	cd ..
else
	echo "stage1 joe exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/dropbearmulti" ]; then
	rm -rf "dropbear-${DROPBEAR_VERSION}"
	tar xf "${BASE}/downloads/dropbear-${DROPBEAR_VERSION}.tar.bz2"
	cd "dropbear-${DROPBEAR_VERSION}"
	patch -Np1 < "${BASE}/patches/dropbear-path.patch"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/build/stage1" \
		--enable-static --disable-shared
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
	"${BASE}/build/stage1/bin/dropbearkey" -t dss -f "${BASE}/build/stage1//etc/dropbear/dropbear_dss_host_key"
	"${BASE}/build/stage1/bin/dropbearkey" -t ecdsa -f "${BASE}/build/stage1//etc/dropbear/dropbear_ecdsa_host_key"
	"${BASE}/build/stage1/bin/dropbearkey" -t ed25519 -f "${BASE}/build/stage1//etc/dropbear/dropbear_ed25519_host_key"
	cd ..
else
	echo "stage1 dropbear exists"
fi

if [ ! -f "${BASE}/build/stage1/lib/libX11.a" ]; then
	rm -rf "tinyxlib-${TINYXLIB_VERSION}"
	tar xf "${BASE}/downloads/tinyxlib-${TINYXLIB_VERSION}.tar.gz"
	cd "tinyxlib-${TINYXLIB_VERSION}"
	patch -Np1 < "${BASE}/patches/tinyxlib-tcc.patch"	
	make -j$CPUS CC="${BASE}/build/stage1/bin/i386-tcc" \
		COMPFLAGS="-Os -march=i486 -Wall -D_XOPEN_SOURCE=600 -D_BSD_SOURCE -D_GNU_SOURCE -fno-strength-reduce -nostdlib -fno-strict-aliasing  -I. -ffunction-sections -fdata-sections" \
		LDFLAGS=""
	mkdir -p "${BASE}/build/stage1/share/X11"
	make -j$CPUS DESTDIR="${BASE}/build/stage1" PREDIR=/ -j$CPUS install
	cd ..
else
	echo "stage1 tinyxlib exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/Xfbdev" ]; then
	rm -rf "tinyxserver-${TINYXSERVER_VERSION}"
	tar xf "${BASE}/downloads/tinyxserver-${TINYXSERVER_VERSION}.tar.gz"
	cd "tinyxserver-${TINYXSERVER_VERSION}"
	patch -Np1 < "${BASE}/patches/tinyxserver-tcc.patch"	
	make -j$CPUS BASE="${BASE}" core Xfbdev xinit
	make -j$CPUS BASE="${BASE}" DESTDIR="${BASE}/build/stage1" PREDIR=/ -j$CPUS install
	cd ..
else
	echo "stage1 Xfbdev exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/rxvt" ]; then
	rm -rf "rxvt-${RXVT_VERSION}"
	tar xf "${BASE}/downloads/rxvt-${RXVT_VERSION}.tar.gz"
	cd "rxvt-${RXVT_VERSION}"
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	./configure --enable-static --prefix="${BASE}/build/stage1" \
		--x-includes="${BASE}/build/stage1/include" \
		--x-libraries="${BASE}/build/stage1/lib"
	make -j$CPUS LDFLAGS="-static"
	make -j$CPUS install
	cd ..
else
	echo "stage1 rxvt exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/lua" ]; then
	rm -rf "lua-${LUA_VERSION}"
	tar xf "${BASE}/downloads/lua-${LUA_VERSION}.tar.gz"
	cd "lua-${LUA_VERSION}"
	patch -Np1 < "${BASE}/patches/lua51-no-readline.patch"
	make -j$CPUS linux CC="${BASE}/build/stage1/bin/i386-tcc" \
		MYLDFLAGS=-static AR="${BASE}/build/stage1/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install INSTALL_TOP="${BASE}/build/stage1"
	cd ..
else
	echo "stage1 lua exists"
fi

if [ ! -f "${BASE}/build/stage1/bin/notion" ]; then
	rm -rf "notion-${NOTION_VERSION}"
	tar xf "${BASE}/downloads/notion-${NOTION_VERSION}.tar.gz"
	cd "notion-${NOTION_VERSION}"
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
		LUAC="${BASE}/build/stage1/bin/luac" \
		PRELOAD_MODULES=1 \
		LUA_VERSION=5.1 PREFIX=/ ETCDIR=/etc/notion
	cd notion || exit 1
	rm notion
	CC="${BASE}/build/stage1/bin/i386-tcc" \
	LDFLAGS="-static" \
	make INCLUDE="-I${BASE}/src/stage1/notion-${NOTION_VERSION}" \
		X11_INCLUDES="-I${BASE}/build/stage1/include" \
		X11_LIBS="${BASE}/build/stage1/lib/libX11.a ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libSM.a ${BASE}/build/stage1/lib/libICE.a ${BASE}/build/stage1/lib/libX11.a ${BASE}/build/stage1/lib/libXext.a ${BASE}/build/stage1/lib/libXinerama.a" \
		XRANDR_LDLIBS="" \
		USE_XFT=0 \
		LUA_DIR="${BASE}/build/stage1" \
		LUAC="${BASE}/build/stage1/bin/luac" \
		PRELOAD_MODULES=1 \
		LUA_VERSION=5.1 PREFIX=/ ETCDIR=/etc/notion \
		notion
	cd .. || exit 1
	make -j$CPUS DESTDIR="${BASE}/build/stage1" PRELOAD_MODULES=1 PREFIX=/ -j$CPUS install
	cd ..
else
	echo "stage1 notion exists"
fi

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
	cd "linux-${LINUX_KERNEL_VERSION}"
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
	cd ..
else
	echo "stage1 kernel exists"
fi

# floppy boot loader

if [ ! -f "${BASE}/build/stage1/boot/boot.img" ]; then
	rm -rf "uflbbl-${UFLBBL_VERSION}"
	tar xf "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz"
	cd "uflbbl-${UFLBBL_VERSION}"
	patch -Np1 < "${BASE}/patches/uflbbl-boot-options.patch"
	cd src
	nasm -o boot.img boot.asm
	cp boot.img "${BASE}/build/stage1/boot/boot.img"
	cd ../..
else
	echo "stage1 uflbbl exists"
fi

cd ../..

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

# create boot floppies

if [ ! -f "${BASE}/floppy.img" ]; then
	touch EOF
	cp "${BASE}/build/stage1/boot/bzImage" .
	# old way of setting video mode on boot into real mode (0x317)
	tools/rdev -v bzImage 791
	tar cvf data.tar -b1 bzImage ramdisk.img EOF
	cat "${BASE}/build/stage1/boot/boot.img" data.tar > "${BASE}/floppy.img"
	split -d -b 1474560 floppy.img floppy
else
	echo "floppy images exist"
fi

trap - 0

exit 0
 
