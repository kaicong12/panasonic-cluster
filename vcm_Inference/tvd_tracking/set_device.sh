# set the device to run the compression
cfg_location=$1
device_idx=$2

# locate to the cuda_device variable and change it to the user input
awk '{sub(/cuda_device=./,"cuda_device='"${device_idx}"'"); print}' $cfg_location > new_config.cfg
cp new_config.cfg $cfg_location
rm new_config.cfg
