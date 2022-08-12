#!/bin/bash

#####################################################
# handle command line arguments
if [ "$#" -ne 1 ]; then
  echo "
  This script encodes the specified YUV file using its given parameters. To run the script, key in its parameters 
  e.g. $0 -i input.yuv -b bitstream.vvc -qp 27 --ConformanceWindowMode=1
" 
fi

while getopts "p:" OPTION; do
  case "$OPTION" in
    p)
      chmod u+x ./EncoderApp
      ./EncoderApp $OPTARG
      ;;
  esac
done