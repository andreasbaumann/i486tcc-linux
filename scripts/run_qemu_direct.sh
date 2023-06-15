#!/bin/oksh

qemu-nbd -f raw root.img -x ROOT &
sleep 2 && \
qemu-system-i386 -cpu 486 -m 24M -machine isapc \
 	-kernel bzImage -initrd ramdisk.img \
 	-append	"debug loglevel=7 earlycon=vga earlycon=uart8250,io,0x3f8,9600n8 console=tty0 console=ttyS0,9600n8 iommu=off nomodeset init=/init" \
	-netdev user,id=net0,net=10.0.0.0/24,host=10.0.0.2,dhcpstart=10.0.0.16,hostfwd=tcp::2222-:22 \
	-device ne2k_isa,iobase=0x300,irq=10,netdev=net0
pkill qemu-nbd
