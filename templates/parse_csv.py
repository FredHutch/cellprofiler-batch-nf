#!/usr/bin/env python3

import os
import pandas as pd
import numpy as np
import math
import glob

# input variables
group_number_col = "${params.group_col}"
file_dir_col = "${params.folder_col}"
file_col = "${params.file_col}"
file_prefix_input = "${params.file_prefix_in}"
file_prefix_output = "${params.file_prefix_out}"
shard_size = ${params.n}
shard_col = "${params.shard_col}"


# does a string find-and-replace only if it's a prefix match
def replace_prefix(input_str, pattern_string, replace_string):
    if input_str.startswith(pattern_string):
        return f"{replace_string}{input_str[len(pattern_string):]}"
    else:
        return input_str


def make_filepaths(row, suffix):
    return os.path.join(row[f"PathName{suffix}"], row[f"FileName{suffix}"])


def parse_and_convert_csv(src_file):
    csv_df = pd.read_csv(src_file)
    csv_cols = csv_df.columns

    # Find out if it has a group or not
    # and replace the file names
    has_groups = False

    if len(csv_df[csv_df[group_number_col] > 1]):
        has_groups = True

    # FIRST, ASSIGN GROUPS + SHARDS
    if has_groups:
        # get the sizes of each group via pandas groupby
        csv_df[shard_col] = 1
        csv_df[shard_col] = csv_df[shard_col].cumsum() - 1
        grouped_df = csv_df[[shard_col, group_number_col]].groupby(group_number_col)
        group_sizes = grouped_df.aggregate(np.count_nonzero).reset_index().to_dict(orient='records')

        # then map groups to shards
        current_shard_id = 1
        current_shard_image_count = 0
        group_to_shard_map = {}

        for x in group_sizes:
            group = x.get(group_number_col)
            size = x.get(shard_col)
            if current_shard_image_count + size >= shard_size:
                current_shard_id += 1
                current_shard_image_count = 0
            group_to_shard_map[group] = current_shard_id
            current_shard_image_count += size

        # then map each row/group to a shard via df.apply() and a lambda function
        csv_df[shard_col] = csv_df[group_number_col].apply(lambda x: group_to_shard_map[x])
    else:
        # first, assign all shards to 1. This just used for counting
        csv_df[shard_col] = 1
        # then, getting the row number for each record, via pd.cumsum()
        # we subtract 1 because we need 0-indexed records rather than 1-based, to divide correctly
        csv_df[shard_col] = csv_df[shard_col].cumsum() - 1
        # assign to shards by dividing the row number by the shard size, then round down
        # we add 1 because we want 1-indexed shard records, to be easier for users to understand
        csv_df[shard_col] = (csv_df[shard_col] / shard_size).apply(math.floor) + 1

    # SECOND, MELT OUT MULTICHANNEL
    filename_suffixes = [x.split('FileName')[1] for x in csv_df.columns if x.find('FileName') >= 0]
    pathname_suffixes = [x.split('PathName')[1] for x in csv_df.columns if x.find('PathName') >= 0]
    suffixes = list(set(pathname_suffixes).intersection(set(filename_suffixes)))

    for s in suffixes:
        csv_df[f"Wf_UniquePrefix{s}"] = csv_df.apply(make_filepaths, suffix=s, axis=1)
        #csv_df[f"PathName{s}"] = csv_df[f"PathName{s}"].apply(lambda x: 
        #                                                      replace_prefix(x, file_prefix_input, file_prefix_output))
        csv_df[f"PathName{s}"] = "input"

    id_cols = [shard_col]
    value_cols = [f"Wf_UniquePrefix{x}" for x in suffixes]
    unpivot = csv_df.melt(id_vars=id_cols,
                          value_vars=value_cols,
                          var_name='SourceCol',
                          value_name='FilePath',
                          ignore_index=True)
    unpivot.drop('SourceCol', axis=1, inplace=True)

    # now fix the prefixes
    unpivot['Wf_Image_Path'] = unpivot['FilePath'].apply(lambda x: 
                                                         replace_prefix(x, file_prefix_input, file_prefix_output))

    # THIRD, WRITE OUT THE RESULTS
    # For each shard, write out 2 files: the original CSV (filtered to that shard)
    #    and a shard/{shard_number}.csv , containing the file mappings themselves
    # write out one file for each shard, into the 
    # first, get the list of shards, and make an dict of arrays to 'collate' the relevant CSV records
    list_of_shards = list(set(csv_df[shard_col].tolist()))
    for shard in list_of_shards:
        # first, write out the CSV
        filtered_csv = csv_df[csv_df[shard_col] == shard]
        filtered_csv[csv_cols].to_csv(f"{shard}.csv", index=False)

        # then write out the shard file
        # we need to use drop_duplicates() because the same file can be reused
        # across multiple columns in the multichannel runs, leading to 
        # duplicate identical file entries (which breaks NF)
        shard_df = unpivot[unpivot[shard_col] == shard].drop_duplicates()
        shard_df[[shard_col, 'Wf_Image_Path']].drop_duplicates().to_csv(f"shards/{shard}.csv", index=False)


if __name__ == "__main__":
    src_dir = "input"

    if not os.path.exists('shards'):
        os.makedirs('shards')

    # can't do this, I'll overwrite entries
    for file in glob.glob(f"{src_dir}/*.csv"):
        print(f"Now working on {file}")
        parse_and_convert_csv(file)
