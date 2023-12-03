#!/bin/sh

[1]-  Running                 86Box &
[2]+  Running                 qemu-nbd -f raw root.img -x ROOT &

qemu-nbd -f raw root.img -x ROOT &
sleep 2 && \
86Box -C scripts/86box.cfg
pkill qemu-nbd
