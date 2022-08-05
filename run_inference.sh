# set the permission and execute the inference script
cd /tvd_det/tvd_inference_release_v3/scripts
chmod u+x tvd_det_seg_results.sh
chmod u+x gen_detout_tvd.sh
chmod u+x eval_det_tvd.sh
chmod u+x gen_segout_tvd.sh
chmod u+x eval_seg_tvd.sh
sh -c "./tvd_det_seg_results.sh anchor.cfg"

# extract the inference matrics and store them as csv files in intermediate_results folder
cd /tvd_det
mkdir intermediate_results
cd /tvd_det/tvd_inference_release_v3/scripts
python gen_metrics_det_seg.py
