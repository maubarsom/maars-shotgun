#$ -cwd
`#'$ -pe smp _THREADS_
#$ -V
#$ -S /bin/bash
`#'$ -N _SAMPLE_
#$ -j yes

#Note that bwa loads samtools/1.1. Need to load in this order to make samtools/1.3 the one that's called
module load bioinformatics/bwa/0.7.15
module load bioinformatics/samtools/1.3
module load general/JRE/1.8.0_65

makefile=/users/maubar/workspace/maars-shotgun/experiments/2017.02_malassezia_search/species_search.mak

time make -r -f ${makefile} sample_name=_SAMPLE_ species=_SPECIES_ read_folder=reads threads=_THREADS_ 
