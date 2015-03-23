# Human contamination removal

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

#Input files
#Input files are assumed to share a common prefix, with the suffixes _R1.fq.gz, _R2.fq.gz, _single.fq.gz
#E.g
#   sample1_R1.fq.gz, sample1_R2.fq.gz, sample1_single.fq.gz
#   IN_PREFIX=sample1
#
ifndef IN_PREFIX
	$(error Variable 'IN_PREFIX' is not defined)
endif

#Split IN_PREFIX in dir and prefix part
IN_DIR := $(dir IN_PREFIX)
IN_PREFIX := $(basename IN_PREFIX)

#Load configuration file
ifndef cfg_file
        $(error Config file variable 'cfg_file' not set)
endif
include $(cfg_file)

#Output file
OUT_DIR := out
OUT_PREFIX:= $(IN_PREFIX)_humanrm

#Input files
R1 := $(IN_DIR)/$(IN_PREFIX)_R1.fq.gz
R2 := $(IN_DIR)/$(IN_PREFIX)_R2.fq.gz
singles := $(IN_DIR)/$(IN_PREFIX)_single.fq.gz

#Intermediate file names
bwa_hg:= 1_bwa_hg
no_human := 2_nohuman

#If paired-end exclude if read mapped in proper pair. If single-end include if unmapped
samtools_filter_flag = $(if $(filter _pe,$*),-F2,-f4)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.PHONY: all stats

all: $(addprefix $(OUT_DIR)/$(OUT_PREFIX),_pe.fq _se.fq ) stats

stats: $(addprefix stats/$(IN_PREFIX)_,pe_to_human.txt se_to_human.txt insert_size.txt)
#*************************************************************************
#Create output files from the strategy
#*************************************************************************
$(OUT_DIR)/$(OUT_PREFIX)_%.fq: $(no_human)/$(IN_PREFIX)_%.fq
	mkdir -p $(dir $@)
	ln -s $(shell pwd)/$^ $@

#*************************************************************************
#Map to GRCh37 with BWA MEM
#*************************************************************************
$(bwa_hg)/$(IN_PREFIX)_pe.bam: $(R1) $(R2)
$(bwa_hg)/$(IN_PREFIX)_se.bam: $(singles)

$(bwa_hg)/$(IN_PREFIX)_pe.bam $(bwa_hg)/$(IN_PREFIX)_se.bam:
	set -o pipefail; $(BWA_BIN) mem -t $(threads) -T 30 -M $(bwa_hg_idx) $^ | $(SAMTOOLS_BIN) view -F 256 -hSb -o $@ -

#*************************************************************************
# Calculate mapping to human stats
#*************************************************************************
stats/%_to_human.txt: $(bwa_hg)/%.bam
	$(SAMTOOLS_BIN) flagstat $^ > $@

#Requires bam to be sorted (by coordinate?) -.-
stats/%_insert_size.txt: $(bwa_hg)/%_pe.bam
	$(PICARD_JAR) CollectInsertSizeMetrics HISTOGRAM_FILE=$*_hist.txt INPUT=$^ OUTPUT=$@ ASSUME_SORTED=True

#*************************************************************************
#Extract unmapped reads  (non-human reads)
#*************************************************************************
$(no_human)/%.bam : $(bwa_hg)/%.bam
	$(SAMTOOLS_BIN) view $(samtools_filter_flag) -hb -o $@ $^ 

#*************************************************************************
# Extract reads from the bam file to a Fastq file
#*************************************************************************
$(no_human)/%.fq : $(no_human)/%.bam
	$(PICARD_JAR) SamToFastq INPUT=$^ FASTQ=$@ INTERLEAVE=True 

