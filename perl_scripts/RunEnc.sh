#!/bin/bash

client_pc=("pc0:ubuntu@192.168.1.222" "pc1:user@192.168.1.17" "pc2:ubuntu@192.168.1.130")
# 1. Create all necessary information to parse user input
# 2. Iterate through each row in the data table
# 3. Parse user input


# 1. Create all necessary information to parse user input
declare -A qp_sets
qp_sets=(
    [0]="22 27 32 37 42 47"  # SFU-sequence Class D, E, FLIR, OpenImages, TVD Obj_Detection, TVD Instance_Segmentation
    [1]="37 42 47 52 57 62"  # SFU-sequence Class A
    [2]="32 37 42 47 52 57"  # SFU-sequence Class B
    [3]="27 32 37 42 47 52"  # SFU-sequence Class C
    [4]="27 32 37 42 50 58"  # TVD-02 obj_tracking
)

declare -A additional_params
additional_params=(
    ["FLIR"]="-fr 1 -f 1--ConformanceWindowMode=1"
    ["OpenImages"]="-fr 1 -f 1 --ConformanceWindowMode=1"
    ["SFU_HW"]=
    ["TVD_video"]
    ["TVD_image"]
)


# 2. Iterate through each row in the data table
while read -r line;
do
    items=($line)

    data_id=${items[0]}
    data_name=${items[1]}
    qp_set=${items[2]}
    dataset_name=${items[3]}

    echo $data_id $data_name $qp_set $dataset_name
    break

done < data.txt


dataset_directory="CTC_YUV" # directory where the raw YUVs are stored in
test_folder=$(realpath ./) # get the absolute path of the shared network test_folder

function sendTask() {
    task=$1 # <command>%<bin_location>%<log_name>
    IFS='%' read -ra task_info <<< "$task" # split the task string with delimiter %
    command=${task_info[0]} 
    bin_location=${task_info[1]} 
    log_name=${task_info[2]} 
    echo $command
    echo $bin_location
    echo $log_name
    mkdir -p $bin_location # create the bin_dir recursively
    echo ./encoder ${command} >> ${bin_location}/${log_name} # write the encoding command into encoder log

    ssh $avai_pc_ip cd $test_folder # let the client machine goes to the shared network test_folder
    ssh $avai_pc_ip RunOne.sh -p $task_command >> ${bin_location}/${log_name} # from the client, run the RunOne.sh with given command to start the compression
}

counter=0 # the number of jobs sent to the clients
# echo ${#job_array[@]}
while [ $counter -lt ${#job_array[@]} ] # main while loop
do
    request_count=0
    while true # busy waiting for the available client pc
    do
        sleep 2 # request for available client pc every 2 sec
        for pc in "${client_pc[@]}"
        do  
            pc_info=(${pc//:/ }) # split the pc information
            pc_name=${pc_info[0]} 
            pc_ip=${pc_info[1]} 
            check_if_available $pc_name $pc_ip
            if [ "$available" = true ] # $available comes from check_if_available()
            then
                echo "Assigned to ${pc_name}"
                avai_pc_ip=$pc_ip
                break[2] # break current for loop and the busy waiting while loop outside, back to the main while loop
            fi
        done

        request_count=$(( $request_count + 1 ))
        if [ $request_count -ge 10]
        then
            break[2] # quit the main while loop if wait for more than 20 sec for the machine
        fi
    done

    echo counter is $counter
    echo ${job_array[counter]} # for debugging: check current task command

    sendTask ${job_array[counter]}
    if [[ ! -f "start.tim" ]]
    then
        touch start.tim
    fi
    counter=$(( $counter + 1 )) # move to next task
done

if [ $counter -eq ${#job_array[@]} ]
then
    touch done.tim # all files have been sent to clients for compression
else
    echo "Some task is not sent successfully." # should never be triggered
fi