#$ -cwd
`#'$ -pe smp _THREADS_
#$ -V
#$ -S /bin/bash
`#'$ -N _SAMPLE_-hf
#$ -j yes

module load bioinformatics/bowtie2/2.2.5
module load bioinformatics/samtools/1.2
module load general/JRE/1.7.0_80

hf_makefile=/users/maubar/fsbio/humanrm/scripts/human_rm.apollo.mak

make -r -f ${hf_makefile} sample_name=_SAMPLE_ read_folder=2_qf threads=_THREADS_ all md5_files 
