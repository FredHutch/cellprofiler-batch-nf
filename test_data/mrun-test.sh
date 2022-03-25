#!/bin/bash
# GROUPING TEST RUN

set -e

# WORKING DIRECTORY
# Go to the working directory, where you have the .cppipe pipeline file and the CSV file created by CellProfiler

# INPUT VARIABLES
# Start of variables you will need to change for the run

# Inputs
INPUT_H5='CN segmentation 647_WGA_SD_40x_021822.cppipe'
INPUT_CSV='multich.csv'
INPUT_BATCH_SIZE=4

# CSV
FILE_PREFIX_IN="/Volumes"
FILE_PREFIX_OUT="/fh/scratch/delete90/hatch_e"
FILE_COL=""


# Outputs
PROJECT=groupingtest
OUTPUT_DIR=/fh/scratch/delete90/hatch_e/dnambi/multich-output/multich/

# Configuration file. You'll need one specific to your lab
# You can use the same file for all workflow runs in your entire lab
# this is the config for the Hutch Data Core folks (temp files are stored in our Fast & Scratch folders)

# Which version of CellProfiler to use
CELLPROFILER_VERSION="4.2.1"

# Configuration, saved to project folder
NXF_CONFIG=/fh/fast/hatch_e/hatchlab/nextflow.singularity.config

# Profile (used to allocate resources)
PROFILE=standard

# Load singularity
ml Singularity
export PATH=$SINGULARITYROOT/bin/:$PATH

# Load nextflow
ml nextflow

# Run the workflow
NXF_VER=21.04.0 \
nextflow \
    run \
    -c $NXF_CONFIG \
    -profile $PROFILE \
    main.nf \
    --input_h5 "${INPUT_H5}" \
    --input_csv "${INPUT_CSV}" \
    --file_prefix_in "${FILE_PREFIX_IN}" \
    --file_prefix_out "${FILE_PREFIX_OUT}" \
    --file_col "${FILE_COL}" \
    --n $INPUT_BATCH_SIZE \
    --version "${CELLPROFILER_VERSION}" \
    --output ${OUTPUT_DIR} \
    -with-report $PROJECT.cellprofiler.html \
    -latest