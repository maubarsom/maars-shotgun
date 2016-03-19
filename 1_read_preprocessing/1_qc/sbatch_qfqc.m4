#!/bin/bash
#SBATCH -A b2012105
`#'SBATCH -p core -n _THREADS_
#SBATCH -t 8:00:00
`#'SBATCH -J _SAMPLE_-qc
#SBATCH -o qc-%j.out
#SBATCH -e qc-%j.err
#SBATCH --tmp=64000

#SBATCH --mail-user mauricio.barrientos@ki.se
#SBATCH --mail-type=FAIL

sample_name=_SAMPLE_
step_makefile=/proj/b2012214/nobackup/private/soft_trim_test/scripts/qc.mak

set -euo pipefail

mkdir -p qf_qc
cd qf_qc
make -r -f ${step_makefile} sample_name=${sample_name} read_folder=../qf threads=_THREADS_ TMP_DIR="${SNIC_TMP}" fq_ext='fq.gz' 
