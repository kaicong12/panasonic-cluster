# set the device used for inference
cfg_location=$1
device_idx=$2

# find the set_device() code and modify it
awk '{sub(/set_device../,"set_device('"${device_idx}"'"); print}' $cfg_location > new_config.py
cp new_config.py $cfg_location
rm new_config.py
