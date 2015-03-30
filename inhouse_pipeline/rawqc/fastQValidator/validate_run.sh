#!/bin/bash
set -euo pipefail
module load gnuparallel

run_dir=$1
nthreads=$2

run_name=`expr match "$1" '.*\(B.Andersson_[0-9]\{2\}_[0-9]\{2\}\)'`
samples_tmp=samples_"$run_name".tmp
#print sample dirs to a tmp file
ls -d $run_dir/P* > $samples_tmp
parallel -j $nthreads --joblog "$run_name".log bash validate_sample.sh :::: $samples_tmp 
rm $samples_tmp
