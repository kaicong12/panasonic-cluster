cfg_location=$1
qp_list=$2

# set QP
awk '{sub(/QP=./,"QP='"${qp_list}"'"); print}' $cfg_location > new_config.cfg
cp new_config.cfg $cfg_location
rm new_config.cfg
