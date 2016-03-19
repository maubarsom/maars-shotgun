SHELL := /bin/bash

#External parameters
# 1) basename
# 2) read_folder
# 3) TMP_DIR

ifndef sample_name
$(error Variable 'sample_name' is not defined)
endif

ifndef read_folder
$(error Variable 'read_folder' is not defined)
endif

ifndef TMP_DIR
$(error Variable 'TMP_DIR' is not defined)
endif

ifndef threads
threads := $(shell nproc)
endif

#Input read autodetection configuration
# fq_ext is mandatory for all!
# For pe R1 and R2_filter
# For se set single_filter
R1_filter:=_1.
R2_filter:=_2.
single_filter:=_singleton.
fq_ext:=fastq.gz

smart_cat := $(if $(findstring gz,$(fq_ext)),zcat,$(if $(findstring bz2,$(fq_ext)),bzcat,cat))
kraken_compression_flag := $(if $(findstring .gz,$(fq_ext)),--gzip-compressed,$(if $(findstring bz2,$(fq_ext)),--bzip2-compressed))

#filter_fx( substring, list)
filter_fx = $(foreach file,$(2),$(if $(findstring $(1),$(file)),$(file)))

#Kraken bin and db config
kraken_bin := /home/maubar/tools/bin/kraken
kraken_report_bin := /home/maubar/tools/bin/kraken-report
kraken_db := /home/maubar/db/kraken150519

.DELETE_ON_ERROR:

.SECONDARY:

.PHONY: pe se all_reads

all_reads: $(sample_name)_kraken.report

pe: $(sample_name)_raw_pe_kraken.report

se: $(sample_name)_raw_se_kraken.report

pe_se: $(sample_name)_raw_all_kraken.report

#******************************************************************
# Raw reads
#******************************************************************
$(TMP_DIR)/$(sample_name).$(fq_ext) : $(wildcard $(read_folder)/*.$(fq_ext))
	cat $^ >> $@

$(TMP_DIR)/$(sample_name)_R1.$(fq_ext) : $(wildcard $(read_folder)/*.$(fq_ext))
	cat $(call filter_fx,$(R1_filter),$^)  >> $@

$(TMP_DIR)/$(sample_name)_R2.$(fq_ext) : $(wildcard $(read_folder)/*.$(fq_ext))
	cat $(call filter_fx,$(R2_filter),$^)  >> $@

$(TMP_DIR)/$(sample_name)_single.$(fq_ext) : $(wildcard $(read_folder)/*.$(fq_ext))
	cat $(call filter_fx,$(single_filter),$^)  >> $@


#Run Kraken for Paired ends, singletons or all reads

%_pe_kraken.out: $(TMP_DIR)/$(sample_name)_R1.$(fq_ext) $(TMP_DIR)/$(sample_name)_R2.$(fq_ext)
	$(kraken_bin) --preload --db $(kraken_db) --threads $(threads) $(kraken_compression_flag) --fastq-input --paired --check-names --output $@ $^

%_se_kraken.out: $(TMP_DIR)/$(sample_name)_single.$(fq_ext)
	$(kraken_bin) --preload --db $(kraken_db) --threads $(threads) $(kraken_compression_flag)--fastq-input --output $@ $^

%_kraken.out: $(TMP_DIR)/$(sample_name).$(fq_ext)
	$(kraken_bin) --preload --db $(kraken_db) --threads $(threads) $(kraken_compression_flag)--fastq-input --output $@ $^


#Recipe for Kraken Report
%_kraken.report: %_kraken.out
	$(kraken_report_bin) --db $(kraken_db) $^ > $@ 

%_all_kraken.report: %_pe_kraken.out %_se_kraken.out
	$(kraken_report_bin) --db $(kraken_db) $^ > $@ 
