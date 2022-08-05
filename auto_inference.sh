task=$1
cfg_location=$2
device_idx=$3
group=$4

# go into the specific task folder
cd $task

# set device
# set group (only works for sfu_hw_det)
chmod u+x set_device.sh
chmod u+x set_group.sh
./set_device.sh $cfg_location $device_idx
./set_group.sh $cfg_location $group

# build and run the docker file
docker build -t $task .
docker run --gpus all --rm -v $PWD:/${task} ${task}
