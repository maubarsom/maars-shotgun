# Human contamination removal pipeline

# Author: Mauricio Barrientos-Somarribas
# Email:  mauricio.barrientos@ki.se

# Copyright 2014 Mauricio Barrientos-Somarribas
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
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef TMP_DIR
TMP_DIR=$(shell echo $$SNIC_TMP)
$(warning TMP_DIR is $(TMP_DIR))
endif

#Input and Output file prefixes
OUT_PREFIX:= $(sample_name)_hf

#Run parameters
ifndef threads
threads := 1
endif
#Choose between bwa and bowtie2
ifndef MAPPER
$(info Using bowtie2 as default mapper for host removal)
MAPPER := bowtie2
endif

#Binary config
BOWTIE2_BIN := bowtie2
BWA_BIN := bwa
SAMTOOLS_BIN := samtools
PICARD_BIN := run_picard

#Input files
R1 := $(wildcard $(read_folder)/*_R1.fq.gz)
R2 := $(wildcard $(read_folder)/*_R2.fq.gz)
singles := $(wildcard $(read_folder)/*_single.fq.gz)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.PHONY: all

all: $(addprefix $(OUT_PREFIX)_,R1.fq.gz R2.fq.gz se.fq.gz)
all: $(addprefix stats/$(OUT_PREFIX)_,pe.bam.flgstat se.bam.flgstat)

#*************************************************************************
#Map to human genome with BWA MEM
#*************************************************************************
$(bwa_hg)_pe.sam: $(R1) $(R2)
$(bwa_hg)_se.sam: $(singles)

bwa/%_pe.bam bwa/%_se.bam:
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(bwa_hg_idx) $^ | $(SAMTOOLS_BIN) view -F 256 -hSb -o $@ -

#*************************************************************************
#Map to human genome with Bowtie2 with --local
#*************************************************************************
#-M : #Max number of valid alignments
#-t report time
bowtie2_idx:= /proj/b2012214/db/bowtie2/grch38_phix
bowtie2_opts:= --local --very-sensitive-local -t -p $(threads)

bowtie2/%_pe.bam: $(R1) $(R2)
	mkdir -p $(dir $@)
	$(BOWTIE2_BIN) $(bowtie2_opts) -x $(bowtie2_idx) -1 $< -2 $(word 2,$^) | $(SAMTOOLS_BIN) view -hSb -o $@ -

bowtie2/%_se.bam: $(singles)
	mkdir -p $(dir $@)
	$(BOWTIE2_BIN) $(bowtie2_opts) -x $(bowtie2_idx) -U $< | $(SAMTOOLS_BIN) view -hSb -o $@ -

#*************************************************************************
#Calculate stats
#*************************************************************************
stats/%.bam.flgstat: $(MAPPER)/%.bam
	mkdir -p $(dir $@)
	$(SAMTOOLS_BIN) flagstat $< > $@

#*************************************************************************
#Extract unmapped reads using Samtools / Picard Tools
#*************************************************************************
#Filtering flags
#Conservative: -F2 (remove only properly mapped pairs)
#Aggressive: -f12 (keep only reads with no kind of mapping to human)
$(TMP_DIR)/%_unmapped_pe.bam: $(MAPPER)/%_pe.bam
	$(SAMTOOLS_BIN) view -F2 -hb -o $@ $^

$(TMP_DIR)/%_unmapped_se.bam: $(MAPPER)/%_se.bam
	$(SAMTOOLS_BIN) view -f4 -hb -o $@ $^

%_R1.fq.gz %_R2.fq.gz: $(TMP_DIR)/%_unmapped_pe.bam
	$(PICARD_BIN) SamToFastq INPUT=$^ FASTQ=$*_R1.fq SECOND_END_FASTQ=$*_R2.fq
	gzip $*_R1.fq
	gzip $*_R2.fq

%_se.fq.gz: $(TMP_DIR)/%_unmapped_se.bam
	$(PICARD_BIN) SamToFastq INPUT=$^ FASTQ=$*_se.fq
	gzip $*_se.fq

.PHONY: clean

clean: 
	rm *.fq
