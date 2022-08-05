# set the permission and execute the inference script
cd sfu_hw_det/code/SFU-HW
chmod u+x detection_anchor.sh
sh -c "./detection_anchor.sh"

# extract the inference matrics and store them as csv files in intermediate_results folder
cd /
mkdir intermediate_results

cd /sfu_hw_det/code/SFU-HW
python gen_metrics.py