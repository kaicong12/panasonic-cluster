#!/bin/bash

pc_name=$1
pc_ip=$2

command="sar 1 1 | grep Average"
average=$(eval $command)
echo $average

# empty space from -10 to -6, slice from -9 onwards in order to extract either the last 3 or 4 characters from "average" string
cpu_idle_perc=${average: -6}
echo $cpu_idle_perc "% is currently idling"