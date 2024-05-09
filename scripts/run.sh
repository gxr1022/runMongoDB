#!/bin/bash


base_path=$1
RUN_PATH=$2
if [[ -z "${base_path}" ]];then
	echo "base_path is empty"
	exit
fi


if [[ -z "${RUN_PATH}" ]];then
	echo "RUN_PATH is empty"
	exit
fi

set -x

pmem_pool_path="/mnt/pmem/"
workload_path="/mnt/gxr/workloads/"
# check=true
check=false
#perf_type=real-time
perf_type=perf
#perf_type=monitor


ws=(

"READ_found       ${workload_path}/builtin/workload_INSERT-50000000.binary                     ${workload_path}/builtin/workload_READ_found-50000000.binary 50000000"

"ycsba            ${workload_path}/ycsb-a/workload_ycsb_a-30000000-30000000-load.binary        ${workload_path}/ycsb-a/workload_ycsb_a-30000000-30000000-run.binary 30000000 30000000"

"ycsbb            ${workload_path}/ycsb-b/workload_ycsb_b-30000000-30000000-load.binary        ${workload_path}/ycsb-b/workload_ycsb_b-30000000-30000000-run.binary 30000000 30000000"

"ycsbc            ${workload_path}/ycsb-c/workload_ycsb_c-30000000-30000000-load.binary        ${workload_path}/ycsb-c/workload_ycsb_c-30000000-30000000-run.binary 30000000 30000000"


# "ycsbc            ${workload_path}/ycsb-c/workload_ycsb_c-100000000-100000000-load.binary        ${workload_path}/ycsb-c/workload_ycsb_c-100000000-100000000-run.binary 100000000 100000000"

)

threads=(
	1
	2
	4
	6
	8
	10
	12
	# 20
	# 32
	# 40
)

# hs=(
# pmem_kv/client_pmem_pacman_flatstore_h
# )

hs=(
# dram_kv/client_dram_libcuckoo
# dram_kv/client_dram_unordered_map
dram_kv/client_dram_cceh
)

kv_sizes=(
	# "8 8"
	# "8 16"
	# "8 64"
	"8 256"
	# "8 1024"
	# "16 8"
	# "16 16"
	# "16 64"
	# "16 256"
	# "16 1024"
	# "32 8"
	# "32 16"
	# "32 64"
	# "32 256"
	# "32 1024"
)



LOG_PATH=${RUN_PATH}/log
EXEC_PATH=${RUN_PATH}/exec
BINARY_PATH=${RUN_PATH}/build/src/clients/

mkdir -p ${LOG_PATH}
mkdir -p ${EXEC_PATH}

echo "init ok "

pushd ${RUN_PATH}


#cmake -B build -GNinja -DCMAKE_BUILD_TYPE=Debug  ${base_path} 2>&1 | tee ./configure.log
cmake -B build -GNinja -DCMAKE_BUILD_TYPE=RelWithDebInfo  ${base_path} 2>&1 | tee ./configure.log
if [[ "$?" != 0  ]];then
	exit
fi
cmake --build build  --verbose  2>&1 | tee ./build.log
#cmake --build build --target ${hs[*]}  --verbose  2>&1 | tee ./build.log
# https://stackoverflow.com/questions/22623045/return-value-of-redirected-bash-command
if [[ "${PIPESTATUS[0]}" != 0  ]];then
	cat ${RUN_PATH}/build.log | grep --color "error"
	echo ${RUN_PATH}/build.log
	exit
fi


${RUN_PATH}/generate_patch.sh




for c in `seq 0 1 0`; do

for w in "${ws[@]}"; do

sudo bash -c "echo 1 > /proc/sys/vm/drop_caches"

for t in ${threads[*]};do

core_binding_str0=$(seq -s, 0 $((t-1)))
core_binding_str1=$(seq -s, $((0 + 12)) $((t + 11)))

load_core_binding=("$core_binding_str0" "$core_binding_str1")
# load_core_binding=("$core_binding_str1")

for l_c_b in ${load_core_binding[*]};do

cpu_node=1
if [[ "${l_c_b}" == $core_binding_str0 ]];then
	cpu_node=0
fi

for mem_node in 1 2; do

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
cmd="numactl --membind=${mem_node} \
${BINARY_PATH}/${h} \
--logtostdout \
--kv-name=${h_name} \
--workload-name=${w_name} \
--bench-type=${perf_type} \
--check=${check} \
--key-size=${key_size} \
--value-size=${value_size} \
--load_threads=${t} \
--load_trace_ops=${load_num} \
--run_threads=${t} \
--run_trace_ops=${run_num} \
--trace-type=file \
--load_trace_filename=${w_load_file} \
--run_trace_filename=${w_run_file} \
--pmem-pool-path=${pmem_pool_path} \
--load_core_binding=${l_c_b} \
--run_core_binding=${l_c_b} \
--undefok=pmem-pool-path
"


this_log_path=${LOG_PATH}/${c}.${perf_type}.${key_size}.${value_size}.${w_name}.${h_name}.${t}.${load_num}.${cpu_node}.${mem_node}.log

echo ${cmd} 2>&1 |  tee ${this_log_path}

echo ${cmd}
sleep 5
${RUN_PATH}//reset_pmem.sh
rm -rf /mnt/pmem/*
sleep 10


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
done
done
done

popd
