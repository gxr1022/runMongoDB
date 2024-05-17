# # #!/bin/bash
set -x

# # # how to check the mongoDB status?
# # # https://stackoverflow.com/questions/5091624/is-mongodb-running

# # # --storageEngine inMemory
# # --nojournal --smallFiles --noprealloc

config_dir="/mnt/nvme0/home/gxr/mongdb-run/test_mongodb/config"

first_mode=(true false)
# first_mode=(false)

for mode in "${first_mode[@]}"; do

if [[ "$mode" == true ]];then
    echo "hello world"
	sudo mongod --config "$config_dir/mongod1.conf" --fork 
    # sudo mongod -f /mnt/nvme0/home/gxr/mongdb-run/test_mongodb/config/mongod1.conf --storageEngine inMemory
    # sudo service mongod start
    # sudo service mongod status
else
    for conf_file in "$config_dir"/*.conf; do
        if [ -f "$conf_file" ]; then
            echo "Starting MongoDB with configuration file: $conf_file" 
            sudo mongod --config "$conf_file" --fork
        fi
    done
fi

sleep 10

./run.sh $mode

sleep 5


if [[ "$mode" == true ]];then
	# sudo systemctl stop mongod
    sudo mongod --config "$config_dir/mongod1.conf" --shutdown
else
    for conf_file in "$config_dir"/*.conf; do
        sudo mongod --config "$conf_file" --shutdown
        echo "Stopped MongoDB instance using configuration: $conf_file"
    done
fi


# clear the data files of mongodb
# for ((i=1; i<=30; i++)); do
#     id+=($i)
# done

# for i in ${id[*]}; do
#     sudo rm -r /ramDisk/mongodb${i}/collection* /ramDisk/mongodb${i}/index*
# done 

done




