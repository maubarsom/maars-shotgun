SHELL := /bin/bash

#External parameters
# 1) basename
# 2) read_folder

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

#Metaphlan bin and db config
#Uppmax
mpa_dir := /home/mauricio/local/share/biobakery-metaphlan2-1c047f491780
#Hamlet
#mpa_dir := /labcommon/tools/metaphlan2

mpa_bin := $(mpa_dir)/metaphlan2.py
mpa_pkl := $(mpa_dir)/db_v20/mpa_v20_m200.pkl
mpa_bowtie2db := $(mpa_dir)/db_v20/mpa_v20_m200

.DELETE_ON_ERROR:

.PHONY: raw

raw: $(sample_name)_raw_metaphlan.txt

#******************************************************************
# Raw reads
#******************************************************************
$(TMP_DIR)/reads_raw.fq.gz : $(wildcard $(read_folder)/*.fastq.gz)
	cat $^ >> $@

%_raw_metaphlan.txt: $(TMP_DIR)/reads_raw.fq.gz
	$(mpa_bin) --mpa_pkl $(mpa_pkl) --bowtie2db $(mpa_bowtie2db) \
		--bowtie2out $*.bowtie2.bz2 --nproc $(threads) --input_type multifastq \
		--biom $*_raw_metaphlan.biom $< $@
