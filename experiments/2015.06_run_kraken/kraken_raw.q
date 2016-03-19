#!/bin/bash
#$ -pe threaded 8
#$ -S /bin/bash
#$ -cwd
#$ -N <sample>_kraken-r
#$ -M mauricio.barrientos@ki.se
#$ -m bea
#$ -j y

export PATH="/home/maubar/.anaconda/bin:/home/maubar/tools/bin:$PATH"

sample_name=<sample>
kraken_make=/home/maars/test_samples/kraken/kraken.mak

time make -f ${kraken_make} sample_name=${sample_name} read_folder=reads threads=8 TMP_DIR=$TMPDIR R1_filter=_1. R2_filter=_2. fq_ext=fastq.gz pe
#time make -f ${kraken_make} sample_name=${sample_name} read_folder=reads threads=8 TMP_DIR=$TMPDIR R1_filter=_1. R2_filter=_2. single_filter=.singleton. fq_ext=fastq.gz pe_se
