#!/bin/bash

declare -A additional_params
additional_params=(
    ["FLIR"]="-c cfg/encoder_intra_vtm.cfg -fr 1 -f 1--ConformanceWindowMode=1"
    ["OpenImages"]="-c cfg/encoder_intra_vtm.cfg -fr 1 -f 1 --ConformanceWindowMode=1"
    ["SFU_HW"]="-c cfg/encoder_randomaccess_vtm.cfg --ConformanceWindowMode=1 --InternalBitDepth=10"
    ["TVD_video"]="-c cfg/encoder_randomaccess_vtm.cfg --InputBitDepth=8 --ReconFile=/dev/null --PrintHexPSNR -v 6 --ConformanceWindowMode=1"  # took out -dph 1
    ["TVD_image"]="-c cfg/encoder_intra_vtm.cfg --ConformanceWindowMode=1 --InternalBitDepth=10"
)

declare -A qp_sets
qp_sets=(
    [QP0]="22 27 32 37 42 47"  # SFU-sequence Class D, E, FLIR, OpenImages, TVD Obj_Detection, TVD Instance_Segmentation
    [QP1]="37 42 47 52 57 62"  # SFU-sequence Class A
    [QP2]="32 37 42 47 52 57"  # SFU-sequence Class B
    [QP3]="27 32 37 42 47 52"  # SFU-sequence Class C
    [QP4]="27 32 37 42 50 58"  # TVD-02 obj_tracking
)


# 2. Parse user input
mode="subset"
data_range=$(seq 8650 8660)
QP=(0 1 2 3 4 5)
if [[ $mode == "full" ]] && [[ ${#qp[@]} -ne 6 ]]; then
    echo "QP list should have exactly 6 QP when using full mode"
    echo ${#qp[@]}
    exit 1
fi
if [[ $mode != "full" ]] && [[ $mode != "subset" ]]; then
    echo "Script only accepts either 'full' or 'subset' mode"
    echo $mode
    exit 1
fi
if [[ $mode == "subset" ]] && [[ ${#data_range} == 0 ]]; then
    echo "Specify the range of data to process when in subset mode"
    exit 1
fi
for qp in ${QP[@]};
do
    if [[ $qp -gt 5 ]] || [[ $qp -lt 0 ]]; then
        echo "QP list should only contain integer from 0 to 5"
    fi
done

# for data in $data_range;
# do
#     echo "this is one element, index: $data" 
# done



# remove filtered_data_subset table left over from the previous experiment, -f tag for rm to ignore non-existent files
if [[ $mode == "subset" ]]; then

    rm -f filtered*
    num_images=$(wc -l < image_data.txt)
    for data_index in $data_range;
    do  
        # index less than num_images means the current data refers to an image, otherwise its a video file
        if [[ $data_index -le $num_images-1 ]]; then
            file="image_data.txt"
            cur_line="$(grep "^ $data_index" $file)"
            echo $cur_line >> "filtered_image_data.txt"
        else
            file="video_data.txt"
            cur_line="$(grep "^ $data_index" $file)"
            echo $cur_line >> "filtered_video_data.txt"
        fi
        
    done

fi

if [[ $mode == "subset" ]]; then
    data_files=$(ls | grep "filtered*")
else
    data_files=("image_data.txt" "video_data.txt")
fi

echo ${data_files[@]} "all elements in data file"


function check_job_status() {
    # this function determines if the job within the data_table has been sent

    dataset_name=$1
    data_name=$2
    cur_qp=$3

    encoder_log="bin_folder/$dataset_name/QP_$cur_qp/$data_name.log"
    echo $encoder_log
    if [[ -f  $encoder_log ]]; then
        echo "$encoder_log exists."
        sent=true
    fi
}

function compute_height_width() {
    
    dataset_name=$1
    data_name=$2

    if [[ $dataset_name == "OpenImages" ]]; then
        # ffprobe command only works on PNG images not YUV
        # for OpenImages dataset, we would need its PNG in the CTC dataset folder
        png_path="$dataset_name/$data_name.png"
        eval $(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=width,height $png_path)
        width=${streams_stream_0_width}
        height=${streams_stream_0_height}

    elif [[ $dataset_name == "SFU_HW" ]]; then
        height=

    elif [[ $dataset_name == "FLIR" ]]; then
        height=512
        width=640    

    elif [[ $dataset_name == "TVD" ]]; then
        height=1080
        width=1920
}

function generate_job() {
    # this function pushes new jobs which have not been sent into job_array

    data_id=$1
    data_name=$2
    qp_set=$3
    dataset_name=$4
    intra_period=$5
    frame_rate=$6
    frame_num=$7
    frame_skip=$8

    # populate qp_array
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
            echo $extra_params
                            
            # OpenImage binfiles have .266 as extension
            binfile="bin_folder/$dataset_name/QP_$qp/$data_name.vvc"
            if [[ $dataset_name == "OpenImages" ]]; then
                binfile="bin_folder/$dataset_name/QP_$qp/$data_name.266"
            fi
            # update TVD video and images to have the same dataset_name since their YUV files come from the same folder
            if [[ "$dataset_name" == *"TVD"* ]]; then
                dataset_name="TVD"
            fi
            # compute height and width of current data_name
            height=0
            width=0
            compute_height_width $dataset_name $data_name
            
            new_job="-i ../CTC_Dataset/$dataset_name/$data_name -b $binfile -q $filtered_qp -hgt $height -wdt $width $extra_params"
        fi
    
    done
}


job_array=()
for file in ${data_files[@]};
do 
    # for each line in the data.txt file, append line to job_array if this line has not been sent for compression
    while read -r line;
    do
        items=($line)

        if [[ "$file" == *"video"* ]]; then
            echo "File is a video file $file"
            data_id=${items[0]}
            data_name=${items[1]}
            qp_set=${items[2]}
            dataset_name=${items[3]}
            intra_period=${items[4]}
            frame_rate=${items[5]}
            frame_num=${items[6]}
            frame_skip=${items[7]}

            generate_job $data_id $data_name $qp_set $dataset_name $intra_period $frame_rate $frame_num $frame_skip
            
        else
            echo "File is a image file $file"
            
            data_id=${items[0]}
            data_name=${items[1]}
            qp_set=${items[2]}
            dataset_name=${items[3]}

            generate_job $data_id $data_name $qp_set $dataset_name

        fi
        
        break

    done < $file
done