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

ifndef read_folder
$(warning Variable 'read_folder' is not defined)
endif

ifndef TMP_DIR
TMP_DIR=$(shell echo $$TMPDIR)
$(warning TMP_DIR is $(TMP_DIR))
endif

#Run parameters
ifndef threads
threads := 8
endif

#Choose between bwa and bowtie2
ifndef MAPPER
MAPPER := bwa
$(info Using $(MAPPER) as default mapper for host removal)
endif

#Binary config
BWA_BIN := bwa
BOWTIE2_BIN := bowtie2
SAMTOOLS_BIN := samtools
PICARD_BIN := java -Xmx16g -jar ~/tools/picard-tools/2.1.1/picard.jar

#Input files
R1 := $(wildcard $(read_folder)/*_1.fastq.gz)
R2 := $(wildcard $(read_folder)/*_2.fastq.gz)
singles := $(wildcard $(read_folder)/*_single.fastq.gz)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.PHONY: all bams stats md5_files build_bwa_idxs

all: bams stats

bams: $(MAPPER)/$(sample_name)_c_albicans.bam
bams: $(MAPPER)/$(sample_name)_t_rubrum.bam

stats: $(addprefix stats/$(sample_name)_c_albicans.$(MAPPER).bam,.flgstat .stats .depth.gz)
stats: $(addprefix stats/$(sample_name)_t_rubrum.$(MAPPER).bam,.flgstat .stats .depth.gz)


# c_albicans_fastqs: fastq/$(sample_name)_c_albicans.fastq
# t_rubrum_fastqs: fastq/$(sample_name)_t_rubrum.fastq

# md5_files: $(MAPPER)/$(sample_name)_c_albicans.bam.md5
# md5_files: $(MAPPER)/$(sample_name)_t_rubrum.bam.md5

build_bwa_idxs: bwa_idx/c_albicans.bwt bwa_idx/t_rubrum.bwt

#*************************************************************************
# Build BWA index
#*************************************************************************
bwa_idx/%.bwt: fasta/%.fna
	mkdir -p $(dir $@)
	bwa index -p $(basename $@) $<

#*************************************************************************
#Map to human genome with BWA MEM
#*************************************************************************
c_albicans_bwa_idx:= ~/fsbio/2016.03_fungi_quicksearch/bwa_idx/c_albicans
t_rubrum_bwa_idx:= ~/fsbio/2016.03_fungi_quicksearch/bwa_idx/t_rubrum

#-F 260 = keep only mapped reads,no secondary mappings (256 + 4)
#-f 2 Keep reads mapped in proper pair -> we want to be a bit stringent here
bwa/%_c_albicans.bam: $(R1) $(R2) $(singles)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(c_albicans_bwa_idx) $< $(word 2,$^)| $(SAMTOOLS_BIN) view -f2 -F256 -hSb -o $(TMP_DIR)/$*_c_albicans_pe.bam -
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(c_albicans_bwa_idx) $(word 3,$^) | $(SAMTOOLS_BIN) view -F 260 -hSb -o $(TMP_DIR)/$*_c_albicans_single.bam -
	$(SAMTOOLS_BIN) sort -@ $(threads) -o $(TMP_DIR)/$*_c_albicans_pe_sorted.bam $(TMP_DIR)/$*_c_albicans_pe.bam
	$(SAMTOOLS_BIN) sort -@ $(threads) -o $(TMP_DIR)/$*_c_albicans_single_sorted.bam $(TMP_DIR)/$*_c_albicans_single.bam
	$(SAMTOOLS_BIN) merge -@ $(threads) $@ $(TMP_DIR)/$*_c_albicans_pe_sorted.bam $(TMP_DIR)/$*_c_albicans_single_sorted.bam


bwa/%_t_rubrum.bam: $(R1) $(R2) $(singles)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(t_rubrum_bwa_idx) $< $(word 2,$^)| $(SAMTOOLS_BIN) view -f2 -F256 -hSb -o $(TMP_DIR)/$*_t_rubrum_pe.bam -
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(t_rubrum_bwa_idx) $(word 3,$^) | $(SAMTOOLS_BIN) view -F 260 -hSb -o $(TMP_DIR)/$*_t_rubrum_single.bam -
	$(SAMTOOLS_BIN) sort -@ $(threads) -o $(TMP_DIR)/$*_t_rubrum_pe_sorted.bam $(TMP_DIR)/$*_t_rubrum_pe.bam
	$(SAMTOOLS_BIN) sort -@ $(threads) -o $(TMP_DIR)/$*_t_rubrum_single_sorted.bam $(TMP_DIR)/$*_t_rubrum_single.bam
	$(SAMTOOLS_BIN) merge -@ $(threads) $@ $(TMP_DIR)/$*_t_rubrum_pe_sorted.bam $(TMP_DIR)/$*_t_rubrum_single_sorted.bam

#*************************************************************************
#Calculate stats
#*************************************************************************
stats/%.$(MAPPER).bam.flgstat: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) flagstat $< > $@

stats/%.$(MAPPER).bam.stats: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) stats $< > $@

#Assumes bams are already sorted
stats/%.$(MAPPER).bam.depth.gz : $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) depth $< | gzip > $@

#*************************************************************************
# Calculate checksums
#*************************************************************************
%.md5 : %
	md5sum $< > $@

#*************************************************************************
#Extract seqs - Not needed yet
#*************************************************************************
# fastq/%.fastq: bwa/%.bam
# 	mkdir -p $(dir $@)
# 	$(PICARD_BIN) SamToFastq INPUT=$< FASTQ=$@


.PHONY: clean

clean:
	rm $(TMP_DIR)/*
