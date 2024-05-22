#!/bin/bash
# mode=$1
# mode=false

sudo /mnt/nvme0/home/gxr/mongdb-run/test_mongodb/scripts/clear_ramdisk.sh


config_dir="/mnt/nvme0/home/gxr/mongdb-run/test_mongodb/config"


current=`date "+%Y-%m-%d-%H-%M-%S"`
base_path="/mnt/nvme0/home/gxr/mongdb-run"
RUN_PATH="/mnt/nvme0/home/gxr/mongdb-run/test_mongodb"

set -x

workload_path="/mnt/nvme0/home/gxr/mongdb-run/workloads"




workload_path="/mnt/nvme0/home/gxr/mongdb-run/workloads"

first_mode=(true false)

# first_mode=(false)

ws=(
"ycsba    ${workload_path}/ycsb/workloada-load-10000000-10000000.log.formated        ${workload_path}/ycsb/workloada-run-10000000-10000000.log.formated 10000000 10000000"
# "ycsba    ${workload_path}/ycsb/workloada-load-1000000-1000000.log.formated        ${workload_path}/ycsb/workloada-run-1000000-1000000.log.formated 1000000 1000000"
# "ycsba    ${workload_path}/ycsb/workloada-load-5000000-5000000.log.formated        ${workload_path}/ycsb/workloada-run-5000000-5000000.log.formated 5000000 5000000"
# "ycsba    ${workload_path}/ycsb/workloada-load-50000000-50000000.log.formated        ${workload_path}/ycsb/workloada-run-50000000-50000000.log.formated 50000000 50000000"
# "ycsba    ${workload_path}/ycsb/workloada-load-100000-100000.log.formated        ${workload_path}/ycsb/workloada-run-100000-100000.log.formated 100000 100000"
)

# threads=(
# 	1
# 	2
# 	4
# 	6
# 	8
# 	10
# 	12
# 	14
# 	16
# 	18
# 	20
# 	22
# 	24
# )

threads=(1)
# Generate subsequent elements by adding 2 to the previous element
for ((i = 4; i <= 128; i += 4)); do
    threads+=($i)
done

# threads=(125)

hs=(
run_client
)

kv_sizes=(
	# "16 16"
	# "16 64"
	"16 256"
	# "16 1024"
)

# first_mode=(true false) 

LOG_PATH=${RUN_PATH}/log/${current}
BINARY_PATH=${RUN_PATH}/build/

mkdir -p ${LOG_PATH}

echo "init ok "

pushd ${RUN_PATH}

cmake -B ${BINARY_PATH} -DCMAKE_BUILD_TYPE=Release ${RUN_PATH}  2>&1 | tee ${RUN_PATH}/configure.log
if [[ "$?" != 0  ]];then
	exit
fi
cmake --build ${BINARY_PATH}  --verbose  2>&1 | tee ${RUN_PATH}/build.log

if [[ "${PIPESTATUS[0]}" != 0  ]];then
	cat ${RUN_PATH}/build.log | grep --color "error"
	echo ${RUN_PATH}/build.log
	exit
fi

# for mode in "${first_mode[@]}"; do

for w in "${ws[@]}"; do

# sudo bash -c "echo 1 > /proc/sys/vm/drop_caches"

for t in ${threads[*]};do

config_array=()
for ((port=1; port<=t; port++)); do
    config_array+=("${config_dir}/mongod${port}.conf")
done
 

thread_binding_seq="0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191"
# thread_binding_seq="0,1,2,3,4,5,6,7,8,9,10,11,24,25,26,27,28,29,30,31,32,33,34,35"


uri_set="mongodb://localhost:27017"
for ((port=27018; port<=27144; port++)); do
    uri_set+=",mongodb://localhost:$port"
done

echo "$uri_set"




for kv_size in "${kv_sizes[@]}";do

kv_size_array=( ${kv_size[*]} )
key_size=${kv_size_array[0]}
value_size=${kv_size_array[1]}

for h in ${hs[*]};do


for mode in "${first_mode[@]}"; do

sudo bash -c "echo 1 > /proc/sys/vm/drop_caches"


if [[ "$mode" == true ]];then
    echo "hello world"
	sudo mongod --config "$config_dir/mongod1.conf" --fork 
    # sudo mongod -f /mnt/nvme0/home/gxr/mongdb-run/test_mongodb/config/mongod1.conf --storageEngine inMemory
    # sudo service mongod start
    # sudo service mongod status
else
	i=0
    for conf_file in "${config_array[@]}"; do
        if [ -f "$conf_file" ] && [ $i -lt $t ]; then
            echo "Starting MongoDB with configuration file: $conf_file" 
            sudo mongod --config "$conf_file" --fork
			i=$((i+1))
		else
			break
        fi
    done
fi


w_array=( ${w} )


w_name=${w_array[0]}
w_load_file=${w_array[1]}
w_run_file=${w_array[2]}
load_num=${w_array[3]}
run_num=${w_array[3]}


h_name=$(basename ${h})

# cmd="numactl --cpunodebind=1 --membind=2 \

# threads run on numa0, using memory on NUMA4
cmd="numactl --membind=4 \
${BINARY_PATH}/${h} \
--num_threads=${t} \
--core_binding=${thread_binding_seq} \
--str_key_size=${key_size} \
--str_key_size=${value_size} \
--load_file=${w_load_file} \
--run_file=${w_run_file}  \
--URI_set=${uri_set} \
--first_mode=${mode}
"


this_log_path=${LOG_PATH}/${h_name}.${t}.thread.${mode}.${key_size}.${value_size}.${w_name}.${load_num}.${run_num}.log

echo ${cmd} 2>&1 |  tee ${this_log_path}

# echo ${cmd}
sleep 5


# monitor need sudo

# gdbserver :1234 \
# sudo \
timeout -v 3600 \
stdbuf -o0 \
${cmd} 2>&1 |  tee -a ${this_log_path}
echo log file in : ${this_log_path}
sleep 10



if [[ "$mode" == true ]];then
	# sudo systemctl stop mongod
    sudo mongod --config "$config_dir/mongod1.conf" --shutdown
else
	i=0
    for conf_file in "${config_array[@]}"; do
		if [ -f "$conf_file" ] && [ $i -lt $t ]; then
            sudo mongod --config "$conf_file" --shutdown
        	echo "Stopped MongoDB instance using configuration: $conf_file"
			i=$((i+1))
		else
			break
        fi
    done
fi

sudo /mnt/nvme0/home/gxr/mongdb-run/test_mongodb/scripts/clear_ramdisk.sh

done
done
done
done
done


popd
