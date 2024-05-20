#!/bin/bash

# Initialize the array with the first element as 1
threads=(1)

# Generate subsequent elements by adding 2 to the previous element
for ((i = 1; i <= 127; i += 2)); do
    threads+=($i)
done

# Print the array to verify
echo "Threads array:"
for thread in "${threads[@]}"; do
    echo $thread
done
