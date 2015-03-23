#!/bin/bash
set -euo pipefail
module load gnuparallel

run_dir=$1
ls -d $run_dir/P* > samples.tmp
parallel -j 8 bash validate_sample.sh :::: samples.tmp 
rm samples.tmp
