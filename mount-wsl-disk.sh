#!/bin/bash
# mounts wsl disk in Ubuntu

sudo modprobe nbd 

sudo qemu-nbd -c /dev/nbd0 -f vhdx /mnt/c/Users/saska/AppData/Local/Packages/CanonicalGroupLimited.Ubuntu18.04onWindows_79rhkp1fndgsc/LocalState/ext4.vhdx

sudo mount /dev/nbd0p1 /mnt/d

