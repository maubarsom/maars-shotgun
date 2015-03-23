#!/bin/bash
set -uo pipefail

OUT_DIR=/gulo/proj_nobackup/b2012214/private/fastQValidate

sample_dir=$1
sample_id=`expr match "$1" '.*\(P[0-9]\{3,4\}_[0-9]\{3,4\}\)'`

for x in `ls $sample_dir/*.fastq.gz`;
do
	fastQValidator --file $x >/dev/null
	if [ $? -ne 0 ]; then echo `basename $x` > "$sample_id".bad ; fi
done
