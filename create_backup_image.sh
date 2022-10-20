#!/bin/bash
dd if=/dev/mmcblk0 of=2022-10-20_nistkasten.img bs=16M status=progress

losetup -P /dev/loop5 2022-10-20_nistkasten.img
zerofree /dev/loop5p2
losetup -d /dev/loop5
./pishrink.sh 2022-10-20_nistkasten.img

lrzip -Uz 2022-10-20_nistkasten.img
