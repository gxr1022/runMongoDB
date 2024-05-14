#!/bin/bash
set -x

config_dir="/mnt/nvme0/home/gxr/mongdb-run/test_mongodb/config/"

# first_mode=(true false)
first_mode=(false)

for mode in "${first_mode[@]}"; do

if [[ "$mode" == true ]];then
    echo "hello world"
	sudo /usr/bin/mongod --config "$config_dir/mongod2.conf" --storageEngine inMemory &
    # sudo service mongod status
else
    for conf_file in "$config_dir"/*.conf; do
        if [ -f "$conf_file" ]; then
            echo "Starting MongoDB with configuration file: $conf_file"
            sudo /usr/bin/mongod --config "$conf_file" --storageEngine inMemory &
        fi
    done
fi

./run.sh $mode

sleep 5

if [[ "$mode" == true ]];then
	# sudo systemctl stop mongod
    sudo /usr/bin/mongod --config "$config_dir/mongod2.conf" --shutdown
else
    for conf_file in "$config_dir"/*.conf; do
        sudo /usr/bin/mongod --config "$conf_file" --shutdown
        echo "Stopped MongoDB instance using configuration: $conf_file"
    done
fi

done




