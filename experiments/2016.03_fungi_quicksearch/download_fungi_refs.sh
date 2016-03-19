#/bin/bash

#Fungal genomes to download

#Candida Albicans
#Strain WO-1 , only one with chromosome level assembly
# Link to assemblies of Candida Albicans strains: http://www.ncbi.nlm.nih.gov/genome/genomes/21

wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA_000149445.2_ASM14944v2/*.genomic.fna.gz
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA_000149445.2_ASM14944v2/*.protein.faa.gz
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA_000149445.2_ASM14944v2/*.txt

#Trichophyton rubrum
#Strain CBS 118892, RefSeq Genome
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF_000151425.1_ASM15142v1/*.genomic.fna.gz
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF_000151425.1_ASM15142v1/*.protein.faa.gz
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF_000151425.1_ASM15142v1/*.txt