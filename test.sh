# IN="video%name%qp_value%intra_period%frame_rate%frames_num%frame_skip%dataset_dir%additional_param"
# sendTask() {
#     task_object=$1
#     task_attributes=(${IN//%/ })
#     echo ${task_attributes[0]}     
    
# }
# sendTask IN
# var=$(realpath ./)
# echo $var
job_array=(1 2 3)
# counter=0
# echo ${#job_array[@]}
# while [ $counter -lt ${#job_array[@]} ]
# do
#     echo counter is $counter
#     echo ${job_array[counter]}
#     counter=$(( $counter + 1 ))
# done
client_pc=("pc0:ubuntu@192.168.1.222" "pc1:user@192.168.1.17" "pc2:ubuntu@192.168.1.130")

for pc in "${client_pc[@]}"
do  
    pc_info=(${pc//:/ })
    pc_ip=${pc_info[0]} 
    echo $pc_ip
    # check_if_available $pc
    # if [ "$available" = true ]
    # then
    #     echo Assigned to 
    # fi
done