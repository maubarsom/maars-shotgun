"""
Script to create a directory structure from selected samples
and link the appropriate fastq files
"""
#!/usr/bin/python
import os
import subprocess
import os.path
import sys
import pandas as pd
import glob

if len(sys.argv) != 4:
    sys.stderr.write("Number of arguments: {}\n".format(len(sys.argv)))
    sys.stderr.write("extract_samples.py <sample_folder> <sample_list> <out_folder>\n")
    exit(1)

# Extract command line arguments
sample_folder = sys.argv[1]
sample_list_filename = sys.argv[2]
out_folder = sys.argv[3]

# Get absolute path for sample_folder
if os.path.isdir(sample_folder):
    sample_folder = os.path.realpath(sample_folder)

# Load sample list with pandas
print(sample_list_filename)
sample_list = pd.read_csv(sample_list_filename)[["sample_id","ScilifeID","RunID"]]
#print(sample_list)

# Create folders
for idx,sample in sample_list.iterrows():
    try:
        os.makedirs(os.path.join(out_folder,sample["sample_id"],"reads"))
    except OSError as e:
        print e
    cmd = "ln -s -t {} {}".format( os.path.join(out_folder,sample["sample_id"],"reads"),
                                      " ".join( glob.glob(os.path.join(sample_folder,sample["RunID"],sample["ScilifeID"],"*.fastq.gz"))))
    ret = subprocess.call(cmd,shell=True)
    if ret != 0:
        sys.stderr.write("Cmd: {} failed with return status {}\n".format(cmd,ret))
