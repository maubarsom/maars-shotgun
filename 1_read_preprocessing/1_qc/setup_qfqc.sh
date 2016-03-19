#!/bin/bash

set -euo pipefail

if [ -z $1 ]; then 
	echo "Usage: setup_qf.sh <folder> <sbatch_m4>"
	exit 1;
fi

lib_dir=$1
SBATCH_M4=$2

echo $lib_dir
cd $lib_dir

for sample_dir in $(ls);
do
	echo $sample_dir
	cd $sample_dir
	sample_name=${sample_dir}
	m4 -D_SAMPLE_=${sample_name} -D_THREADS_=8 ${SBATCH_M4} > sbatch_qfqc.sh
	cd ..
done
