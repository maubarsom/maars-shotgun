#!/usr/bin/env nextflow

params.fastq_dir='/users/maubar/fsbio/humanrm'
fastq_files = Channel.fromFilePairs("${params.fastq_dir}/**/*{1,2}.fastq.gz")

//Old references (ftp://ftp.fmach.it/metagenomics/strainest/ref/)
//species_list=['P_acnes','S_aureus']
//strainest_db="/users/k1772927/brc_scratch/db/strainest/ref"

//New references (ftp://ftp.fmach.it/metagenomics/strainest/ref2/)
species_list=['Escherichia_Coli','Staphylococcus_Epidermidis']
strainest_db="/users/k1772927/brc_scratch/db/strainest/ref2"

process bowtie_mapping{
    tag { "${sample_id}/${species}" }

    input:
    set sample_id, reads from fastq_files
    each species from species_list

    output:
    set sample_id, species, "${sample_id}_${species}.sam" into bowtie2_out

    script:
    """
    bowtie2 -p 8 --very-sensitive  --no-unal -x ${strainest_db}/${species}/bowtie/align -1 ${reads[0]} -2 ${reads[1]} -S ${sample_id}_${species}.sam
    """
}

process sam_sorting{
  tag { "${sample_id}/${species}" }

  input:
  set sample_id, species, file(sam_file) from bowtie2_out

  output:
  set sample_id, species, "${sample_id}_${species}_sorted.bam","${sample_id}_${species}_sorted.bam.bai" into sam_sort_out

  script:
  """
  samtools view -Sb ${sam_file} | samtools sort --threads 4 -m 2G -o ${sample_id}_${species}_sorted.bam -
  samtools index ${sample_id}_${species}_sorted.bam
  """
}
/*
In the new databases snp_clust.dgrp is called snv.txt
For backwards compatibility the file was soft linked with the old name snp_clust.dgrp
*/
process run_strainEst{
  tag { "${sample_id}/${species}" }
  publishDir "strainEst/${species}", mode: 'copy'

  input:
  set sample_id, species, file(sorted_bam), file(sorted_bam_idx) from sam_sort_out

  output:
  set sample_id, species, "*" into strainEst_out

  script:
  """
  strainest est ${strainest_db}/${species}/snp_clust.dgrp ${sorted_bam} ./
  cp .command.err ${sample_id}_${species}.err
  for x in *.txt; do mv \${x} ${sample_id}_${species}_\${x}; done
  shopt -s nullglob
  for x in *.pdf; do mv \${x} ${sample_id}_${species}_\${x}; done
  """
}
