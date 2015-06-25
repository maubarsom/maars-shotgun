###README
This folder contains the quality filtering and trimming for all the MAARS samples.

Quality trimming steps:
1. Nesoni for base quality trimming
2. Cutadapt for illumina adapter trimming

The scripts folder contains the files to process the data:
 * qf.mak: Implementation of quality trimming with min length 75 and min base quality > 20
 * qf_lite.mak: An implementation of light quality trimming following ideas from [this article](http://dx.doi.org/10.3389/fgene.2014.00013)
 * uppmax.cfg: configuration file required to run qf.mak (soon to be removed)
