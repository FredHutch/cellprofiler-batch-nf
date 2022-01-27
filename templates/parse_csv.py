#!/usr/bin/env python3

import os
import csv
import sys
from collections import defaultdict

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

# make a little method to write out CSVs from a dict
def write_csv_from_dict(dict_array, file_loc):
    # get the CSV header from the keys in the first dict
    fieldnames = dict_array[0].keys()
    with open(file_loc, 'w') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        # write out the header, then each row
        writer.writeheader()
        for row in dict_array:
            writer.writerow(row)


def parse_and_convert_csv(src_file):
    # get the CSV as a dict
    csv_dict = []
    with open(f"{src_dir}/{src_file}", 'r') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            csv_dict.append(row)

    # Find out if it has a group or not
    # and replace the file names
    has_groups = False
    for row in csv_dict:
        row['Wf_Image_Path'] = os.path.join(replace_prefix(row[file_dir_col], file_prefix_input, file_prefix_output),
                                            row[file_col])
        if int(row[group_number_col]) > 1:
            has_groups = True

    # variables used for sharding
    current_shard_id = 1
    current_shard_image_count = 0

    # leave the group numbers alone entirely. They determine which shard goes where, that's it
    # also set the shard id values appropriately
    if has_groups:
        def def_group_size():
            return 0
        # set shards based on groups
        group_sizes = defaultdict(def_group_size)
        for row in csv_dict:
            group_sizes[row.get(group_number_col)] = group_sizes[row.get(group_number_col)] + 1

        group_to_shard_map = {}
        for group, size in group_sizes.items():
            if current_shard_image_count + size >= shard_size:
                current_shard_id += 1
                current_shard_image_count = 0
            group_to_shard_map[group] = current_shard_id
            current_shard_image_count += size

        for row in csv_dict:
            row[shard_col] = group_to_shard_map[row.get(group_number_col)]
    else:
        for row in csv_dict:
            # increment the current_shard
            if current_shard_image_count >= shard_size:
                current_shard_id += 1
                current_shard_image_count = 0
            # set the shard value for this record
            row[shard_col] = current_shard_id
            current_shard_image_count += 1

    # now write out the results
    # write out one file for each shard
    # first, get the list of shards, and make an dict of arrays to 'collate' the relevant CSV records
    list_of_shards = list(set([x[shard_col] for x in csv_dict]))
    shards_collated = {k: [] for k in list_of_shards}

    # put each CSV record into the correct shard array
    for row in csv_dict:
        shards_collated[row[shard_col]].append(row)

    # now, write out each array as its own file
    for shard_number, dict_array in shards_collated.items():
        file_loc = f"{shard_number}.csv"
        write_csv_from_dict(dict_array=dict_array, file_loc=file_loc)


if __name__ == "__main__":
    src_dir = "input"
    for file in os.listdir('input'):
        print(f"Now working on {file}")
        parse_and_convert_csv(file)
