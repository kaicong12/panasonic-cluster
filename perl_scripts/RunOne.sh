#!/bin/bash

#####################################################
# handle command line arguments
if [ "$#" -ne 1 ]; then
  echo "
This script encodes the specified YUV file using its given parameters. To run the script, key in its parameters 
  e.g. $0 -i input.yuv -b bitstream.vvc -qp 27 --ConformanceWindowMode=1

<< Do not key in height and width of the input YUV as parameter as this script would calculate it >>
" 
fi


while getopts "p:" OPTION; do
  case "$OPTION" in
    p)
      avalue="$OPTARG"
      echo "The value provided is $OPTARG"
      ;;
  esac
done
shift "$(($OPTIND-1))"

