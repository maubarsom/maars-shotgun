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

ifndef step
$(error Variable 'step' is not defined)
endif

ifndef read_folder
$(warning Variable 'read_folder' will be assumed to be "./")
read_folder := ./
endif

ifndef TMP_DIR
TMP_DIR := /tmp
endif

#Outfile
OUT_PREFIX:=$(sample_name)_$(step)

#Reads
R1:= $(wildcard $(read_folder)/*R1*.f*q.gz  $(read_folder)/*_1.f*q.gz)
R2:= $(wildcard $(read_folder)/*R2*.f*q.gz  $(read_folder)/*_2.f*q.gz)

SINGLE := $(wildcard $(read_folder)/*single.f*q.gz )

ifneq ($(words $(R1) $(R2)),2)
$(error More than one R1 or R2 $(words $(R1) $(R2)))
endif

#Hack to decode target fastqc depending on the file extension of the reads f[ast]q[.gz]
fq2fastqc = $(patsubst %.fq,%.fq_fastqc.zip,$(patsubst %.fastq,%_fastqc.zip,$(1)))
gz_filtered_reads := $(notdir $(basename $(filter %.gz,$(R1) $(R2))) $(filter-out %.gz,$(R1) $(R2)))
fastqc_targets := $(call fq2fastqc,$(gz_filtered_reads))
$(info $(fastqc_targets))

#Logging
log_name := $(CURDIR)/qc_$(step)_$(shell date +%s).log
log_file := >( tee -a $(log_name) >&2 )

#Run params
ifndef threads
	$(error Define threads variable in make.cfg file)
endif

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.INTERMEDIATE: $(OUT_PREFIX)_sga.fq %_sga.sai %_k17.jf %_sga.preqc

.PHONY: all fastqc basic kmer_analysis

all: basic kmer_analysis

#Basic
basic: $(OUT_PREFIX)_pe_stats.txt fastqc

ifdef SINGLE
basic: $(OUT_PREFIX)_se_stats.txt
endif

#Computationally intensive
kmer_analysis: $(OUT_PREFIX)_sga_preqc.pdf $(OUT_PREFIX)_k17.hist.pdf

fastqc: $(fastqc_targets)
#*************************************************************************
#Import helper scripts - Check paths are ok
#*************************************************************************
plot_kmer_histogram.R:
	ln -s ../scripts/plot_kmer_histogram.R

#*************************************************************************
#FASTQC
#*************************************************************************

FASTQC_RECIPE = $(FASTQC_BIN) --noextract -k 10 -o ./ $^ 2>> $(log_file)

%_fastqc.zip: $(read_folder)/%.fastq.gz
	$(FASTQC_RECIPE)

%_fastqc.zip: $(read_folder)/%.fastq
	$(FASTQC_RECIPE)

%.fq_fastqc.zip: $(read_folder)/%.fq.gz
	$(FASTQC_RECIPE)

%.fq_fastqc.zip: $(read_folder)/%.fq
	$(FASTQC_RECIPE)

#*************************************************************************
#SGA PREQC
#*************************************************************************
# First, preprocess the data to remove ambiguous basecalls
$(OUT_PREFIX)_sga.fq: $(R1) $(R2)
	$(SGA_BIN) preprocess --pe-mode 1 -o $@ $^ >&2 2>> $(log_file)

# Build the index that will be used for error correction
# Error corrector does not require the reverse BWT
%_sga.sai: %_sga.fq
	$(SGA_BIN) index -a ropebwt -t $(threads) --no-reverse $(notdir $^) >&2 2>> $(log_file)

#Run SGA preqc
%_sga.preqc: %_sga.fq %_sga.sai
	$(SGA_BIN) preqc -t $(threads) --force-EM $< > $@ 2>> $(log_file)

#Create SGA preqc report
%_sga_preqc.pdf: %_sga.preqc
	$(SGA_PREQC_REPORT_BIN) -o $(basename $@) $^

#*************************************************************************
#JELLYFISH 2
#*************************************************************************
%_k17.jf: %_sga.fq
	$(JELLYFISH2_BIN) count -s 8G -C -m 17 -t $(threads) -o $@ $^ 2>> $(log_file)

%_k17.hist: %_k17.jf
	$(JELLYFISH2_BIN) histo -t $(threads) $^ -o $@ 2>> $(log_file)

%_k17.hist.pdf: %_k17.hist | plot_kmer_histogram.R
	Rscript plot_kmer_histogram.R $^ $@

#*************************************************************************
#PRINSEQ
#*************************************************************************
%_pe_stats.txt: $(R1) $(R2)
	gunzip -c $< > $(TMP_DIR)/tmp_R1.fq
	gunzip -c $(word 2,$^) > $(TMP_DIR)/tmp_R2.fq
	$(PRINSEQ_BIN) -fastq $(TMP_DIR)/tmp_R1.fq -fastq2 $(TMP_DIR)/tmp_R2.fq -stats_all > $@
	rm $(TMP_DIR)/tmp_R1.fq $(TMP_DIR)/tmp_R2.fq

%_se_stats.txt: $(SINGLE)
	gunzip -c $< > $(TMP_DIR)/tmp_single.fq
	$(PRINSEQ_BIN) -fastq $(TMP_DIR)/tmp_single.fq -stats_all > $@
	rm $(TMP_DIR)/tmp_single.fq

#*************************************************************************
#CLEANING RULES
#*************************************************************************
.PHONY: clean-tmp clean-out

clean-tmp:
	-rm $(OUT_PREFIX)_sga.{fq,sai,bwt}
	-rm *.jf
	-rm plot_kmer_histogram.R

clean-out:
	-rm *_fastqc.zip #Fastqc
	-rm *.hist *.hist.pdf #Jellyfish
	-rm *.preqc *.pdf #SGA preqc
