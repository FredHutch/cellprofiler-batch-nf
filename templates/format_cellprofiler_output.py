#!/usr/bin/env python3

import os
import csv
import glob
import sys
import pandas as pd


# static variables
col_separator = '\t'
na_rep = "${params.nan_value}"
cols_to_copy = ["${params.file_col}"]
shard_id = "${shard_id}"
shard_csv_file = "shard.csv"
input_dir = 'input'
join_config = {'*Image.txt': ['Group_Index']
               # '*Nuclei.txt': ['FileName_Orig', 'PathName_Orig']
               }


# this method
def parse_and_convert_tsv(shard_df,
                          source_file,
                          destination_file,
                          join_cols):
    """Takes an input TSV/CSV file, joins it with the shard_df (specific columns)
    and saves the results"""

    file_df = pd.read_csv(source_file, sep=col_separator)
    
    # we want to add in only the 'cols_to_copy' to the resulting TSV/CSV file
    # Make sure the columns in cols_to_copy are in the dataframe, otherwise exclude them
    valid_cols_to_copy = [x for x in cols_to_copy if x in file_df.columns]
    cols_to_join = join_cols + valid_cols_to_copy

    # pd.merge() does most of the work. We're doing a left join to avoid filtering any records
    # if shard_df doesn't have all of the entries
    merged_df = pd.merge(file_df, shard_df[cols_to_join], on=col_mapping, how='left')

    # save the resulting TSV/CSV
    merged_df.to_csv(destination_file, sep=col_separator, na_rep=na_rep, index=False)


if __name__ == "__main__":
    # remove the experiment file if it exists
    file_to_remove = os.path.join(input_dir, "${params.experiment_file}")
    if os.path.exists(file_to_remove):
        os.remove(file_to_remove)

    # load the shard CSV, we'll be using it many times
    shard_df = pd.read_csv(os.path.join(input_dir, shard_csv_file))

    # for each type of file to process, iterate through the files
    # and join them with the shard CSV
    # col_mapping is a list of columns to join on (must have the same name in both files)
    for path, col_mapping in join_config.items():
        for file in glob.glob(os.path.join(input_dir, path)):
            print(f"Processing {file} per {path} (shard {shard_id})")
            parse_and_convert_tsv(shard_df=shard_df,
                                  source_file=file,
                                  destination_file=f"{os.path.basename(file)}",
                                  join_cols=col_mapping)