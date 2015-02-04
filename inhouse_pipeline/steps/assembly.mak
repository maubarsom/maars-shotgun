# Assembly strategies pipeline

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
$(warning Variable 'read_folder' will be assumed to be "./")
read_folder := ./
endif

ifndef prev_steps
prev_steps := qf_rmcont
$(warning 'prev_steps' is assumed to be $(prev_steps))
endif

ifndef step
step:= asm
$(warning Variable 'step' has been defined as '$(step)')
endif

#Input and Output file prefixes
IN_PREFIX := $(sample_name)_$(prev_steps)
OUT_PREFIX:= $(IN_PREFIX)_$(step)

#Reads
INPUT_PAIRED_END := $(read_folder)/$(IN_PREFIX)_pe.fq
INPUT_SINGLE_END := $(read_folder)/$(IN_PREFIX)_se.fq

#Logging
log_name := $(CURDIR)/$(OUT_PREFIX)_$(shell date +%s).log
log_file := >( tee -a $(log_name) >&2 )

#Run params
ifndef threads
	$(error Define threads variable in make.cfg file)
endif

ifndef ASSEMBLERS
	$(error Define ASSEMBLERS variable in make.cfg file)
endif

#Creates a OUT_PREFIX_assembler_ctgs_filt.fa for each assembler
OUT_FILES:= $(addsuffix _ctgs_filt.fa,$(addprefix $(OUT_PREFIX)_,$(ASSEMBLERS)))

#Ray
ray_kmer := 31

#Fermi parameters
fermi_overlap := 40

#Fermi pe parameters
fermi_pe_overlap := 40
#Abyss parameters
abyss_kmer:= 30

#SGA parameters
sga_ec_kmer := 41
sga_cov_filter := 2
sga_min_overlap := 200
sga_assemble_overlap := 111
TRIM_LENGTH := 400

#Masurca parameters
masurca_kmer := 21
masurca_pe_stats := 300 80
masurca_se_stats := 250 50

#Samtools parameters
#If paired-end exclude if read mapped in proper pair. If single-end include if unmapped
samtools_filter_flag = $(if $(filter pe,$*),-F2,-f4)

#Delete produced files if step fails
.DELETE_ON_ERROR:

#Avoids the deletion of files because of gnu make behavior with implicit rules
.SECONDARY:

.INTERMEDIATE: $(TMP_DIR)/singletons_pe.fq $(TMP_DIR)/singletons_se.fq $(TMP_DIR)/$(OUT_PREFIX)_allctgs.fa.bwt

.PHONY: all

all: $(OUT_PREFIX)_allctgs.fa singletons/pe_to_contigs.sam singletons/se_to_contigs.sam

#Concatenate the contigs from all assembly strategies into a single file
$(OUT_PREFIX)_allctgs.fa: $(OUT_FILES)
	cat $^ > $@

$(OUT_PREFIX)_%.fa: singletons/singletons_%.fa
	ln -s $^ $@

$(OUT_PREFIX)_%.fq.gz: $(STRATEGY)/$(sample_name)_%.fq.gz
	ln -s $^ $@

#*************************************************************************
#MetaRay
#*************************************************************************
raymeta/Contigs.fasta: $(INPUT_PAIRED_END) $(INPUT_SINGLE_END)
	@echo -e "\nAssembling reads with Ray Meta\n\n" > $(log_file)
	mpiexec -n 16 Ray Meta -k $(ray_kmer) -i $(INPUT_PAIRED_END) -s $(INPUT_SINGLE_END) -o $(dir $@) 2>> $(log_file)

#Ray Assembler duplicates contigs for some reason, probably due to MPI
$(OUT_PREFIX)_raymeta_contigs.fa: raymeta/Contigs.fasta
	../scripts/deduplicate_raymeta_ctgs.py -o $@ $^ 2>> $(log_file)

#*************************************************************************
#Megahit
#*************************************************************************
megahit/final.contigs.fa: $(INPUT_PAIRED_END) $(INPUT_SINGLE_END)
	$(MEGAHIT_BIN) -m 5e10 -l $(READ_LEN) --k-max 81 --input-cmd "cat $^" --cpu-only -t $(threads) -o $(dir $@)

$(OUT_PREFIX)_megahit_contigs.fa: megahit/final.contigs.fa
	ln -s $^ $@

#*************************************************************************
#Extract contigs > 300 bp
#*************************************************************************
#Seqtk is used to sample sequences > 300bp
#Awk renames contigs to make them friendly for RAPSEARCH and other tools that do not support spaces in the names
%_ctgs_filt.fa : %_contigs.fa
	$(SEQTK_BIN) seq -L 300 $^ | awk -vPREFIX=$* 'BEGIN {counter=1; split(PREFIX,fields,"_asm_"); ASM=fields[2];} /^>/ {print ">" ASM "_" counter ;counter+=1;} ! /^>/{print $0;}' > $@ 2>> $(log_file)

#*************************************************************************
#Extract singletons
#*************************************************************************
$(TMP_DIR)/$(OUT_PREFIX)_allctgs.fa.bwt: $(OUT_PREFIX)_allctgs.fa
	$(BWA_BIN) index -p $(basename $@) $<

singletons/pe_to_contigs.sam: $(INPUT_PAIRED_END) $(TMP_DIR)/$(OUT_PREFIX)_allctgs.fa.bwt
	mkdir -p singletons
	$(BWA_BIN) mem -t $(threads) -T 30 -M -p $(basename $(word 2,$^)) $< > $@ 2>> $(log_file)

singletons/se_to_contigs.sam: $(INPUT_SINGLE_END) $(TMP_DIR)/$(OUT_PREFIX)_allctgs.fa.bwt
	mkdir -p singletons
	$(BWA_BIN) mem -t $(threads) -T 30 -M    $(basename $(word 2,$^)) $< > $@ 2>> $(log_file)

.PHONY: clean
clean:
	-rm -r sga/
	-rm -r abyss/
	-rm -r raymeta/
	-rm -r fermi/
	-rm -r masurca/
	-rm *.contigs.fa *.ctgs_filt.fa
