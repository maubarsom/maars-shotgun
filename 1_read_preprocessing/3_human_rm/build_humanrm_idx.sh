#$ -cwd
#$ -pe smp 8
#$ -V
#$ -S /bin/bash
#$ -N hg_idx
#$ -j yes

set -euo pipefail

#Modules
module load bioinformatics/bowtie2/2.2.5
module load bioinformatics/bwa/0.7.12-r1039

#Download GRCh38 chromosomes
wget -N ftp://ftp.ncbi.nlm.nih.gov/genbank/genomes/Eukaryotes/vertebrates_mammals/Homo_sapiens/GRCh38/Primary_Assembly/assembled_chromosomes/FASTA/*.fa.gz

#Download Mitochondrial chromosome
wget -N ftp://ftp.ncbi.nlm.nih.gov/genbank/genomes/Eukaryotes/vertebrates_mammals/Homo_sapiens/GRCh38/non-nuclear/assembled_chromosomes/FASTA/chrMT.fa.gz

#Download phiX174 reference (illumina spikein)
wget -N 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=9626372&rettype=fasta&retmode=text' -O phiX174.fa

#gunzip *.fa.gz
mkdir fasta
mv *.fa fasta/

#Build bowtie2 index
mkdir -p bowtie2
bowtie2-build $(echo fasta/*.fa | sed "s/ /,/g") bowtie2/grch38_phix

#Build bwa index
mkdir -p bwa
bwa index -p bwa/grch38_phix fasta/*.fa 

#rm *.fa
