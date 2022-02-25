#!/usr/bin/env python3

import os
import csv
import glob
import sys
import pandas as pd


# static variables
col_separator = '\t'
na_rep = "${params.nan_value}"  # 'nan'
cols_to_copy = ["${params.file_col}"]  # ["FileName_Orig"]


# logic
# read in all of the .txt files from output_dir as TSV files. Remove carraige returns if they are there
# for each one, remove the ImageNumber column
# Add the image name column with its header. This is what needs to get fixed based on shard.csv
# Save it back as a TSV without the carriage returns (handled by pandas automatically?)
def parse_and_convert_tsv(shard_df,
                          source_file,
                          destination_file,
                          join_cols):
    file_df = pd.read_csv(source_file, sep=col_separator)
    cols_to_join = col_mapping + cols_to_copy
    merged_df = pd.merge(file_df, shard_df[cols_to_join], on=col_mapping, how='left')
    merged_df.to_csv(destination_file, sep=col_separator, na_rep=na_rep, index=False)


if __name__ == "__main__":
    shard_csv_file = "shard.csv"
    shard_id = [x for x in os.listdir('.') if x.isdigit()][0]
    input_dir = '.'
    
    join_config = {'*Image.txt': ['Group_Index']
                   # '*Nuclei.txt': ['FileName_Orig', 'PathName_Orig']
                   }

    file_to_remove = os.path.join(input_dir, "${params.experiment_file}")
    if os.path.exists(file_to_remove):
        os.remove(file_to_remove)

    shard_df = pd.read_csv(shard_csv_file)

    for path, col_mapping in join_config.items():
        for file in glob.glob(os.path.join(input_dir, path)):
            print(f"Processing {file} , per {path}")
            parse_and_convert_tsv(shard_df=shard_df,
                                  source_file=file,
                                  destination_file=f"{shard_id}-{file}",
                                  join_cols=col_mapping)