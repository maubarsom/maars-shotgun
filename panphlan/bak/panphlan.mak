SHELL := /bin/bash

#External parameters
# 1) basename
# 2) read_folder
# 3) species

ifndef sample_name
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef species
$(error Variable 'species' is not defined) 
endif 

ifndef TMP_DIR
TMP_DIR=$(shell echo $$TMPDIR)
$(warning TMP_DIR is $(TMP_DIR))
endif

ifndef threads
threads := $(shell nproc)
endif

#Metaphlan bin and db config
panphlan_dir := /users/maubar/tools/panphlan/a25bc29ad4ec
panphlan_db_dir := /users/maubar/fsbio/db/panphlan

#Input files extension
fq_ext:=fastq.gz

.DELETE_ON_ERROR:

.PHONY: all

all: $(sample_name)_panphlan_$(species).csv.bz2

#******************************************************************
# Run Panphlan on a sample against the selected species pangenome
#******************************************************************
$(sample_name)_panphlan_$(species).csv.bz2: $(wildcard $(read_folder)/*.$(fq_ext))
	zcat $^ | $(panphlan_dir)/panphlan_map.py -c $(species) \
			--i_bowtie2_indexes $(panphlan_db_dir)/$(species) \
			-o $@ -p $(threads) --verbose --tmp TMP_$(species)

