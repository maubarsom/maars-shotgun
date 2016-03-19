#$ -cwd
`#'$ -pe smp _THREADS_
#$ -V
#$ -S /bin/bash
`#'$ -N _SAMPLE_-hf
#$ -j yes

#Note that bwa loads samtools/1.1. Need to load in this order to make samtools/1.3 the one that's called
module load bioinformatics/bwa/0.7.12-r1039
module load bioinformatics/samtools/1.3
module load general/JRE/1.8.0_65

makefile=/users/maubar/workspace/maars-shotgun/experiments/2016.03_fungi_quicksearch/fungi_quicksearch.mak

time make -r -f ${makefile} sample_name=_SAMPLE_ read_folder=reads threads=_THREADS_ all
