#!/bin/bash

set -euo pipefail

if [ -z $1 ]; then 
	echo "The folder to process is required"
	exit 1;
fi

QF_SBATCH=/proj/b2012214/nobackup/private/read_preproc/scripts/sbatch_qf.templ
HUMANRM_SBATCH=/proj/b2012214/nobackup/private/read_preproc/scripts/sbatch_humanrm.templ

lib_dir=$1
echo $lib_dir
cd $lib_dir

for sample_dir in `ls -d P*`;
do
	echo $sample_dir
	cd $sample_dir
	sample_name=${sample_dir%_index*}
	sed -e "s/<sample>/$sample_name/g" -e "s/<threads>/2/g" $QF_SBATCH > sbatch_qf.sh
	#sed -e "s/<sample>/$sample_name/g" -e "s/<threads>/4/g" $HUMANRM_SBATCH > sbatch_humanrm.sh
	cd ..
done
