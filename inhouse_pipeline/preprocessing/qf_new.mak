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
R1_TMP := $(TMP_DIR)/$(sample_name)_1.$(fq_ext)
R2_TMP := $(TMP_DIR)/$(sample_name)_2.$(fq_ext)

#Outfile
OUT_PREFIX := $(sample_name)_qf

#Input read autodetection settings
R1_filter:=_1.
R2_filter:=_2.
fq_ext:=fastq.gz

#filter_fx( substring, list): Returns all items in list that contains substring
filter_fx = $(foreach file,$(2),$(if $(findstring $(1),$(file)),$(file)))

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

all: $(addprefix $(OUT_PREFIX),_R1.fq.gz _R2.fq.gz _single.fq.gz)

$(OUT_PREFIX)_%.fq.gz: 2_nesoni/$(sample_name)_%.fq.gz
	ln -f $(shell pwd)/$^ $@

#*************************************************************************
# Merge all Forward and Reverse reads into a single file
#*************************************************************************
$(R1_TMP): $(wildcard $(read_folder)/*.$(fq_ext))
	cat $(call filter_fx,$(R1_filter),$^) >> $@

$(R2_TMP): $(wildcard $(read_folder)/*.$(fq_ext))
	cat $(call filter_fx,$(R2_filter),$^) >> $@

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
