#!/bin/bash

set -euo pipefail

if [ -z $1 ]; then 
	echo "The folder to process is required"
	exit 1;
fi

SBATCH_TEMPLATE=/proj/b2012214/nobackup/private/raw_qc/sbatch_raqc.templ
OUT_FILE=sbatch_rawqc.sh

lib_dir=$1
echo $lib_dir
cd $lib_dir

for sample_dir in `ls -d P*`;
do
	echo $sample_dir
	cd $sample_dir
	sample_name=${sample_dir%_index*}
	sed -e "s/<sample>/$sample_name/g" -e "s/<threads>/4/g" $SBATCH_TEMPLATE > $OUT_FILE
	cd ..
done
