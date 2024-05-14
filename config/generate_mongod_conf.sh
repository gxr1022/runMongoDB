#!/bin/bash

num_files=30

start_port=27017

for ((i=1; i<=$num_files; i++)); do

    conf_file="mongod${i}.conf"
    port=$((start_port + i - 1))
    cat <<EOF > $conf_file
systemLog:
  destination: file
  path: "/var/log/mongodb/mongod${i}.log"
  logAppend: true
storage:
  dbPath: "/var/lib/mongodb${i}"
  journal:
    enabled: true
net:
  port: $port
  bindIp: 127.0.0.1
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
EOF

    echo "Generated $conf_file,端口号为 $port"
done
