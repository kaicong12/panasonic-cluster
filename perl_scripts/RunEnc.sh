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


# 3. Parse user input
mode
data_range=
qp=[0,1,2,3,4,5]

if mode == "full":
    qp = [0,1,2,3,4,5]

##### Functions #####
1. get_data_type() -> Array(2)
2. filter_job(mode, type, data_range) -> returns [str]
3. create_job_array(data_table_subset, qp) -> append str to job_array
    3.1 read every element within data_table_subset, for each element: 
    3.2 get_resolution(dataset_name, filename) 
        3.1.1 Dataset with same resolution throughout -> read from dictionary
        3.1.2 dataset with resolution on name (e.g. SFU) -> split by "x" and read integer before and after
        3.1.3 Each file under dataset has different res. , read res using ffprobe  ## need to assume cluster have FFMPEG3





job_array=()
for datatype in "${data_types[@]}"
do
   filter_job $mode $datatype $data_range
   create_job_array $data_subset_table $qp
done

echo $job_array # check the constructed job_array

dataset_directory="CTC_YUV" # directory where the raw YUVs are stored in
test_folder=$(realpath ./) # get the absolute path of the shared network test_folder

sendTask() {
    task_command=$1
    ssh $avai_pc_ip $test_folder/RunOne.sh -p $task_command # send the task comand to the available pc
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

# ## task: object, structure: video%name%qp_value%intra_period%frame_rate%frames_num%frame_skip%dataset_dir%additional_param (-dph 1...)
# job_array=() # element; element.name; 
# for datatype in data_types:
#     data_subset_table = filter_job(mode, datatype, data_range=None)
#     job_array.append(create_job_array(data_subset_table, qp))

# echo job_array # contains a list of objects (either video or image objects)

# dataset_diretory = "CTC"
# sendTask(task_object)
#     if task_object.type == "video":
#         file_path = os.patj.join(dataset_diretory, task_object.name)
#         parameters = "-i $file_path -qp ${task_object.qp} $additional_parameter"
#         ssh ... ./RunOne.sh -p "parameters"
#     else:
#         ./RunOne.sh -i -b -o

# counter = 0
# while counter < len(job_array) {
#     request_count = 0

#     while True:
#         sleep(2)

#         for pc in client_pc:
#             available = check_if_available(pc)
#             if available:
#                 $avai_pc_ip = $pc
#                 break [2]
        
#         request_count += 1

#         if request_count >= 10:
#             break [2]

#     sendTask(job_array[counter])
#     counter += 1

#     if not exist (start.tim):
#         create the file                      
# }

# if counter == len(job_array):
#     create done.time
# else:
#     raise ("some task is not sent successfully")  # should never get triggered



