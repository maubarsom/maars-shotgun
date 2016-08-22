#$ -cwd
`#'$ -pe smp _THREADS_
#$ -V
#$ -S /bin/bash
`#'$ -N _SAMPLE_`_'pacnes
#$ -j yes

module load bioinformatics/bowtie2/2.2.5
module load bioinformatics/samtools/1.3.1

makefile=/users/maubar/fsbio/panphlan/panphlan.mak

make -r -f ${makefile} sample_name=_SAMPLE_`_'hf read_folder=reads threads=_THREADS_ species=pacnes16
