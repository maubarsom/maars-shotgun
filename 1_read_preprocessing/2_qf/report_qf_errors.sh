#!/bin/bash
set -euo pipefail
folder="$1"

cd $folder
for x in `ls -d P*`;
do
	if [ ! -e $x/qf/out ] || [ `ls $x/qf/out | wc -l` -ne 3 ];  
	then
		echo $x
	fi
done
cd ..
