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

ifndef sample_name
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef prev_steps
prev_steps := qf
$(info 'prev_steps' is assumed to be $(prev_steps))
endif

ifndef step
step:=rmcont
$(warning Variable 'step' has been defined as '$(step)')
endif

#Input and Output file prefixes
IN_PREFIX:= $(sample_name)_$(prev_steps)
OUT_PREFIX:= $(IN_PREFIX)_$(step)

#Run parameters
ifndef threads
	$(error Define threads variable in make.cfg file)
endif

#Input files
R1 := $(read_folder)/$(IN_PREFIX)_R1.fq.gz
R2 := $(read_folder)/$(IN_PREFIX)_R2.fq.gz
singles := $(read_folder)/$(IN_PREFIX)_single.fq.gz

#Log file
log_name := $(CURDIR)/$(OUT_PREFIX)_$(shell date +%s).log
log_file := >( tee -a $(log_name) >&2 )

#Intermediate file names
bwa_hg:= $(IN_PREFIX)_bwahg
stampy_hg := $(IN_PREFIX)_bwa
no_human := $(IN_PREFIX)_nohuman

bwa_contaminants := $(no_human)_bwa
no_contaminants := $(no_human)_nocontaminants

#Function to determine interleaved flag for bwa if out file has pe or se
interleaved_flag = $(if $(filter pe,$*),-p)
#If paired-end exclude if read mapped in proper pair. If single-end include if unmapped
samtools_filter_flag = $(if $(filter pe,$*),-F2,-f4)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.PHONY: all

all: $(OUT_PREFIX)_pe.fq $(OUT_PREFIX)_se.fq

#*************************************************************************
#Create output files from the strategy
#*************************************************************************
$(OUT_PREFIX)_%.fq: $(no_human)_%.fq
	ln -s $^ $@

#*************************************************************************
#Map to GRCh37 with BWA MEM
#*************************************************************************
$(bwa_hg)_pe.sam: $(R1) $(R2)
$(bwa_hg)_se.sam: $(singles)

$(bwa_hg)_pe.sam $(bwa_hg)_se.sam:
	@echo -e "\nMapping $^ to human genome with BWA MEM @"`date`"\n\n" >> $(log_file)
	$(BWA_BIN) mem -t $(threads) -T 30 -M $(bwa_hg_idx) $^ > $@ 2> $(log_file)

#*************************************************************************
#Convert to bam removing secondary mappings
#*************************************************************************
$(bwa_hg)_pe.bam $(bwa_hg)_se.bam: $(bwa_hg)_%.bam: $(bwa_hg)_%.sam
	$(SAMTOOLS_BIN) view -F 256 -hSb -o $@ $^ 2>> $(log_file)

#*************************************************************************
#Extract unmapped reads using Picard Tools
#*************************************************************************
$(no_human)_pe.bam $(no_human)_se.bam: $(no_human)_%.bam  : $(bwa_hg)_%.bam
	@echo -e "\nRemove properly mapped pairs to human\n\n" >> $(log_file)
	$(SAMTOOLS_BIN) view $(samtools_filter_flag) -hb -o $@ $^ 2> $(log_file)

$(no_human)_%.fq : $(no_human)_%.bam
	@echo -e "\nWrite human-free fastq\n\n" >> $(log_file)
	$(PICARD_SAM2FASTQ_BIN) INPUT=$^ FASTQ=$@ INTERLEAVE=True 2>> $(log_file)
