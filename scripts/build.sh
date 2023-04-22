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

LINUX_KERNEL_VERSION="6.2.11"
TINYCC_VERSION="85b27"
MUSL_VERSION="1.2.3"
_OKSH_VERSION="7.2"
SBASE_VERSION="191f7"
UBASE_VERSION="3c887"
SMDEV_VERSION="8d075"
SINIT_VERSION="28c44"
SDHCP_VERSION="8455f"
UFLBBL_VERSION="d8680"
LIBEVENT_VERSION="2.1.12-stable"
VIS_VERSION="c9737"
LIBTERMKEY_VERSION="0.22"
NETBSD_NCURSES_VERSION="0.3.2"
TMUX_VERSION="3.3a"
ZLIB_VERSION="1.2.13"
MANDOC_VERSION="1.14.6"
ABASE_VERSION="36cd0"

echo "Building in base directory '$BASE'"

# download sources

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

if [ ! -f "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz" ]; then
	cd "${BASE}/downloads/"
	git clone git://git.andreasbaumann.cc/uflbbl.git "uflbbl-${UFLBBL_VERSION}"
	git -C "uflbbl-${UFLBBL_VERSION}" checkout "${UFLBBL_VERSION}"
	tar zcf "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz" "uflbbl-${UFLBBL_VERSION}"
	rm -rf "uflbbl-${UFLBBL_VERSION}"
	cd ..
fi

# we cannot build the kernel with tcc (tccboot times are long gone), so
# we build it with gcc. Luckily we don't need a cross-compiler for that,
# we can just use the hosts gcc.

if [ ! -f "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz" ]; then
	wget -O "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${LINUX_KERNEL_VERSION}.tar.gz"
fi

# stage 0
#########

cd "${BASE}/src/stage0"

# stage 0 host, build a 64-bit cross-compiler for i386, the host might
# not have a packaged tcc at all or one not built for cross-compilation
# TODO: we get a little bit too many cross compilers, but currently
# we cannot easily just the ones we want.

if [ ! -x "${BASE}/root/stage0/bin/i386-tcc" ]; then
	rm -rf "tinycc-${TINYCC_VERSION}"
	tar xf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz"
	cd "tinycc-${TINYCC_VERSION}"
	patch -Np1 < "../../../patches/tcc-asm.patch"
	./configure --enable-static --prefix="${BASE}/root/stage0" \
		--config-musl --enable-cross
	make -j$CPUS
	make -j$CPUS install
	cd ..
else
	echo "stage0 tcc-i386 binary exists"
fi

# build a first C library which is used to build the stage 1 tcc
# against, and of course stage 0

if [ ! -f "${BASE}/root/stage0/lib/libc.a" ]; then
	rm -rf "musl-${MUSL_VERSION}"
	tar xf "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz"
	cd "musl-${MUSL_VERSION}"
	patch -Np1 < "../../../patches/musl-1.2.3-tcc.patch"
	CC="${BASE}/root/stage0/bin/i386-tcc" ./configure \
		--prefix="${BASE}/root/stage0" \
		--target=i386-linux-musl --disable-shared
	make -j$CPUS AR="${BASE}/root/stage0/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install
	cd ..
else
	echo "stage0 musl C library exists"
fi

# build tcc with tcc from stage1 against musl from stage0, it should
# have no dependencies from the host anymore

cd "${BASE}/src/stage1"

if [ ! -x "${BASE}/root/stage1/bin/i386-tcc" ]; then
	rm -rf "tinycc-${TINYCC_VERSION}"
	tar xf "${BASE}/downloads/tinycc-${TINYCC_VERSION}.tar.gz"
	cd "tinycc-${TINYCC_VERSION}"
	patch -Np1 < "../../../patches/tcc-asm.patch"
	patch -Np1 < "../../../patches/tcc-stage1.patch"
	sed -i "s|@@BASE@@|${BASE}|g" Makefile configure config-extra.mak
	sed -i "s|@@TINYCC_VERSION@@|${TINYCC_VERSION}|g" Makefile configure config-extra.mak
	./configure --enable-static --prefix="${BASE}/root/stage1" \
		--cc="${BASE}/root/stage0/bin/i386-tcc" --config-musl \
		--enable-cross
	make -j$CPUS
	make -j$CPUS install
	ln -fs tcc/i386-libtcc1.a "${BASE}/root/stage1/lib/."
	cd ..
else
	echo "stage1 tcc-i386 binary exists"
fi

# stage 1
#########

# rebuild musl with tcc from stage1

if [ ! -f "${BASE}/root/stage1/lib/libc.a" ]; then
	rm -rf "musl-${MUSL_VERSION}"
	tar xf "${BASE}/downloads/musl-${MUSL_VERSION}.tar.gz"
	cd "musl-${MUSL_VERSION}"
	patch -Np1 < "../../../patches/musl-1.2.3-tcc.patch"
	CC="${BASE}/root/stage1/bin/i386-tcc" ARCH=i386 \
	./configure \
		--prefix="${BASE}/root/stage1" \
		--target=i386-linux-musl --disable-shared
	make -j$CPUS AR="${BASE}/root/stage1/bin/i386-tcc -ar" RANLIB=echo
	make -j$CPUS install
	cd ..
