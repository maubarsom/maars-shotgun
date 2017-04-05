# Pipeline to map reads against Fungal species genomes

# Author: Mauricio Barrientos-Somarribas
# Email:  mauricio.barrientos@ki.se

# Copyright 2015 Mauricio Barrientos-Somarribas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#Make parameters
SHELL := /bin/bash

ifndef sample_name
$(warning Variable 'sample_name' is not defined)
endif

ifndef species
$(warning Variable 'species' is not defined)
endif

ifndef read_folder
$(warning Variable 'read_folder' is not defined)
endif

ifndef TMP_DIR
TMP_DIR=$(shell echo $$TMPDIR)
$(warning TMP_DIR is $(TMP_DIR))
endif

ifndef threads
threads := 8
endif

#Choose between bwa and bowtie2
ifndef MAPPER
MAPPER := bwa
$(info Using $(MAPPER) as default mapper )
endif

#Binary config
BWA_BIN := bwa
SAMTOOLS_BIN := samtools
PICARD_BIN := java -Xmx16g -jar ~/tools/picard-tools/2.1.1/picard.jar
DIAMOND_BIN := ~/tools/diamond/0.7.11/diamond
TIDDIT_BIN := ~/tools/TIDDIT/bin/TIDDIT
GATK_BIN := java -Xmx16g -jar ~/tools/gatk-3.7/GenomeAnalysisTK.jar
BEDOPS_PATH := ~/tools/bedops-2.4.23

#Input files
R1 := $(wildcard $(read_folder)/*_1.fastq.gz)
R2 := $(wildcard $(read_folder)/*_2.fastq.gz)
singles := $(wildcard $(read_folder)/*_single.fastq.gz)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.PHONY: all bams stats diamond rmdup_bams rmdup_stats

all: rmdup_bams rmdup_stats

bams: $(MAPPER)/$(sample_name)_$(species).bam.bai
stats: $(addprefix stats/$(sample_name)_$(species).bam,.flgstat .cov.gz)

rmdup_bams: $(MAPPER)/$(sample_name)_$(species)_rmdup.bam.bai
rmdup_stats: $(addprefix stats/$(sample_name)_$(species)_rmdup.bam,.flgstat .cov.gz)


#*************************************************************************
#Map to species genome with BWA MEM
#*************************************************************************
species_bwa_idx:= ~/fsbio/2017.02_malassezia_search/bwa_idx/$(species)

#-F 260 = keep only mapped reads,no secondary mappings (256 + 4)
#-f 2 Keep reads mapped in proper pair -> we want to be a bit stringent here
bwa/%_$(species).bam: $(R1) $(R2) $(singles)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -R '@RG\tID:pe\tSM:$*' -M $(species_bwa_idx) $< $(word 2,$^)| $(SAMTOOLS_BIN) view -f2 -F256 -hSb -o $(TMP_DIR)/$*_$(species)_pe.bam -
	$(BWA_BIN) mem -t $(threads) -T 30 -R '@RG\tID:single\tSM:$*' -M $(species_bwa_idx) $(word 3,$^) | $(SAMTOOLS_BIN) view -F 260 -hSb -o $(TMP_DIR)/$*_$(species)_single.bam -
	$(SAMTOOLS_BIN) sort -@ $(threads) -o $(TMP_DIR)/$*_$(species)_pe_sorted.bam $(TMP_DIR)/$*_$(species)_pe.bam
	$(SAMTOOLS_BIN) sort -@ $(threads) -o $(TMP_DIR)/$*_$(species)_single_sorted.bam $(TMP_DIR)/$*_$(species)_single.bam
	$(SAMTOOLS_BIN) merge -@ $(threads) -r $@ $(TMP_DIR)/$*_$(species)_pe_sorted.bam $(TMP_DIR)/$*_$(species)_single_sorted.bam

bwa/%_rmdup.bam: bwa/%.bam
	$(PICARD_BIN) MarkDuplicates I=$< O=$@ M=bwa/$*.metrics REMOVE_DUPLICATES=true 

%.bam.bai: %.bam
	$(SAMTOOLS_BIN) index $<

#*************************************************************************
#Calculate stats
#*************************************************************************
stats/%.bam.flgstat: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) flagstat $< > $@

stats/%.bam.stats: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) stats $< > $@

#Assumes bams are already sorted
stats/%.bam.depth.gz : $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) depth $< | gzip > $@

#*************************************************************************
# Calculate coverage
#*************************************************************************
species_fasta_ref:=~/fsbio/db/genomes/$(species)/$(species)_genome.fasta

stats/%.bam.cov.gz: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(GATK_BIN) -T DepthOfCoverage --omitIntervalStatistics --omitPerSampleStats --omitLocusTable -I $< -o $(TMP_DIR)/$(notdir $(basename $@)) -R $(species_fasta_ref)
	ls $(TMP_DIR)
	cut -f1,2 $(TMP_DIR)/$(notdir $(basename $@)) | gzip > $@

stats/%.bam.tiddit.tab: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(TIDDIT_BIN) --cov --bin_size 500 --bam $< --output $(basename $@)


#*************************************************************************
# Calculate checksums
#*************************************************************************
%.md5 : %
	md5sum $< > $@

#*************************************************************************
#Extract seqs
#*************************************************************************
fastq/%_1.fastq.gz fastq/%_2.fastq.gz: bwa/%.bam
	mkdir -p $(dir $@)
	$(PICARD_BIN) SamToFastq INPUT=$< FASTQ=fastq/$*_1.fastq.gz SECOND_END_FASTQ=fastq/$*_2.fastq.gz

fastq/%.fastq.gz: bwa/%.bam
	mkdir -p $(dir $@)
	$(PICARD_BIN) SamToFastq INPUT=$< FASTQ=$@ INTERLEAVE=True

#*************************************************************************
# Run Diamond against sprot
#*************************************************************************
diamond/%_diamond_sprot.daa : fastq/%.fastq.gz 
	mkdir -p $(dir $@)
	$(DIAMOND_BIN) blastx --sensitive -p $(threads) --db $(diamond_sprot_db) --query $< \
		--id 80 --compress 1 --daa $@ --tmpdir $(TMP_DIR) --seg yes

diamond/%.sam.gz : diamond/%.daa
	$(DIAMOND_BIN) view --daa $< --out $(basename $@) --outfmt sam --compress 1

.PHONY: clean

clean:
	rm $(TMP_DIR)/*
