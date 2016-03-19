#$ -cwd
`#'$ -pe smp _THREADS_
#$ -V
#$ -S /bin/bash
`#'$ -N _SAMPLE_-hf
#$ -j yes

module load bioinformatics/bwa/0.7.12-r1039
module load bioinformatics/samtools/1.2
module load general/JRE/1.7.0_80

makefile=/users/maubar/maars/2015.11_deltatoxin/s_aureus_toxin.mak

time make -r -f ${makefile} sample_name=_SAMPLE_ read_folder=reads threads=_THREADS_ all
