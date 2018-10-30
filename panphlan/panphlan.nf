#!/usr/bin/env nextflow

// Input parameters
params.fastq_dir='/users/maubar/fsbio/humanrm'
params.panphlan_dir='/users/k1772927/tools/panphlan-1.2.2.5'
params.panphlan_db_dir='/users/maubar/fsbio/db/panphlan'

/*
1. Create a channel that gets all fastq files in the directory

and then groups them by the "scilife_id" such that the channel emits
tuples like

[sample_id,[fastq1,fastq2,fastq3]]

e.g
["P100_101",["P100_101_1.fastq.gz",
             "P100_101_2.fastq.gz",
             "P100_101_single.fastq.gz"]
            ]
*/
samples=Channel.fromPath("${params.fastq_dir}/**/*.fastq.gz")
    .map{ [ (it.name =~ /(P[0-9]+_[0-9]+)_.+\.fastq\.gz/)[0][1], it]}
    .groupTuple(by:0,size:3,remainder:true)

//List of bowtie index IDs for Panphlan
//species_list= ['saureus16','sepidermidis16','pacnes16']
species_list= ['saureus16']

process panphlan_map{
    publishDir 'panphlan/map', mode:'copy'

    tag {"${species_id}/${sample_id}"}

    input:
    set sample_id,'reads*.fq.gz' from samples
    each species_id from species_list

    // Note: panphlan seems to add the species name to the output before the .csv.bz2 part
    output:
    set species_id,"${sample_id}_${species_id}.csv.bz2" into panphlan_map_out

    script:
    """
    source activate panphlan
    zcat *.fq.gz | ${params.panphlan_dir}/panphlan_map.py --fastx fastq -p 8 --verbose --tmp \${TMPDIR} \
            -c ${species_id} --i_bowtie2_indexes ${params.panphlan_db_dir}/${species_id} \
            -o ${sample_id}.csv.bz2 
    """
}

profile_params="--min_coverage 2 --left_max 1.25 --right_min 0.75"
if(params.sensitive){
    profile_params="--min_coverage 1 --left_max 1.70 --right_min 0.30"
}

process panphlan_profile{
    publishDir 'panphlan/profile'
    tag {"${species_id}"}

    input:
    set species_id, "*" from panphlan_map_out.groupTuple(by:0)

    output:
    set species_id, "${species_id}_panphlan.csv"

    script:
    """
    mkdir ${species_id}
    mv *.csv.bz2 ${species_id}
    source activate panphlan
    ${params.panphlan_dir}/panphlan_profile.py -c ${species_id} --i_bowtie2_indexes ${params.panphlan_db_dir}/${species_id} \
        ${profile_params} -i ${species_id} -o ${species_id}_panphlan.csv --add_strains --verbose
    """
}
