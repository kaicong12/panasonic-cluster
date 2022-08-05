# set the device to be used for inference
cfg_location=$1
device_idx=$2

# find the cuda_device variable and modify it
awk '{sub(/cuda_device=./,"cuda_device='"${device_idx}"'"); print}' $cfg_location > new_config.cfg
cp new_config.cfg $cfg_location
rm new_config.cfg
