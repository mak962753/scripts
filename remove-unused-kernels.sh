#!/bin/bash

CURRENT_KERNEL=`sed -E "s/\-[a-z]+$//ig" <(uname -r)`

echo "current kernel: $CURRENT_KERNEL"

P=`dpkg --list | egrep -i --color 'linux-image|linux-headers|linux-modules' | awk '{ print $2 }' | grep -v $CURRENT_KERNEL | xargs`

if [[ -z $P ]]; then 
  echo "nothing to remove"
  exit
fi 

dpkg --list | egrep -i --color 'linux-image|linux-headers|linux-modules' | awk '{ print $2 }' | grep -v $CURRENT_KERNEL | xargs sudo apt purge -y

#echo "to remove: $OLD_PACKAGES"

#sudo apt purge -s -v $OLD_PACKAGES
