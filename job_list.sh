#!/bin/bash

while true
do
    #Readind each test_name in sequence  
    while read test_name
    do  
        echo $test_name
        cd $test_name
        chmod u+x RunEnc.sh
        ./RunEnc.sh
        if test -f "done.tim"
        then
            cd ..
            continue # Current test is completed. Go to next test.
        else
            cd ..
            break # Current test (top priority) is not done. Go back to current test again.
        fi
    done < job_list.txt 
done