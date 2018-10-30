#!/bin/bash
#$ -cwd
#$ -pe smp 8
#$ -V
#$ -S /bin/bash
#$ -N panphlan_sensitive.log
#$ -j yes

set -euo pipefail -o verbose

export PATH=/users/maubar/tools/panphlan/a25bc29ad4ec:${PATH}

panphlan_db_dir=/users/maubar/fsbio/db/panphlan

mkdir -p 2_panphlan_profile

#Run with default parameters
for species in pacnes16 saureus16 sepidermidis16;
do
panphlan_profile.py -c ${species} --i_bowtie2_indexes ${panphlan_db_dir}/${species} \
			--min_coverage 2 --left_max 1.25 --right_min 0.75 \
			-i 1_panphlan_map/${species} -o 2_panphlan_profile/${species}_panphlan_default.csv --add_strains --verbose 
done

#Run with sensitive parameters
for species in pacnes16 saureus16 sepidermidis16;
do
panphlan_profile.py -c ${species} --i_bowtie2_indexes ${panphlan_db_dir}/${species} \
			--min_coverage 1 --left_max 1.70 --right_min 0.30 \
			-i 1_panphlan_map/${species} -o 2_panphlan_profile/${species}_panphlan_sensitive.csv --add_strains --verbose 
done
