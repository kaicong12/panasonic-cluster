# run the inference scripts provided by input contribution document
cd /tvd_tracking/tvd_inference_release_v3/scripts
chmod u+x tvd_track_results.sh
chmod u+x eval_track_tvd.sh
sh -c "./tvd_track_results.sh anchor_track.cfg"

# extract the inference matrics and store them as csv files in intermediate_results folder
cd /tvd_tracking
mkdir intermediate_results
cd /tvd_tracking/tvd_inference_release_v3/scripts
python gen_metrics_tracking.py

