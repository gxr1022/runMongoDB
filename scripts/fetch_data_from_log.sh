#! /bin/bash

set -x

cur_date=$1

logs_folder="/home/gxr/mongodb-run/test_mongodb/log/$cur_date"
csv_folder="/home/gxr/mongodb-run/test_mongodb/data/$cur_date"



mkdir -p "$csv_folder"

csv_file="$csv_folder/${cur_date}_result.csv"
echo "mode,thread_number,load_operations,run_operations,key_size(B),value_size(B),overall_throughput(IOPS),average_latency(ns)" > "$csv_file"


for logfile in "$logs_folder"/*.log; do
    #Extract filename from path
    logname=$(basename "$logfile")
    
    
    overall_throughput=$(grep "load_overall_throughput" "$logfile" | awk '{print $4}')
    average_latency=$(grep "load_overall_average_latency_ns" "$logfile" | awk '{print $4}')

    key_size=$(echo "$logname" | cut -d '.' -f 5)
    value_size=$(echo "$logname" | cut -d '.' -f 6)
    thread_number=$(echo "$logname" | cut -d '.' -f 2)
    load_operations=$(echo "$logname" | cut -d '.' -f 8)
    run_operations=$(echo "$logname" | cut -d '.' -f 9)
    mode=$(echo "$logname" | cut -d '.' -f 4)

    echo "$mode,$thread_number,$load_operations,$run_operations,$key_size,$value_size,$overall_throughput,$average_latency" >> "$csv_file"

done