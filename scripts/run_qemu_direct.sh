#!/bin/oksh

sleep 2 && \
qemu-system-i386 -cpu 486 -m 64M \
 	-kernel bzImage -initrd ramdisk.img \
 	-append	"debug loglevel=7 earlycon=uart8250,io,0x3f8,9600n8 console=tty0 console=ttyS0,9600n8 init=/init iommu=off" \
	-netdev user,id=net0,net=10.0.0.0/24,host=10.0.0.2,dhcpstart=10.0.0.16,hostfwd=tcp::8080-:80 \
	-device ne2k_isa,iobase=0x300,irq=10,netdev=net0
