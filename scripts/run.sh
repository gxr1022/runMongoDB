#!/bin/bash
mode=$1
current=`date "+%Y-%m-%d-%H-%M-%S"`
base_path="/mnt/nvme0/home/gxr/mongdb-run"
RUN_PATH="/mnt/nvme0/home/gxr/mongdb-run/test_mongodb"

# set -x

workload_path="/mnt/nvme0/home/gxr/mongdb-run/workloads"

ws=(

"ycsba    ${workload_path}/ycsb/workloada-load-1000000-1000000.log.formated        ${workload_path}/ycsb/workloada-run-1000000-1000000.log.formated 1000000 1000000"
# "ycsba    ${workload_path}/ycsb/workloada-load-100000-100000.log.formated        ${workload_path}/ycsb/workloada-run-100000-100000.log.formated 100000 100000"
)

threads=(
	1
	5
	10
	15
	20
	25
	30
)


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

LOG_PATH=${RUN_PATH}/log/${current}.${first_mode}
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

sudo bash -c "echo 1 > /proc/sys/vm/drop_caches"

for t in ${threads[*]};do

thread_binding_seq="0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143"


uri_set="mongodb://localhost:27017"
for ((port=27018; port<=27046; port++)); do
    uri_set+=",mongodb://localhost:$port"
done

echo "$uri_set"




for kv_size in "${kv_sizes[@]}";do

kv_size_array=( ${kv_size[*]} )
key_size=${kv_size_array[0]}
value_size=${kv_size_array[1]}

for h in ${hs[*]};do


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


this_log_path=${LOG_PATH}/${h_name}.${t}.thread.${key_size}.${value_size}.${w_name}.${load_num}.${run_num}.log

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

done
done
done
done
# done


popd
