import numpy as np
import gzip
from glob import glob
import sys
# from timeit import timeit

def calculate_windows_from_file(gatk_cov_gz_file, window_size=500):
    fh = gzip.open(gatk_cov_gz_file, mode="rt")

    window_list = []
    cov_list = []

    current_contig = None
    last_pos = -1
    current_window_cov = 0

    # Positions are 1-indexed
    next(fh) #Skip header
    for line in fh:
        ctg_pos, cov = line.rstrip("\n").split("\t")
        ctg, pos = ctg_pos.rsplit(":",maxsplit=1)
        pos = int(pos)
        cov = int(cov)
        if current_contig != ctg:
            if current_contig is not None:
                window_list.append((current_contig, (last_pos//window_size)*window_size+1, last_pos))
                cov_list.append(current_window_cov)
            current_contig = ctg
            current_window_cov = cov  # Reset window coverage
        else:
            # no need to handle special case of new contig, because the if current_ctg != ctg takes care of that
            if pos % window_size == 1:
                window_list.append((current_contig, last_pos - window_size + 1, last_pos))
                cov_list.append(current_window_cov)
                current_window_cov = cov  # Reset window coverage
            else:  # Position within window, accumulate cov
                current_window_cov += cov

        # Update last_pos
        last_pos = pos

    #Process last window if any
    window_list.append((current_contig, (last_pos // window_size) * window_size + 1, last_pos))
    cov_list.append(current_window_cov)


    return window_list,np.array(cov_list)


def calculate_window_sizes(window_list):
    return tuple(end-start+1 for _,start,end in window_list)


def get_sample_coverage(gatk_cov_gz_file, window_sizes, cov_matrix, sample_row):
    fh = gzip.open(gatk_cov_gz_file, mode="rt")
    # Positions are 1-indexed
    next(fh)  # Skip header
    window_idx = 0
    pos_in_window = 0
    for line in fh:
        if pos_in_window == window_sizes[window_idx]:
            window_idx += 1
            pos_in_window = 0
        cov = int(line.rstrip("\n").split("\t")[1])
        cov_matrix[sample_row, window_idx] += cov
        pos_in_window += 1


def wrapper(fx, *args, **kwargs):
    def wrapped():
        return fx(*args, **kwargs)
    return wrapped


if __name__ == '__main__':
    # Read first file and calculate windows

    if len(sys.argv) != 3:
        print("Usage: gatk_cov_parser.py window_size folder_to_analyze")

    #Read parameters
    window_size = sys.argv[1]
    folder_to_analyze = sys.argv[2]

    files_to_parse = glob("{}/*.cov.gz".format(folder_to_analyze))

    print("Number of files to parse: {}".format(len(files_to_parse)))
    print(", ".join(files_to_parse))

    print("Calculating windows from file...")
    windows, _ = calculate_windows_from_file(files_to_parse[0], 5000)

    window_sizes = calculate_window_sizes(windows)
    print("done")

    # Initialize matrix to store coverage for each window, for each file
    cov_matrix = np.zeros((len(files_to_parse), len(windows)), dtype=np.int64)

    # Process each sample
    for sample_idx, sample in enumerate(sorted(files_to_parse)):
        print("Processing sample {}...".format(sample))
        get_sample_coverage(sample, window_sizes, cov_matrix, sample_idx)
        print("done")

    # Save results
    with open("windows.csv", "w") as wdw_fh_out:
        for wdw in windows:
            wdw_fh_out.write(",".join([str(x) for x in wdw]) +"\n" )

    with open("samples.txt", "w") as smpls_fh_out:
        for sample in sorted(files_to_parse):
            smpls_fh_out.write("{}\n".format(sample))

    np.save("cov_windows.npy", arr=cov_matrix)

