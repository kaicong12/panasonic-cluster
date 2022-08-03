#!/bin/bash

# 1. Create all necessary information to parse user input
# 2. Parse user input
# 3. Iterate through each row in the data table if user selected subset mode
# 4. Generate job_array from either data.txt or filtered_data.txt
# 5. Distribute each task within job_array to different client pc for compression


# 1. Create all necessary information to parse user input
declare -A qp_sets
qp_sets=(
    [QP0]="22 27 32 37 42 47"  # SFU-sequence Class D, E, FLIR, OpenImages, TVD Obj_Detection, TVD Instance_Segmentation
    [QP1]="37 42 47 52 57 62"  # SFU-sequence Class A
    [QP2]="32 37 42 47 52 57"  # SFU-sequence Class B
    [QP3]="27 32 37 42 47 52"  # SFU-sequence Class C
    [QP4]="27 32 37 42 50 58"  # TVD-02 obj_tracking
)

declare -A additional_params
additional_params=(
    ["FLIR"]="-c cfg/encoder_intra_vtm.cfg -fr 1 -f 1--ConformanceWindowMode=1"
    ["OpenImages"]="-c cfg/encoder_intra_vtm.cfg -fr 1 -f 1 --ConformanceWindowMode=1"
    ["SFU_HW"]="-c cfg/encoder_randomaccess_vtm.cfg --ConformanceWindowMode=1 --InternalBitDepth=10"
    ["TVD_video"]="-c cfg/encoder_randomaccess_vtm.cfg --InputBitDepth=8 --ReconFile=/dev/null --PrintHexPSNR -v 6 --ConformanceWindowMode=1"  # took out -dph 1
    ["TVD_image"]="-c cfg/encoder_intra_vtm.cfg --ConformanceWindowMode=1 --InternalBitDepth=10"
)



# 2. Parse user input
mode="full"
data_range=()
QP=(0 1 2 3 4 5)

# user input validation
if [[ $mode == "full" ]] && [[ ${#qp[@]} -ne 6 ]]; then
    echo "QP list should have exactly 6 QP when using full mode"
    exit 1
fi
if [[ $mode != "full" ]] || [[ $mode != "subset" ]]; then
    echo "Script only accepts either 'full' or 'subset' mode"
    exit 1
fi
if [[ $mode == "subset" ]] && [[ ${#data_range} == 0 ]]; then
    echo "Specify the range of data to process when in subset mode"
    echo "e.g. data_range=(seq 0 15) to run compression on data with data_id between 0 to 15" 
    exit 1
fi
for qp in ${QP[@]};
do
    if [[ $qp -gt 5 ]] || [[ $qp -lt 0 ]]; then
        echo "QP list should only contain integer from 0 to 5"
    fi
done



# 3. Iterate through each row in the data table if user selected subset mode
if [[ $mode == "subset" ]]; then

    rm -f filtered*
    num_images=$(wc -l < ../gen_data_table/image_data.txt)
    for data_index in $data_range;
    do  
        # index less than num_images means the current data refers to an image, otherwise its a video file
        if [[ $data_index -le $num_images-1 ]]; then
            file="../gen_data_table/image_data.txt"
            cur_line="$(grep "^ $data_index" $file)"
            echo $cur_line >> "filtered_image_data.txt"
        else
            file="../gen_data_table/video_data.txt"
            cur_line="$(grep "^ $data_index" $file)"
            echo $cur_line >> "filtered_video_data.txt"
        fi
        
    done

fi



# 4. Generate job_array from either data.txt or filtered_data.txt
function check_job_status() {
    # this function determines if the job within the data_table has been sent

    dataset_name=$1
    data_name=$2
    qp=$3

    encoder_log="bin_folder/$dataset_name/QP_$qp/$data_name.log"
    if [[ -f  $encoder_log ]]; then
        echo "$encoder_log exists."
        sent=true
    fi
}

function generate_job() {
    # this function pushes new jobs which have not been sent into job_array

    data_id=$1
    data_name=$2
    qp_set=$3
    dataset_name=$4
    width=$5
    height=$6
    intra_period=$7
    frame_rate=$8
    frame_num=$9
    frame_skip=$10

    # populate qp_array according to index specified by user (each task may use different qp_set)
    qp_array=(${qp_sets[$qp_set]})
    filtered_qp_array=()
    for index in ${QP[@]};
    do
        filtered_qp_array+=(${qp_array[$index]})
    done
    
    # check if this job has been sent
    for filtered_qp in $filtered_qp_array;
    do

        sent=false
        # this function will update sent to true if this job has been sent
        check_job_status $dataset_name $data_name $filtered_qp
        if [[ $sent = false ]]; then
            extra_params=${additional_params["$dataset_name"]}
                            
            # OpenImage binfiles have .266 as extension
            binfolder="bin_folder/$dataset_name/QP_$qp"
            binfile="$binfolder/$data_name.vvc"
            if [[ $dataset_name == "OpenImages" ]]; then
                binfile="$binfolder/$data_name.266"
            fi
            # update TVD video and images to have the same dataset_name since their YUV files come from the same folder
            if [[ "$dataset_name" == *"TVD"* ]]; then
                dataset_name="TVD"
            fi
            new_job=-1
            # new_job differs for image and video, differentiate these 2 by checking the number of input arguments
            if [ "$#" -eq 6 ]; then
                # arguments equals to 6 means it is a image job
                new_job="-i ../CTC_Dataset/$dataset_name/$data_name.yuv -b $binfile -q $filtered_qp -hgt $height -wdt $width $extra_params%$binfolder%$data_name.log"
            elif [ "$#" -eq 10 ]; then
                # arguments equals to 10 means it is a video job
                new_job="-i ../CTC_Dataset/$dataset_name/$data_name.yuv -b $binfile -q $filtered_qp -hgt $height -wdt $width --FrameSkip=$frame_skip --FramesToBeEncoded=$frame_num --IntraPeriod=$intra_period --FrameRate=$frame_rate $extra_params%$binfolder%$data_name.log"
            fi

            # sanity check to see if new_job is initialized properly
            if [[ $new_job == -1 ]]; then
                echo "Job $data_id is not initialized properly, please try again"
                exit 1
            else
                job_array+=($new_job)
            fi
        fi
    
    done
}

job_array=()
# determine if cluster should create job_array based on full data.txt or filtered_data.txt depending on mode
if [[ $mode == "subset" ]]; then
    data_files=$(ls | grep "filtered*")
else
    data_files=("image_data.txt" "video_data.txt")
fi
for file in ${data_files[@]};
do 
    # for each line in the data.txt or filtered_data.txt file, append line to job_array if this line has not been sent for compression
    while read -r line;
    do

        items=($line)
        data_id=${items[0]}
        data_name=${items[1]}
        qp_set=${items[2]}
        dataset_name=${items[3]}
        width=${items[4]}
        height=${items[5]}

        if [[ "$file" == *"video"* ]]; then
            echo "File is a video file $file"
            
            # video data have more parameters than image data
            intra_period=${items[6]}
            frame_rate=${items[7]}
            frame_num=${items[8]}
            frame_skip=${items[9]}

            # check if this job has been sent and send if it hasnt
            generate_job $data_id $data_name $qp_set $dataset_name $width $height $intra_period $frame_rate $frame_num $frame_skip
            
        else
            echo "File is a image file $file"

            # check if this job has been sent and send if it hasnt
            generate_job $data_id $data_name $qp_set $dataset_name $width $height

        fi
        
    done < $file
done



# 5. Distribute each task within job_array to different client pc for compression
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