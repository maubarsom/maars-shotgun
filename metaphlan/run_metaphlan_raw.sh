#!/bin/bash
#SBATCH -A b2012214
#SBATCH -p core -n 4 
#SBATCH -t 5:00:00
#SBATCH -J <sample>-mpa-r
#SBATCH -o mpa-r-%j.out
#SBATCH -e mpa-r-%j.err
#SBATCH --tmp=20480

#SBATCH --mail-user mauricio.barrientos@ki.se
#SBATCH --mail-type=ALL


module load bowtie2/2.2.3

sample_name=<sample>
metaphlan_makefile=/proj/b2012214/nobackup/private/metaphlan_maars/metaphlan.mak


make -f $metaphlan_makefile sample_name=$sample_name read_folder=reads/ threads=4 TMP_DIR=$SNIC_TMP
