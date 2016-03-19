# Pipeline to map reads against staph delta toxin

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
PICARD_BIN := java -Xmx16g -jar /users/maubar/tools/picard-tools/1.138/picard.jar

#Input files
R1 := $(wildcard $(read_folder)/*_1.fastq.gz)
R2 := $(wildcard $(read_folder)/*_2.fastq.gz)
singles := $(wildcard $(read_folder)/*_single.fastq.gz)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.PHONY: all bams toxin_fastqs md5_files build_bwa_idxs

all: bams toxin_fastqs

#bams: stats/$(OUT_PREFIX)_pe.$(MAPPER).bam.flgstat
bams: stats/$(sample_name)_deltatoxin.$(MAPPER).bam.flgstat
bams: stats/$(sample_name)_alphatoxin.$(MAPPER).bam.flgstat

toxin_fastqs: fastq/$(sample_name)_deltatoxin.fastq
toxin_fastqs: fastq/$(sample_name)_alphatoxin.fastq

#md5_files: $(MAPPER)/$(OUT_PREFIX)_pe.bam.md5
md5_files: $(MAPPER)/$(sample_name)_deltatoxin.bam.md5
md5_files: $(MAPPER)/$(sample_name)_alphatoxin.bam.md5

build_bwa_idxs: bwa_idx/s_aureus_delta_toxin.bwt bwa_idx/s_aureus_alpha_toxin.bwt

#*************************************************************************
# Build BWA index
#*************************************************************************
bwa_idx/%.bwt: fasta/%.fasta
	mkdir -p $(dir $@)
	bwa index -p $(basename $@) $<

#*************************************************************************
#Map to human genome with BWA MEM
#*************************************************************************
deltatoxin_bwa_idx:= /users/k1217790/fsbio/microbiomics/2015.11_deltatoxin/bwa_idx/s_aureus_delta_toxin
alphatoxin_bwa_idx:= /users/k1217790/fsbio/microbiomics/2015.11_deltatoxin/bwa_idx/s_aureus_alpha_toxin

#-F 260 = keep only mapped reads,no secondary mappings (256 + 4)
bwa/%_deltatoxin.bam: $(R1) $(R2) $(singles)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(deltatoxin_bwa_idx) <(cat $^) | $(SAMTOOLS_BIN) view -F 260 -hSb -o $@ -

bwa/%_alphatoxin.bam: $(R1) $(R2) $(singles)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(alphatoxin_bwa_idx) <(cat $^) | $(SAMTOOLS_BIN) view -F 260 -hSb -o $@ -

#*************************************************************************
#Extract seqs
#*************************************************************************
fastq/%.fastq: bwa/%.bam
	mkdir -p $(dir $@)
	$(PICARD_BIN) SamToFastq INPUT=$< FASTQ=$@

#*************************************************************************
#Calculate stats
#*************************************************************************
stats/%.$(MAPPER).bam.flgstat: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) flagstat $< > $@

stats/%.$(MAPPER).bam.stats: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) stats $< > $@

stats/%.$(MAPPER).bam.depth.gz : $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) sort $< | $(SAMTOOLS_BIN) depth - | gzip > $@

#*************************************************************************
# Calculate checksums
#*************************************************************************
%.md5 : %
	md5sum $< > $@

.PHONY: clean

clean:
	rm $(TMP_DIR)/*