else
	echo "stage1 musl C library exists"
fi

# install kernel headers (we don't think musl does any trickery to
# them or depends on them being installed)

if [ ! -d "${BASE}/root/stage1/include/linux" ]; then
	rm -rf "linux-${LINUX_KERNEL_VERSION}"
	tar xf "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz"
	cd "linux-${LINUX_KERNEL_VERSION}"
	CC=false make -j$CPUS ARCH=x86 INSTALL_HDR_PATH="${BASE}/root/stage1" headers_install
	cd ..
else
	echo "stage1 kernel headers exist"
fi

# test if the stage 1 compiler is working

if [ ! -x "${BASE}/root/stage1/bin/test-stage1" ]; then
	${BASE}/root/stage1/bin/i386-tcc -static \
		-o "${BASE}/root/stage1/bin/test-stage1" "${BASE}/tests/test-stage1.c"
	"${BASE}/root/stage1/bin/test-stage1"
	# TODO: check output, make sure we get the right thing
else
	echo "Reached working stage 1 compiler"
fi

# Now we build the rest of stage 1

if [ ! -x "${BASE}/root/stage1/bin/oksh" ]; then
	rm -rf "oksh-${_OKSH_VERSION}"
	tar xf "${BASE}/downloads/oksh-${_OKSH_VERSION}.tar.gz"
	cd "oksh-${_OKSH_VERSION}"
	CC="${BASE}/root/stage1/bin/i386-tcc" \
	./configure \
		--prefix="${BASE}/root/stage1" \
		--disable-shared --enable-static
	make -j$CPUS LDFLAGS=-static
	make -j$CPUS install
	ln -s oksh "${BASE}/root/stage1/bin/sh"
	cd ..
else
	echo "stage1 oksh exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/sbase-box" ]; then
	rm -rf "sbase-${SBASE_VERSION}"
	tar xf "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz"
	cd "sbase-${SBASE_VERSION}"
	make -j$CPUS sbase-box CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS sbase-box-install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 sbase exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/ubase-box" ]; then
	rm -rf "ubase-${UBASE_VERSION}"
	tar xf "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz"
	cd "ubase-${UBASE_VERSION}"
	patch -Np1 < "../../../patches/ubase-sysmacros.patch"
	make -j$CPUS ubase-box CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS ubase-box-install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 ubase exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/smdev" ]; then
	rm -rf "smdev-${SMDEV_VERSION}"
	tar xf "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz"
	cd "smdev-${SMDEV_VERSION}"
	patch -Np1 < "../../../patches/smdev-sysmacros.patch"
	make -j$CPUS CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 smdev exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/sinit" ]; then
	rm -rf "sinit-${SINIT_VERSION}"
	tar xf "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz"
	cd "sinit-${SINIT_VERSION}"
	cp "${BASE}/configs/sinit-config.h" config.h
	make -j$CPUS CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 smdev exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/sdhcp" ]; then
	rm -rf "sdhcp-${SDHCP_VERSION}"
	tar xf "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz"
	cd "sdhcp-${SDHCP_VERSION}"
	make -j$CPUS CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS install PREFIX="${BASE}/root/stage1"
	mv "${BASE}/root/stage1/sbin/sdhcp" "${BASE}/root/stage1/bin"
	rmdir "${BASE}/root/stage1/sbin"
	cd ..
else
	echo "stage1 sdhcp exists"
fi

# for vi
if [ ! -f "${BASE}/root/stage1/lib/libncurses.a" ]; then
	rm -rf "netbsd-curses-${NETBSD_NCURSES_VERSION}"
	tar xf "${BASE}/downloads/netbsd-curses-${NETBSD_NCURSES_VERSION}.tar.gz"
	cd "netbsd-curses-${NETBSD_NCURSES_VERSION}"
	patch -Np1 < "../../../patches/netbsd-curses-attributes.patch"
	CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS='-static' make -j$CPUS all-static
	CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS='-static' make -j$CPUS install-static \
		PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 netbsd-curses exists"
fi

# for vis
if [ ! -f "${BASE}/root/stage1/lib/libtermkey.a" ]; then
	rm -rf "libtermkey-${LIBTERMKEY_VERSION}"
	tar xf "${BASE}/downloads/libtermkey-${LIBTERMKEY_VERSION}.tar.gz"
	cd "libtermkey-${LIBTERMKEY_VERSION}"
	"${BASE}/root/stage1/bin/i386-tcc" -c termkey.c
	"${BASE}/root/stage1/bin/i386-tcc" -c driver-ti.c
	"${BASE}/root/stage1/bin/i386-tcc" -c driver-csi.c
	"${BASE}/root/stage1/bin/i386-tcc" -ar libtermkey.a termkey.o driver-ti.o driver-csi.o
	cp libtermkey.a "${BASE}/root/stage1/lib"
	cp termkey.h "${BASE}/root/stage1/include"
	cd ..
else
	echo "stage1 libtermkey exists"
fi

