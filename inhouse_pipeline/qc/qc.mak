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

#Input read autodetection settings
fq_ext:=fastq.gz
#Only used for raw mode
R1_filter:=_1.
R2_filter:=_2.

#For raw mode
# filter_fx( subst, list) : Returns items in list that contain subst
filter_fx = $(foreach file,$(2),$(if $(findstring $(1),$(file)),$(file)))

R1_files := $(call filter_fx,$(R1_filter),$(wildcard $(read_folder)/*.$(fq_ext)))
R2_files := $(call filter_fx,$(R2_filter),$(wildcard $(read_folder)/*.$(fq_ext)))

#Definitions to create fastqc file targets depending on the fastq extension
fastqc_ext := $(if $(findstring fastq,$(fq_ext)),_fastqc.zip,.fq_fastqc.zip)
fastqc_txt_ext := $(if $(findstring fastq,$(fq_ext)),_fastqc.txt,.fq_fastqc.txt)
generate_fastqc_targets = $(patsubst %.$(fq_ext),%$(fastqc_txt_ext),$(notdir $(1)))

.DELETE_ON_ERROR:

.SECONDARY:

.PHONY: fastqc clean

ifdef RAW
fastqc: $(sample_name)_raw_1$(fastqc_txt_ext) $(sample_name)_raw_2$(fastqc_txt_ext)
else
fastqc: $(call generate_fastqc_targets, $(wildcard $(read_folder)/*.$(fq_ext)) )
endif

#*********************RAW MODE **************************
ifdef RAW
ifneq "$(words $(R1_files))" "$(words $(R2_files))"
$(error Different number of R1 ($(words $(R1_files))) and R2 ($(words $(R2_files))) files)
endif

ifeq "0" "$(words $(R1_files))"
$(error "No R1 or R2 files")
endif

ifeq "1" "$(words $(R1_files))"
# If only one R1 and one R2 file, create links to TMP_DIR
$(TMP_DIR)/$(sample_name)_raw_1.$(fq_ext) : $(R1_files)
	ln -s $(shell pwd)/$^ $@

$(TMP_DIR)/$(sample_name)_raw_2.$(fq_ext) : $(R2_files)
	ln -s $(shell pwd)/$^ $@
else
# If more than one R1 and R2
# Merge all Forward and Reverse reads into a single file
$(TMP_DIR)/$(sample_name)_raw_1.$(fq_ext) : $(R1_files)
	cat $^ > $@

$(TMP_DIR)/$(sample_name)_raw_2.$(fq_ext) : $(R2_files)
	cat $^ > $@
#*********
endif

endif

#*************************************************************************
# FASTQC
#*************************************************************************
FASTQC_RECIPE = $(FASTQC_BIN) --noextract -k 10 -t $(threads) -o ./ $^

#QF mode
%$(fastqc_ext): $(read_folder)/%.$(fq_ext)
	$(FASTQC_RECIPE)

#Raw mode
$(sample_name)_raw_%$(fastqc_ext): $(TMP_DIR)/$(sample_name)_raw_%.$(fq_ext)
	$(FASTQC_RECIPE)

%$(fastqc_txt_ext): %$(fastqc_ext)
	unzip -p $<  $(basename $<)/fastqc_data.txt > $@

#*************************************************************************
#CLEANING RULES
#*************************************************************************
clean:
	-rm -r reads/
	-rm -r *.html
