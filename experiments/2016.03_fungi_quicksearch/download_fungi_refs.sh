#$ -cwd
#$ -pe smp 3
#$ -V
#$ -S /bin/bash
#$ -N download_fungi
#$ -j yes


#/bin/bash
set -euo pipefail
#Fungal genomes to download

mkdir -p candida_albicans trichophyton_rubrum

#Candida Albicans
#Strain WO-1 , only one with chromosome level assembly
# Link to assemblies of Candida Albicans strains: http://www.ncbi.nlm.nih.gov/genome/genomes/21
cd candida_albicans
wget -N ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA_000149445.2_ASM14944v2/*_genomic.fna.gz &
wget -N ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA_000149445.2_ASM14944v2/*_protein.faa.gz &
wget -N ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA_000149445.2_ASM14944v2/*.txt
cd ..
wait
gunzip -c candida_albicans/*.fna.gz > c_albicans.fna

#Trichophyton rubrum
#Strain CBS 118892, RefSeq Genome
cd trichophyton_rubrum
wget -N ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF_000151425.1_ASM15142v1/*_genomic.fna.gz &
wget -N ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF_000151425.1_ASM15142v1/*_protein.faa.gz &
wget -N ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF_000151425.1_ASM15142v1/*.txt
cd ..
wait
gunzip -c trichophyton_rubrum/*.fna.gz > t_rubrum.fna
