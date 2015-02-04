#!/usr/bin/env python
"""
Script to generate sbatch files to run the pipeline in the Uppmax Cluster

Author: Mauricio Barrientos-Somarribas
Email:  mauricio.barrientos@ki.se

Copyright 2014 Mauricio Barrientos-Somarribas

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import sys
import argparse
import os
import os.path

#Time of script execution and logging module
import time
import logging

# import re
#
# import itertools
# from collections import *

#****************Begin of Main ***************
def main(args):
	steps = ["qc","qf","rmcont","asm","taxassign" ]
	modules = {
		"qc": ["+java/sun_jdk1.7.0_25","+R/3.1.0", "+jellyfish/2.0.0" ],
		"qf" :["+java/sun_jdk1.7.0_25","+R/3.1.0", "+jellyfish/2.0.0" ],
		"rmcont":["+bwa/0.7.10","+picard/1.118"],
		"asm":["-gcc"],
		"taxassign":["+blast/2.2.29+","+hmmer/3.1b1-gcc"]
	}

	step_duration = {
		"qc": "06:00:00",
		"qf" : "06:00:00",
		"rmcont": "06:00:00",
		"asm": "06:00:00",
		"taxassign": "1-00:00:00"
	}

	step_makefile_rule = {
		"qc": "raw_qc",
		"qf" : "qf_qc",
		"rmcont": "contamination_rm",
		"asm": "assembly",
		"taxassign": "tax_assign"
	}

	#Create log file for sbatch logs
	log_folder = "log/"
	if not os.path.exists(log_folder):
		os.makedirs(log_folder)

	for step in steps:
		step_filename = os.path.join(args.output_folder,"run_"+step+".sh")
		with open(step_filename, "w") as fh:
			fh.write("#!/bin/bash\n")
			fh.write("#SBATCH -A "+args.project_id+"\n")
			fh.write("#SBATCH -p node -n 16\n")
			fh.write("#SBATCH -t "+step_duration[step]+"\n")
			fh.write("#SBATCH -J "+args.sample_name+"_"+step+"\n")
			fh.write("#SBATCH -o log/"+step+"-%j.out"+"\n")
			fh.write("#SBATCH -e log/"+step+"-%j.err"+"\n")

			fh.write("#SBATCH --mail-user mauricio.barrientos@ki.se\n")
			fh.write("#SBATCH --mail-type=ALL\n\n")

			fh.write( modules_to_load(modules[step]) )
			#Unload default python and samtools (using anaconda)
			fh.write( modules_to_load(["-python","-samtools"]))

			fh.write("set -euo pipefail\n\n") #Fast failing for bash script

			#Assumes cfg/uppmax.cfg is the template to use
			#TODO: choose base configuration file from arguments
			tmp_cfg_file = "cfg/uppmax_"+step+".cfg"
			fh.write("cp cfg/uppmax.cfg "+tmp_cfg_file +"\n")
			fh.write('echo "export TMP_DIR := $SNIC_TMP" >> '+tmp_cfg_file+"\n")
			fh.write("make -r sample_name="+args.sample_name+" cfg_file="+tmp_cfg_file+" "+step_makefile_rule[step]+"\n")
			fh.write("rm "+tmp_cfg_file)

#*****************End of Main**********************

def modules_to_load(modules):
	module_string = ""
	for mod in modules:
		if mod[0] == "+":
			module_string += "module load "+mod[1:]+"\n"
		elif mod[0] == "-":
			module_string += "module unload "+mod[1:]+"\n"
		else:
			logging.error("Module definition malformed")
			sys.exit(1)

	return module_string


def validate_args(args):
	return True


if __name__ == '__main__':
	#Process command line arguments
	parser = argparse.ArgumentParser(description="Script that generates sbatch scripts to run pipeline in a SLURM-based cluster like Uppmax")

	parser.add_argument("sample_name",help="Sample name that will be used on the pipeline")
	parser.add_argument("-o","--output-folder", default="./", help="Folder where to output the scripts" )
	parser.add_argument("-A","--project_id", default="b2011088",help="Slurm project id")
	args = parser.parse_args()

	#Initialize log
	log_level = logging.INFO
	logging.basicConfig(stream=sys.stderr,level=log_level)

	if validate_args(args):
		time_start = time.time()
		main( args )
		logging.info("Time elapsed: "+str(time.time() - time_start)+"\n")
	else:
		logging.error("Invalid arguments. Exiting script\n")
		sys.exit(1)
