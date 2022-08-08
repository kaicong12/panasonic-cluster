# VVC AutoEnvironment Cluster Script 

# How to run a custom test
1. Decide on a custom name for the new custom test. (e.g. `2022_08_01_VTM11.0_Sub_VVC_random`)
2. Create a new folder under directly at the root using the custom name.
3. Copy the necessary files/folder into the new folder, files to be copied are listed at the [Directories Definition](#directories-definition) section.
4. Open up `job_list.txt` and key in the name of this new test, tests in `job_list.txt` will be executed from top to bottom, so user may place the test with a higher priority on top
5. Go to `RunEnc.sh` within the test folder to key in the specific inputs for this new test, available user inputs are `QPs`, `data_range` and `mode`, the explanation for each input is specified under the [Cluster Script Logic](#cluster-script-logic) section.
6. Execute `./job_list.sh` from the terminal, give it executable permission if required `chmod u+x ./job_list.sh`


# RunEnc.sh
## Directories Definition
All files needed to run a specific test are to be manually copied over by user as user creates the new test_folder (in this case `2022_08_01_VTM11.0_Sub_VVC_random`)  and place directly under the new test folder

Files/Folders to be copied over are:  
- `cfg_folder`
- `check_cpu.sh`
- `image_data.txt`
- `video_data.txt`
- `RunEnc.sh`
- `RunOne.sh`  
```
    ├── 2022_08_01_VTM11.0_Sub_VVC_random  -> test name for a specific test
    │   ├── image_data.txt
    │   ├── video_data.txt
    │   ├── check_cpu.sh
    │   ├── RunEnc.sh
    │   ├── RunOne.sh
    │   ├── cfg_folder
    │   │   └── encoder_intra_vtm.cfg
    │   │   └── encoder_randomaccess_vtm.cfg
    │   └── bin_folder  -> will be created by the script
    │       └── TVD
    │           └── QP_22
``` 

*Note that **`bin_folder`** stores both the compressed binfile and encoder log which signifies that the data has been sent. The binfiles and encoder logfiles are categorized by dataset name and QP.  
<br>

## Cluster Script Logic
1. Read user input
    - **`mode`**: either "full" or "subset"
    - **`data_range`**: a list of integers indicating which subset of data_id to run compression on if `mode` selected is `subset`
    - **`qp`**: a list of integer between 0 to 5 indicating which QP to compress the data on

2. Filter out selected data_id if user specified "subset" mode (new data table `filtered_image_data.txt` and `filtered_data_data.txt` table will be generated for this test)

3. Generate `job_array` from either data.txt or filtered_data.txt (Detailed logic described below)

4. Distribute each task within job_array to different client pc for compression
    
### Generate Job Array
The create job array function consists of 2 parts, first is to read through either the `filtered_image_data.txt` and `filtered_video_data.txt` or the `image_data.txt` and `video_data.txt` depending on the mode for the test. 
- If user chooses to run the test on `subset` mode, the script would read through `filtered_image_data.txt` and `filtered_video_data.txt`. 
- Otherwise if user chooses to run the test on `full` mode, the script would read through `image_data.txt` and `video_data.txt` instead.

Code to read through each line are as below:
<details>
  <summary><b>Click to view detailed code to read through the data table</b></summary>

```shell
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
            # video data have more parameters than image data
            intra_period=${items[6]}
            frame_rate=${items[7]}
            frame_num=${items[8]}
            frame_skip=${items[9]}

            # check if this job has been sent and send if it hasnt
            generate_job $data_id $data_name $qp_set $dataset_name $width $height $intra_period $frame_rate $frame_num $frame_skip
            
        else
            # check if this job has been sent and send if it hasnt
            generate_job $data_id $data_name $qp_set $dataset_name $width $height

        fi
        
    done < $file
done
```

</details>

The second part of generating job_array is to actually generate the job array using the data table produced from the previous step. For each job, the script would generate one task for every qp to compress the same data on. One examplary task would be as follow:  
`"-i $yuvfolder/$data_name.yuv -b $binfile -q $qp -hgt $height -wdt $width --FrameSkip=$frame_skip --FramesToBeEncoded=$frame_num --IntraPeriod=$intra_period --FrameRate=$frame_rate $extra_params%$binfolder%$data_name.log"`  
Each task represents a command to be run by the Encoder on a specific QP and this task will be sent to `RunOne.sh` for encoding. (Details specified under the [RunOne.sh](#runonesh) section)

Code to generate job_array are as below:
<details>
  <summary><b>Click to view code to generate job_array</b></summary>

```shell
job_array=()  # initialize a global job_array variable
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
    for filtered_qp in ${filtered_qp_array[@]};
    do

        sent=false
        # this function will update sent to true if this job has been sent
        check_job_status $dataset_name $data_name $filtered_qp
        if [[ $sent = false ]]; then
            extra_params=${additional_params["$dataset_name"]}
                            
            # update TVD video and images to have the same dataset_name since their YUV files come from the same folder
            if [[ "$dataset_name" == *"TVD"* ]]; then
                binfolder="bin_folder/TVD/QP_$qp"
                yuvfolder="../CTC_Dataset/TVD"
            else
                binfolder="bin_folder/$dataset_name/QP_$qp"
                yuvfolder="../CTC_Dataset/$dataset_name"
            fi
            # OpenImage binfiles have .266 as extension
            binfile="$binfolder/$data_name.vvc"
            if [[ $dataset_name == "OpenImages" ]]; then
                binfile="$binfolder/$data_name.266"
            fi
            new_job=-1
            # new_job differs for image and video, differentiate these 2 by checking the number of input arguments
            if [ "$#" -eq 6 ]; then
                # arguments equals to 6 means it is a image job
                new_job="-i $yuvfolder/$data_name.yuv -b $binfile -q $filtered_qp -hgt $height -wdt $width $extra_params%$binfolder%$data_name.log"
            elif [ "$#" -eq 10 ]; then
                # arguments equals to 10 means it is a video job
                new_job="-i $yuvfolder/$data_name.yuv -b $binfile -q $filtered_qp -hgt $height -wdt $width --FrameSkip=$frame_skip --FramesToBeEncoded=$frame_num --IntraPeriod=$intra_period --FrameRate=$frame_rate $extra_params%$binfolder%$data_name.log"
            fi

            # sanity check to see if new_job is initialized properly
            if [[ $new_job == -1 ]]; then
                echo "Job $data_id is not initialized properly, please try again"
                exit 1
            else
                job_array+=("$new_job")
            fi
        fi
    
    done
}
```

</details>
<br>

## Task distribution logic
Follow same task distribution logic as the old perl script. Iterate through each job within the job_array and check for available pc to send the job to, if no available pc is found after 20 seconds, break out from this current test and move on to the next test.

Code to send task are as below:
<details>
  <summary><b>Click to view code to send task</b></summary>

```shell
counter=0 # the number of jobs sent to the clients
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
                break 2 # break current for loop and the busy waiting while loop outside, back to the main while loop
            fi
        done

        request_count=$(( $request_count + 1 ))
        if [ $request_count -ge 10]
        then
            break 2 # quit the main while loop if wait for more than 20 sec for the machine
        fi
    done

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
```
</details>
<br>


# RunOne.sh
This script takes in each task within the job array as input argument and parse the input argument as parameters to encode the given task.

Code for RunOne.sh are as below:
<details>
  <summary><b>Click to view RunOne.sh</b></summary>

```shell
while getopts "p:" OPTION; do
  case "$OPTION" in
    p)
      chmod u+x encoder
      ./encoder "$OPTARG"
      ;;
  esac
done
shift "$(($OPTIND-1))"
```

</details>
<br>


# VCM Inference Scripts
## Directories Definition
Prior to the inferencing step, user is expected to copy the `vcm_Inference` folder into each of the client PC. There are a total of **7 task folders** and **2 shelll scripts** under the `vcm_Inference` folder. Each folder contains the fully compressed dataset of the intended QP, and user is expected to use the `auto_inference.sh` script to perform model inference on a specific dataset and QP.
<br>

Examples:  
To perform inference with flir on QP_22, QP_27 and QP_32, run from **client PC**:                
```./auto_inference.sh flir ./eval_coco_mAP.sh None None "22 27 32"```

To perform inference with openimages_det on all QPs with **`CUDA_DEVICE=1`**, run from **client PC**:                
```./auto_inference.sh  openimages_det ./scripts/anchor.cfg 1 None```

To perform inference with tvd_tracking on all QPs with **`CUDA_DEVICE=2`**, run from **client PC**:                
```./auto_inference.sh  tvd_tracking ./scripts/anchor_track.cfg 2 None```

```
vcm_Inference
    ├── auto_inference.sh
    ├── gpu.sh
    ├── flir
    ├── openimages_det
    ├── openimages_seg
    ├── sfu_hw
    ├── tvd_det
    ├── tvd_seg
    └── tvd_tracking
```

In addition to the fully compressed dataset, each task folder would also contain the following scripts. The scripts listed below would be triggered by `auto_inference.sh` during the inferencing process for each individual task. 

| Task Name       | `run_inference.sh` | `set_device.sh` | `set_qp.sh` | `set_group.sh` |
| :----------:    | :----------------: | :-------------: | :---------: | :------------: | 
| flir            |                    |                 | &check;     |                |
| openimages_det  |                    | &check;         | &check;     |                |
| openimages_seg  | &check;            | &check;         | &check;     |                |
| sfu_hw          | &check;            | &check;         | &check;     |                |
| tvd_det         | &check;            | &check;         | &check;     |                |
| tvd_seg         | &check;            | &check;         | &check;     |                |
| tvd_tracking    | &check;            | &check;         | &check;     |                |

Code for auto_inference.sh are as below:
<details>
  <summary><b>Click to view auto_inference.sh</b></summary>

```shell
# acceptable task values are "flir", "openimages_det", "openimages_seg", "sfu_hw", "tvd_det", "tvd_seg", "tvd_tracking"
task=$1
cfg_location=$2
device_idx=$3
group=$4
qp_list="$5"

# go into the specific task folder
cd $task

# set device
# set group (only works for sfu_hw_det)
chmod u+x set_device.sh
chmod u+x set_group.sh
chmod u+x set_qp.sh

./set_device.sh $cfg_location $device_idx
./set_group.sh $cfg_location $group
./set_qp.sh $cfg_location "$qp_list"

# build and run the docker file
docker build -t $task .
docker run --gpus all --rm -v $PWD:/${task} ${task}
```

</details>
<br>