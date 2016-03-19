# Host and PhiX contamination removal pipeline

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
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef TMP_DIR
TMP_DIR=$(shell echo $$TMPDIR)
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

.PHONY: all md5_files

FASTQ_OUT := $(addprefix $(OUT_PREFIX)_,1.fastq.gz 2.fastq.gz single.fastq.gz)

all: $(FASTQ_OUT)
all: $(addprefix stats/$(OUT_PREFIX)_,pe.$(MAPPER).bam.flgstat se.$(MAPPER).bam.flgstat)

md5_files: $(MAPPER)/$(OUT_PREFIX)_pe.bam.md5 $(MAPPER)/$(OUT_PREFIX)_se.bam.md5
md5_files: $(addsuffix .md5,$(FASTQ_OUT))

#*************************************************************************
#Map to human genome with BWA MEM
#*************************************************************************
bwa_idx:= /users/maubar/fsbio/humanrm/hg_idx/bwa/grch38_phix

bwa/%_pe.bam: $(R1) $(R2)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(bwa_idx) $^ | $(SAMTOOLS_BIN) view -F 256 -hSb -o $@ -

bwa/%_se.bam: $(singles)
	mkdir -p $(dir $@)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(bwa_idx) $^ | $(SAMTOOLS_BIN) view -F 256 -hSb -o $@ -
#*************************************************************************
#Map to human genome with Bowtie2 with --local
#*************************************************************************
#-M : #Max number of valid alignments
#-t report time
bowtie2_idx:= /users/maubar/fsbio/humanrm/hg_idx/bowtie2/grch38_phix
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
stats/%.$(MAPPER).bam.flgstat: $(MAPPER)/%.bam
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

%_1.fastq.gz %_2.fastq.gz: $(TMP_DIR)/%_unmapped_pe.bam
	$(PICARD_BIN) SamToFastq INPUT=$^ FASTQ=$*_1.fastq SECOND_END_FASTQ=$*_2.fastq
	gzip $*_1.fastq
	gzip $*_2.fastq

%_single.fastq.gz: $(TMP_DIR)/%_unmapped_se.bam
	$(PICARD_BIN) SamToFastq INPUT=$^ FASTQ=$*_single.fastq
	gzip $*_single.fastq

#*************************************************************************
# Calculate checksums
#*************************************************************************
%.md5 : %
	md5sum $< > $@

.PHONY: clean

clean:
	rm $(TMP_DIR)/*
