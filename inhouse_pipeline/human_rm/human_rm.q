#$ -cwd
#$ -pe smp 32
#$ -V
#$ -S /bin/bash
#$ -N maarsHF
#$ -j yes

module load bioinformatics/bowtie2/2.2.5
module load bioinformatics/samtools/1.2
module load general/JRE/1.7.0_80

hf_makefile=/users/maubar/fsbio/humanrm/scripts/human_rm.mak

mkdir -p sample_log
parallel -j4 --results sample_log --joblog parallel.log cd {} \; make -r -f ${hf_makefile} sample_name={/} read_folder=../2_qf threads=8  all md5_files \; ::: $(find . -name "P*" -type d | head -n 1 )
