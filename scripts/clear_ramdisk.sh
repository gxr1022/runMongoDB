#!/bin/bash
for ((i=1; i<=48; i++)); do
    id+=($i)
done

for i in ${id[*]}; do
    # sudo rm -r /mnt/nvme0/home/gxr/mongdb-run/ramDisk/mongodb${i}
    # sudo mkdir -p /mnt/nvme0/home/gxr/mongdb-run/ramDisk/mongodb${i}
    sudo rm -r /home/gxr/mongodb-run/ramDisk/mongodb${i}
    sudo mkdir -p /home/gxr/mongodb-run/ramDisk/mongodb${i}
done 

