# Pipeline for read QC inspection

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

SHELL := /bin/bash

#External parameters
# 1) basename
# 2) step
# 3) read_folder

ifndef sample_name
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef TMP_DIR
TMP_DIR := $(shell echo "$$SNIC_TMP")
endif

ifndef threads
threads := $(shell nproc)
endif

#Tool bin and db configurations
FASTQC_BIN := fastqc

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Keep fastqc zip files
.SECONDARY:

.PHONY: fastqc clean

fastqc: $(sample_name)_1_fastqc.txt $(sample_name)_2_fastqc.txt

#******************************************************************
# Raw reads
#******************************************************************
$(TMP_DIR)/$(sample_name)_1.fastq.gz : $(wildcard $(read_folder)/*_1.fastq.gz)
	cat $^ >> $@

$(TMP_DIR)/$(sample_name)_2.fastq.gz : $(wildcard $(read_folder)/*_2.fastq.gz)
	cat $^ >> $@

#*************************************************************************
#FASTQC
#*************************************************************************
%_fastqc.zip: $(TMP_DIR)/%.fastq.gz
	$(FASTQC_BIN) --noextract -k 10 -t $(threads) -o ./ $^

%_fastqc.txt: %_fastqc.zip
	unzip -p $<  $*_fastqc/fastqc_data.txt > $@

#*************************************************************************
#CLEANING RULES
#*************************************************************************
clean:
	-rm -r reads/
	-rm -r *.html
