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

LINUX_KERNEL_VERSION="6.2.10"
TINYCC_VERSION="85b27"
MUSL_VERSION="1.2.3"
_OKSH_VERSION="7.2"
SBASE_VERSION="191f7"
UBASE_VERSION="3c887"
SMDEV_VERSION="8d075"
SINIT_VERSION="28c44"
SDHCP_VERSION="8455f"
UFLBBL_VERSION="d8680"

echo "Building in base directory '$BASE'"

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
	make
	make install
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
	make AR="${BASE}/root/stage0/bin/i386-tcc -ar" RANLIB=echo
	make install
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
	sed -i "s|@@BASE@@|${BASE}|g" Makefile configure
	./configure --enable-static --prefix="${BASE}/root/stage1" \
		--cc="${BASE}/root/stage0/bin/i386-tcc" --config-musl \
		--enable-cross
	make
	make install
	ln -fs tcc/i386-libtcc1.a "${BASE}/root/stage1/lib/."
	cd ..
else
	echo "stage1 tcc-i386 binary exists"
fi

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
	make AR="${BASE}/root/stage1/bin/i386-tcc -ar" RANLIB=echo
	make install
	cd ..
else
	echo "stage1 musl C library exists"
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
	make LDFLAGS=-static
	make install
	ln -s oksh "${BASE}/root/stage1/bin/sh"
	cd ..
else
	echo "stage1 oksh exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/sbase-box" ]; then
	rm -rf "sbase-${SBASE_VERSION}"
	tar xf "${BASE}/downloads/sbase-${SBASE_VERSION}.tar.gz"
	cd "sbase-${SBASE_VERSION}"
	make sbase-box CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make sbase-box-install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 sbase exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/ubase-box" ]; then
	rm -rf "ubase-${UBASE_VERSION}"
	tar xf "${BASE}/downloads/ubase-${UBASE_VERSION}.tar.gz"
	cd "ubase-${UBASE_VERSION}"
	patch -Np1 < "../../../patches/ubase-sysmacros.patch"
	make ubase-box CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make ubase-box-install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 ubase exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/smdev" ]; then
	rm -rf "smdev-${SMDEV_VERSION}"
	tar xf "${BASE}/downloads/smdev-${SMDEV_VERSION}.tar.gz"
	cd "smdev-${SMDEV_VERSION}"
	patch -Np1 < "../../../patches/smdev-sysmacros.patch"
	make CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 smdev exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/sinit" ]; then
	rm -rf "sinit-${SINIT_VERSION}"
	tar xf "${BASE}/downloads/sinit-${SINIT_VERSION}.tar.gz"
	cd "sinit-${SINIT_VERSION}"
	make CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make install PREFIX="${BASE}/root/stage1"
	cd ..
else
	echo "stage1 smdev exists"
fi

if [ ! -x "${BASE}/root/stage1/bin/sdhcp" ]; then
	rm -rf "sdhcp-${SDHCP_VERSION}"
	tar xf "${BASE}/downloads/sdhcp-${SDHCP_VERSION}.tar.gz"
	cd "sdhcp-${SDHCP_VERSION}"
	make CC="${BASE}/root/stage1/bin/i386-tcc" LDFLAGS=-static
	make install PREFIX="${BASE}/root/stage1"
	mv "${BASE}/root/stage1/sbin/sdhcp" "${BASE}/root/stage1/bin"
	rmdir "${BASE}/root/stage1/sbin"
	cd ..
else
	echo "stage1 sdhcp exists"
fi


cd ../..

trap - 0

exit 0
 
