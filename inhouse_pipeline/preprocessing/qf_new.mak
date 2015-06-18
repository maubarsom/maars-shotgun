# Raw reads quality filtering pipeline for MAARS samples

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

#Temporary merged R1 and R2
R1_TMP := $(TMP_DIR)/$(sample_name)_1.fastq.gz
R2_TMP := $(TMP_DIR)/$(sample_name)_2.fastq.gz

#Outfile
OUT_DIR := out
OUT_PREFIX := $(sample_name)_qf

#Load configuration file
ifndef cfg_file
	$(error Config file variable 'cfg_file' not set)
endif
include $(cfg_file)

MIN_READ_LENGTH := 50

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Uncomment for debugging, otherwise make deletes all intermediary files
.SECONDARY:

.PHONY: all

all: $(addprefix $(OUT_DIR)/$(OUT_PREFIX),_R1.fq.gz _R2.fq.gz _single.fq.gz)

$(OUT_DIR)/$(OUT_PREFIX)_%.fq.gz: 2_nesoni/$(sample_name)_%.fq.gz
	mkdir -p $(dir $@)
	ln -f $(shell pwd)/$^ $@

#*************************************************************************
# Merge all Forward and Reverse reads into a single file
#*************************************************************************
$(R1_TMP) : $(wildcard $(read_folder)/*R1*.f*q.gz  $(read_folder)/*_1.f*q.gz)
	cat $^ > $@

$(R2_TMP) : $(wildcard $(read_folder)/*R2*.f*q.gz  $(read_folder)/*_2.f*q.gz)
	cat $^ > $@

#*************************************************************************
# Call to NESONI for light quality trimming
#*************************************************************************
1_nesoni/%_R1.fq.gz 1_nesoni/%_R2.fq.gz 1_nesoni/%_single.fq.gz: $(R1_TMP) $(R2_TMP)
	mkdir -p $(dir $@)
	$(NESONI_BIN) clip --adaptor-clip no --homopolymers yes --qoffset 33 --quality 5 --length 50 \
		--out-separate yes $(nesoni_out_prefix) pairs: $^

#*************************************************************************
# Call to CUTADAPT to remove Illumina adapters from short fragments
#*************************************************************************
2_cutadapt/%_R1.fq.gz 2_cutadapt/%_R2.fq.gz: 1_nesoni/%_R1.fq.gz 1_nesoni/%_R2.fq.gz
	mkdir -p $(dir $@)
	#Remove Illumina double(or single index) adapters from fwd and rev pairs
	$(CUTADAPT_BIN) --cut=6 -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT \
									--overlap=5 --error-rate=0.1 --minimum-length $(MIN_READ_LENGTH) \
									-o $(dir $@)/$*_R1.fq.gz -p $(dir $@)/$*_R2.fq.gz $< $(word 2,$^)

2_cutadapt/%_single.fq.gz: 1_nesoni/%_single.fq.gz
	#Remove Illumina double(or single index) adapters from singletons
	$(CUTADAPT_BIN) --cut=6 -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC -a AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT \
									--overlap=5 --error-rate=0.1 --minimum-length $(MIN_READ_LENGTH) \
									-o $@ $<

.PHONY: clean
clean:
	-rm 1_nesoni/*.fq.gz
	-rm 2_cutadapt/*.fq.gz