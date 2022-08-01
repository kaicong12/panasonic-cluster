#!/bin/bash

username=(
    "kctey"
    "ubuntu"
)

ip_address=(
    "192.168.1.46"
    "192.168.10.157"
)

##### Remove tasks and respective config files from this array and the one below to skip certain inference tasks #####
dataset_tasks=(
    "FLIR_det"
    "OpenImages_det"
    "OpenImages_seg"
    "SFU-HW_det"
    "TVD_det"
    "TVD_seg"
    "TVD_tracking"
)

cfg_rel_filepath=(
    ""
    "scripts/anchor.cfg"
    "scripts/anchor.cfg"
    ""
    "tvd_inference_release_v3/scripts/anchor.cfg"
    "tvd_inference_release_v3/scripts/anchor.cfg"
    "tvd_inference_release_v3/scripts/anchor_track.cfg"
)

QPS=(
    "QP_22"
    "QP_27"
    "QP_32"
    "QP_37"
    "QP_42"
    "QP_47"
)


# task assignment begins here
cur_task_idx=0
while [[ $cur_task_idx -lt ${#dataset_tasks[@]} ]]
do
    
    for user_idx in ${!username[@]};
    do
        cur_user=${username[user_idx]}
        cur_ip=${ip_address[user_idx]}

        gpu_info=$(ssh $cur_user@$cur_ip "cd /home/"${cur_user}"/Desktop && ./gpu.sh") # either returns "not available" or the list of available devices
        gpu_not_available=$(eval echo $gpu_info | grep "not available" | wc -l)  

        if [[ $gpu_not_available -gt 0 ]]
        then 
            echo "No GPU is available on this machine: "$cur_user
        else
            free_devices=$(echo $gpu_info | grep -Eo '[0-9]')
            for device in $free_devices;
            do

                echo Assigned ${dataset_tasks[cur_task_idx]} to $cur_user, running on device $device
                ssh $cur_user@$cur_ip "exec 0<&-;exec 1>&-;exec 2>&-; sleep 3 &"
                # ssh $cur_user@$cur_ip "exec 0<&-;exec 1>&-;exec 2>&-; cd <script_folder> && ./auto_inference.sh ${dataset_tasks[cur_task_idx]} ${cfg_rel_filepath[cur_task_idx]} $device"
                cur_task_idx=$(($cur_task_idx + 1))

                if [[ cur_task_idx -ge ${#dataset_tasks[@]} ]]
                then
                    break
                fi

            done
        fi
    done

done
