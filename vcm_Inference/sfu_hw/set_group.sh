cfg_location=$1
group="$2"
echo $group

# replace the inference_group list with user specified group
awk '{sub(/inference_group = ".*"/,"inference_group = \"'"${group}"'\""); print}' $cfg_location > new_config.py
cp new_config.py $cfg_location
rm new_config.py

awk '{sub(/inference_group = ".*"/,"inference_group = \"'"${group}"'\""); print}' "code/SFU-HW/gen_metrics.py" > new_config.py
cp new_config.py code/SFU-HW/gen_metrics.py
rm new_config.py

awk '{sub(/inference_group = ".*"/,"inference_group = \"'"${group}"'\""); print}' "code/SFU-HW/calc_metric.py" > new_config.py
cp new_config.py code/SFU-HW/calc_metric.py
rm new_config.py