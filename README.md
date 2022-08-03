# VCM AutoEnvironment Cluster Script 

## Directories Definition
All files needed to run a specific test are to be manually copied over by user as user creates the new test_folder (in this case `2022_08_02_subset_test`)  and place directly under the new test folder

Files/Folders to be copied over are:  
- `cfg_folder`
- `image_data.txt`
- `video_data.txt`
- `RunEnc.sh`
- `RunOne.sh`  
```
    ├── 2022_08_02_subset_test  -> test name for a specific test
    │   ├── image_data.txt
    │   ├── video_data.txt
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

## Cluster Distribution Logic
1. Read user input
    - **`mode`**: either "full" or "subset"
    - **`data_range`**: a list of integers indicating which subset of data_id to run compression on if `mode` selected is `subset`
    - **`qp`**: a list of integer between 0 to 5 indicating which QP to compress the data on

2. Filter out selected data_id if user specified "subset" mode (new data table `filtered_image_data.txt` and `filtered_data_data.txt` table will be generated for this test)

3. Generate `job_array` from either data.txt or filtered_data.txt (Detailed logic described below)

4. Distribute each task within job_array to different client pc for compression
    
### Generate Job Array
The create job array function consists of 2 parts, first is to read through either the `filtered_image_data.txt` and `filtered_video_data.txt` or the `image_data.txt` and `video_data.txt` depending on the mode for the test.

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
```

</details>

The second part of generating job_array is to actually generate the job array using the data table produced from the previous step. For each job, the script would generate one task for every qp to compress the same data on. One examplary task would be as follow:  
`"-i ../CTC_Dataset/$dataset_name/$data_name.yuv -b $binfile -q $filtered_qp -hgt $height -wdt $width --FrameSkip=$frame_skip --FramesToBeEncoded=$frame_num --IntraPeriod=$intra_period --FrameRate=$frame_rate $extra_params%$binfolder%$data_name.log"`  
Each task represents a command to be run by the Encoder on a specific QP and this task will be sent to `RunOne.sh` for encoding.

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
```

</details>
<br>

## Task distribution logic
Follow same task distribution logic as the old perl script. Iterate through each job within the job_array and check for available pc to send the job to, if no available pc is found after 20 seconds, break out from this current test and move on to the next test.
