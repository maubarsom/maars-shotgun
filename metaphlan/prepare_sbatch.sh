#!/bin/bash

set -euo pipefail

if [ -z $1 ]; then 
	echo "The folder to process is required"
	exit 1;
fi

SBATCH_TEMPLATE=/home/mauricio/utils/maars-shotgun/metaphlan/run_metaphlan_raw.sh

lib_dir=$1
echo $lib_dir
cd $lib_dir

for sample_dir in `ls -d P*`;
do
	echo $sample_dir
	cd $sample_dir
	sample_name=${sample_dir%_index*}
	sed "s/<sample>/$sample_name/g" $SBATCH_TEMPLATE > sbatch_mpa.sh
	cd ..
done
