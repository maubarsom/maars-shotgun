#!/bin/bash
#SBATCH -A b2012214
#SBATCH -p core -n 8
#SBATCH -t 3:00:00
#SBATCH -J <sample>-mpa-f
#SBATCH -o mpa-f-%j.out
#SBATCH -e mpa-f-%j.err
#SBATCH --tmp=20480

#SBATCH --mail-user mauricio.barrientos@ki.se
#SBATCH --mail-type=ALL


module load bowtie2/2.2.3

sample_name=<sample>

mpa_dir=/home/mauricio/local/share/biobakery-metaphlan2-fd4fbe5acdb4

out_file=metaphlan/"$sample_name"_metaphlan_filt.txt
out_biom=metaphlan/"$sample_name"_metaphlan_filt.biom

#Concatenate reads into tmp folder
cat contamination_rm/*_rmcont_pe.fq contamination_rm/*_rmcont_se.fq > "$SNIC_TMP"/reads.fq

input_fastq="$SNIC_TMP"/reads.fq

mkdir -p metaphlan
metaphlan2.py --mpa_pkl ${mpa_dir}/db_v20/mpa_v20_m200.pkl --bowtie2db ${mpa_dir}/db_v20/mpa_v20_m200 \
	--bowtie2out metaphlan/filtered.bowtie2.bz2 --nproc 8 --input_type multifastq --biom $out_biom \
	$input_fastq $out_file
#Delete bowtie mapping results
rm filtered.bowtie2.bz2
