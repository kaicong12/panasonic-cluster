#!/bin/bash

check_gpu_utilization="nvidia-smi --query-gpu=utilization.gpu,index --format=csv"

# returns gpu utlization in percentage
# regex to grep integer output from 0-100
gpu_utilization=$(eval $check_gpu_utilization | grep -Eo '([0-9]|[1-9][0-9]|100) %, [0-9]'| tr -d " ") 

gpu_available="not available"
avai_gpu_idx=()
for ele in $gpu_utilization;
do
    gpu=($(eval echo $ele | tr "%," "\n"))

    perc=${gpu[0]}
    gpu_idx=${gpu[1]}
    if [[ $prec -le 30 ]]; then 
        gpu_available="available"
        avai_gpu_idx+=$gpu_idx
    fi
done


echo $gpu_available $avai_gpu_idx
