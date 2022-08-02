#!/bin/bash

# 1. Create all necessary information to parse user input
# 2. Parse user input
# 3. Iterate through each row in the data table


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



# 4. Generate job_array
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

job_array=()
for file in ${data_files[@]};
do 
    
    while read -r line;
    do
        items=($line)

        if [[ "$file" == *"video"* ]]; then
            echo "File is a video file $file"
            data_id=${items[0]}
            data_name=${items[1]}
            qp_set=${items[2]}
            intra_period=${items[3]}
            frame_rate=${items[4]}
            frame_num=${items[5]}
            frame_skip=${items[6]}
            dataset_name=${items[7]}

            check_job_status $data_name "22"

            echo $data_id $data_name $qp_set $intra_period $frame_rate $frame_num $frame_skip $dataset_name

            # ignore jobs which have been sent for compression
        else
            echo "File is a image file $file"
            
            data_id=${items[0]}
            data_name=${items[1]}
            qp_set=${items[2]}
            dataset_name=${items[3]}

            echo $data_id $data_name $qp_set $dataset_name
        fi
        
        break

    done < $file
done


##### Functions #####
1. get_data_type() -> Array(2)
2. filter_job(mode, type, data_range) -> returns [str]
3. create_job_array(data_table_subset, qp) -> append str to job_array
    3.1 read every element within data_table_subset, for each element: 
    3.2 get_resolution(dataset_name, filename) 
        3.1.1 Dataset with same resolution throughout -> read from dictionary
        3.1.2 dataset with resolution on name (e.g. SFU) -> split by "x" and read integer before and after
        3.1.3 Each file under dataset has different res. , read res using ffprobe  ## need to assume cluster have FFMPEG3


## task: object, structure: video%name%qp_value%intra_period%frame_rate%frames_num%frame_skip%dataset_dir%additional_param (-dph 1...)
job_array=() # element; element.name; 
for datatype in data_types:
    data_subset_table = filter_job(mode, datatype, data_range=None)
    job_array.append(create_job_array(data_subset_table, qp))

echo job_array # contains a list of objects (either video or image objects)

dataset_diretory = "CTC"
test_folder = "(realpath ./)"
sendTask(task_object)
    job_array = ["-i CTC_dataset/FLIR/FLIR0891.yuv -b bin_folder/FLIR/QP_22/FLIR0891.vvc -c -c cfg/encoder_intra_vtm.cfg -fr 1 -f 1--ConformanceWindowMode=1%20bin_folder/dataset_name/QP_22%20FLIR0891.log"]
    for ele in job_array:
        ssh $pc $test_folder/RunOne.sh -p $ele

    if task_object.type == "video":
        log_file=job_obj.split(%20)[2]
        file_path = os.patj.join(dataset_diretory, task_object.name)
        parameters = "-i $file_path -qp ${task_object.qp} $additional_parameter"
        echo "encoder job_obj.split(%20)[0]" >> log_file
        ssh ... ./RunOne.sh -p "parameters" >> log_file

counter = 0
while counter < len(job_array) {
    request_count = 0

    while True:
        sleep(2)

        for pc in client_pc:
            available = check_if_available(pc)
            if available:
                $avai_pc_ip = $pc
                break [2]
        
        request_count += 1

        if request_count >= 10:
            break [2]

    sendTask(job_array[counter])
    counter += 1

    if not exist (start.tim):
        creeate the file                      
}

if counter == len(job_array):
    create done.time
else:
    raise ("some task is not sent successfully")  # should never get triggered



