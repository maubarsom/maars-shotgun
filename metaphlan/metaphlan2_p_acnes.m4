#$ -cwd
`#'$ -pe smp _THREADS_
#$ -V
#$ -S /bin/bash
`#'$ -N _SAMPLE_-mpa2-pacnes
#$ -j yes

module load bioinformatics/bowtie2/2.2.5

makefile=/users/maubar/fsbio/metaphlan/scripts/metaphlan2.rosalind.mak

make -r -f ${makefile} sample_name=_SAMPLE_`_'hf read_folder=3_hf threads=_THREADS_ strain
