#!/bin/oksh

qemu-nbd -f raw root.img -x ROOT &
sleep 2 && \
# NOTE: -kernel/-initrd is QEMU's own direct boot loader, which skips the
# kernel's real-mode setup code (arch/x86/boot/*) entirely. That means the
# BIOS video mode never gets set and vga16fb/Xfbdev will not get correct
# graphics this way (screen_info never gets populated, so sysfb won't even
# create a vga-framebuffer device). Use run_qemu.sh (real floppy/BIOS boot
# via uflbbl) to test vga16fb or Xfbdev.
qemu-system-i386 -cpu 486 -m 24M -machine isapc \
 	-kernel bzImage -initrd ramdisk.img \
 	-append	"debug loglevel=7 earlycon=vga earlycon=uart8250,io,0x3f8,9600n8 console=tty0 console=ttyS0,9600n8 iommu=off init=/init video:vesafb=off" \
	-netdev user,id=net0,net=10.0.0.0/24,host=10.0.0.2,dhcpstart=10.0.0.16,hostfwd=tcp::2222-:22,hostfwd=tcp::6001-:6000 \
	-vga std -vnc `hostname`:0 \
	-device ne2k_isa,iobase=0x300,irq=10,netdev=net0
pkill qemu-nbd