# for vi, tmux
if [ ! -f "${BASE}/root/stage1/lib/libevent.a" ]; then
	rm -rf "libevent-${LIBEVENT_VERSION}"
	tar xf "${BASE}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz"
	cd "libevent-${LIBEVENT_VERSION}"
	CC="${BASE}/root/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/root/stage1" \
		--enable-static --disable-shared --disable-openssl
	make -j$CPUS
	make -j$CPUS install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 libevent exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/vi" ]; then
	rm -rf "vis-${VIS_VERSION}"
	tar xf "${BASE}/downloads/vis-${VIS_VERSION}.tar.gz"
	cd "vis-${VIS_VERSION}"
	patch -Np1 < "../../../patches/vis-no-pkgconfig-for-ncurses.patch"
	LDFLAGS=-L"${BASE}/root/stage1/lib" \
	CFLAGS=-I"${BASE}/root/stage1/include" \
	CC="${BASE}/root/stage1/bin/i386-tcc"  \
	./configure --prefix="${BASE}/root/stage1" \
		--disable-lua
	make -j$CPUS LDFLAGS=-static
	cp vis "${BASE}/root/stage1/bin/vi"
	cd ..
else
	echo "stage1 vis exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/tmux" ]; then
	rm -rf "tmux-${TMUX_VERSION}"
	tar xf "${BASE}/downloads/tmux-${TMUX_VERSION}.tar.gz"
	cd "tmux-${TMUX_VERSION}"
	CC="${BASE}/root/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/root/stage1" \
		--enable-static
	make -j$CPUS LIBS="-lncursesw -levent_core -lterminfo"
	make -j$CPUS install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 tmux exists"
fi

# for mandoc
if [ ! -f "${BASE}/root/stage1/lib/libz.a" ]; then
	rm -rf "zlib-${ZLIB_VERSION}"
	tar xf "${BASE}/downloads/zlib-${ZLIB_VERSION}.tar.gz"
	cd "zlib-${ZLIB_VERSION}"
	CC="${BASE}/root/stage1/bin/i386-tcc" \
	./configure --prefix="${BASE}/root/stage1" \
		--static
	make -j$CPUS
	make -j$CPUS install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 zlib exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/man" ]; then
	rm -rf "mandoc-${MANDOC_VERSION}"
	tar xf "${BASE}/downloads/mandoc-${MANDOC_VERSION}.tar.gz"
	cd "mandoc-${MANDOC_VERSION}"
	cat >configure.local <<EOF
		PREFIX=${BASE}/root/stage1
		BINDIR=/bin
		SBINDIR=/bin
		MANDIR=/share
		CC="${BASE}/root/stage1/bin/i386-tcc"
		CFLAGS="-static -I${BASE}/root/stage1/include"
		LDFLAGS="-static -L${BASE}/root/stage1/lib"
		BINM_PAGER=more
EOF
	./configure 
	make -j$CPUS
	make -j$CPUS install DESTDIR="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 mandoc exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/abase-box" ]; then
	rm -rf "abase-${ABASE_VERSION}"
	tar xf "${BASE}/downloads/abase-${ABASE_VERSION}.tar.gz"
	cd "abase-${ABASE_VERSION}"
	make -j$CPUS abase-box CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make -j$CPUS abase-box-install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 abase exists"
fi

if [ ! -f "${BASE}/root/stage1/boot/bzImage" ]; then
	echo "Building the Linux kernel.."
	rm -rf "linux-${LINUX_KERNEL_VERSION}"
	tar xf "${BASE}/downloads/linux-${LINUX_KERNEL_VERSION}.tar.gz"
	cd "linux-${LINUX_KERNEL_VERSION}"
	echo "TODO: implement kernel building, using miniconfig.."
	# TODO:
	# tar xf linux-6.2.11.tar.xz
	# cd linux-6.2.11/
	# cp ../linux-6.2.10/.config .
	# make menuconfig
	# make -j$CPUS bzImage
	# make -j$CPUS modules
	# find . -name '*.ko' | xargs tar cvf ~/modules.tar
	false
	mkdir "${BASE}/root/stage1/boot"
	mkdir "${BASE}/root/stage1/lib/modules"
	cd ..
else
	echo "stage1 kernel exists"
fi

# floppy boot loader

if [ ! -f "${BASE}/root/stage1/boot/boot.img" ]; then
	rm -rf "uflbbl-${UFLBBL_VERSION}"
	tar xf "${BASE}/downloads/uflbbl-${UFLBBL_VERSION}.tar.gz"
	cd "uflbbl-${UFLBBL_VERSION}/src"
	nasm -o boot.img boot.asm
	cp boot.img "${BASE}/root/stage1/boot/boot.img"
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

# create boot floppies

if [ ! -f "${BASE}/floppy.img" ]; then
	touch EOF
	tar cvf data.tar -b1 bzImage ramdisk.img EOF
	cat "${BASE}/root/stage1/boot/boot.img" data.tar > "${BASE}/floppy.img"
	split -d -b 1474560 floppy.img floppy
else
	echo "floppy images exist"
fi

trap - 0

exit 0
 
