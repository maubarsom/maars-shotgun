#!/bin/bash

#SBATCH -A b2012214

#SBATCH -p core -n 1

#SBATCH -t 6:00:00

#SBATCH -J generic_job
#SBATCH --mail-user mauricio.barrientos@ki.se
#SBATCH --mail-type=ALL
#SBATCH -e slurm-%j.err

#SBATCH --tmp=64000

module load gnuparallel

