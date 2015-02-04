#!/bin/bash
#SBATCH -A b2012214
#SBATCH -p core -n 8
#SBATCH -t 3:00:00
#SBATCH -J <sample>-mpa-r
#SBATCH -o mpa-r-%j.out
#SBATCH -e mpa-r-%j.err
#SBATCH --tmp=20480

#SBATCH --mail-user mauricio.barrientos@ki.se
#SBATCH --mail-type=ALL


module load bowtie2/2.2.3

sample_name=<sample>

mpa_dir=/home/mauricio/local/share/biobakery-metaphlan2-fd4fbe5acdb4

out_file=metaphlan/"$sample_name"_metaphlan_raw.txt
out_biom=metaphlan/"$sample_name"_metaphlan_raw.biom

#Extract reads into tmp folder
zcat reads/*_1.fastq.gz reads/*_2.fastq.gz > "$SNIC_TMP"/reads.fq

input_fastq="$SNIC_TMP"/reads.fq

mkdir -p metaphlan
metaphlan2.py --mpa_pkl ${mpa_dir}/db_v20/mpa_v20_m200.pkl --bowtie2db ${mpa_dir}/db_v20/mpa_v20_m200 \
	--bowtie2out metaphlan/raw.bowtie2.bz2 --nproc 8 --input_type multifastq --biom $out_biom \
	$input_fastq $out_file
#Delete bowtie mapping results
rm raw.bowtie2.bz2
