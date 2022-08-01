#!/bin/bash

while true
do
    #Readind each test_name in sequence  
    while read test_name
    do  
        echo $test_name
        enc_script=${test_name}/RunEnc.sh
        echo $enc_script
        chmod u+x $enc_script
        ./${enc_script}
        done_file=${test_name}/done.tim
        if test -f "$done_file"; then
            continue # Current test is completed. Go to next test.
        else
            break # Current test (top priority) is not done. Go back to current test again.
        fi
    done < job_list.txt 
done