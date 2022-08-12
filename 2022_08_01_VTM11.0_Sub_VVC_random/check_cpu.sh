#!/bin/bash

pc_name=$1
pc_ip=$2

average=$(ssh $pc_name@$pc_ip "sar 1 1 | grep Average")
cpu_idle_perc=${average: -6}

# correct way to compare 2 floats in bash
larger_than_fifty=$(echo "$cpu_idle_perc>50" | bc)
if [[ $larger_than_fifty -eq 1 ]]; then
    available=true
else
    available=false
fi

echo $available