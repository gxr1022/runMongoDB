#!/bin/bash
for ((i=1; i<=30; i++)); do
    id+=($i)
done

for i in ${id[*]}; do
    sudo rm -rf /ramDisk/mongodb${i}
    sudo mkdir /ramDisk/mongodb${i}
done 

