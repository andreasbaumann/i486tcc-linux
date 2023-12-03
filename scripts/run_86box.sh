#!/bin/sh

qemu-nbd -f raw root.img -x ROOT &
sleep 2 && \
86Box -C scripts/86box.cfg
pkill qemu-nbd
