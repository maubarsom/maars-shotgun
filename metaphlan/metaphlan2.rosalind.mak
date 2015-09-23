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
TMP_DIR=$(shell echo $$TMPDIR)
$(warning TMP_DIR is $(TMP_DIR))
endif

ifndef threads
threads := $(shell nproc)
endif

#Metaphlan bin and db config
mpa_dir := /users/maubar/tools/metaphlan2/4864b9107195

mpa_bin := $(mpa_dir)/metaphlan2.py
mpa_pkl := $(mpa_dir)/db_v20/mpa_v20_m200.pkl
mpa_bowtie2db := $(mpa_dir)/db_v20/mpa_v20_m200

#Input files extension
fq_ext:=fastq.gz

.DELETE_ON_ERROR:

.PHONY: all

all: $(sample_name)_mpa2_relAbAndReads.txt

#******************************************************************
# Concat all reads into a single file
#******************************************************************
$(TMP_DIR)/$(sample_name).$(fq_ext) : $(wildcard $(read_folder)/*.$(fq_ext))
	cat $^ > $@

#******************************************************************
# Run Metaphlan2 on the concat'd fastq file
#******************************************************************
#Old processing command for first files
# Lacks the rel_ab_w_read_stats for the output, but the
# mapping step is equivalent for all
$(sample_name)_mpa2.txt: $(TMP_DIR)/$(sample_name).$(fq_ext)
	$(mpa_bin) --mpa_pkl $(mpa_pkl) --bowtie2db $(mpa_bowtie2db) \
		--bowtie2out $(basename $@).bowtie2.bz2 --nproc $(threads) --input_type multifastq \
		--biom $(basename $@).biom $< $@

ifndef RERUN
# New processing command with MPA2, adds the rel_ab_w_reads_stats parameter
# to include estimated reads mapping to each clade and sample_id_key identifier
$(sample_name)_mpa2_relAbAndReads.txt: $(TMP_DIR)/$(sample_name).$(fq_ext)
	$(mpa_bin) --mpa_pkl $(mpa_pkl) --bowtie2db $(mpa_bowtie2db) \
		--bowtie2out $(basename $@).bowtie2.bz2 --nproc $(threads) --input_type multifastq \
		--sample_id_key $(sample_name) -t rel_ab_w_read_stats \
		--biom $(basename $@).biom $< $@
else
# Generate the new abundance calculation from the mapping generated
# by the old command
$(sample_name)_mpa2_relAbAndReads.txt: $(sample_name)_mpa2.bowtie2.bz2
	$(mpa_bin) --mpa_pkl $(mpa_pkl) --bowtie2db $(mpa_bowtie2db) \
		--nproc $(threads) --input_type bowtie2out \
		--sample_id_key $(sample_name) -t rel_ab_w_read_stats \
		--biom $(basename $@).biom $< $@
endif
