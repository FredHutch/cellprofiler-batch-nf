#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

// Set default parameters
params.help = false
params.input_h5 = false
params.input_csv = false
params.output = false

// Docker containers reused across processes
params.container_cellprofiler = "cellprofiler/cellprofiler:${params.version}"
params.container_pandas = "quay.io/fhcrc-microbiome/python-pandas:v1.0.3"


// Function which prints help message text
def helpMessage() {
    log.info"""
    Usage:

    nextflow run FredHutch/cellprofiler-batch-nf <ARGUMENTS>

    Required Arguments:
      --input_h5            Batch file created by the CellProfiler GUI interface defining the analysis to run
      --input_csv           CSV file containing the parameters + groupings for this run
      --output              Path to output directory

    Optional Arguments:
      --n                   Number of images to analyze in each batch (default: 1000)
      --concat_n            Number of tabular results to combine/concatenate in the first round (default: 100)
      --version             Software version CellProfiler (default: 4.2.1)
                            Must correspond to tag available at hub.docker.com/r/cellprofiler/cellprofiler/tags
      --group_col           The name of the grouping column in the CSV file (default: Group_Number)
      --folder_col          The name of the folder column in the CSV file (default: PathName_Orig)
      --file_col            The name of the file column in the CSV file (default: FileName_Orig)
      --shard_col           The name of the column being added that has the shard (default: Shard_Id)
      --file_prefix_in      The value of the folder path prefix, in the folder column of the CSV 
                               that needs to be changed (no default, ignored when empty)
      --file_prefix_out     When using --file_prefix_in, set this to be the value of the folder path
                               to change into
      --container_cellprofiler The location of a Docker container that has CellProfiler. This can be used
                               to run containers that have CellProfiler and additional software (e.g. cellpose)
                               (default: cellprofiler/cellprofiler:{version})
      --container_pandas    The location of a Docker container to use that has pandas
                               (default: quay.io/fhcrc-microbiome/python-pandas:v1.0.3)
      --nan_value           When reformatting the .txt files, this is what gets put in place of 'NA' or 'NaN' values
                               (default: 'nan')

    CellProfiler Citations: See https://cellprofiler.org/citations
    Workflow: https://github.com/FredHutch/cellprofiler-batch-nf

    """.stripIndent()
}


workflow {

    // Show help message if the user specifies the --help flag at runtime
    if (params.help || !params.input_h5 || !params.input_csv || !params.output) {
        // Invoke the function above which prints the help message
        helpMessage()
        // Exit out and do not run anything else
        exit 0
    }

    // Point to the input file for the workflow
    input_h5 = file(params.input_h5)

    // Point to the input CSV for the workflow
    input_csv = file(params.input_csv)

    ParseCsv(
      input_csv
    )

    // Get the list of files per shard and associate them with a tuple
    files_by_shard = ParseCsv.out
      .flatMap()
      .splitCsv(header: true)
      .map { it -> [it.Shard_Id, file( it.Wf_Image_Path )] }
      .groupTuple()
      //.view()

    // Get the csv file for each shard and associate it with a tuple
    csv_by_shard = ParseCsv.out
      .flatMap()
      .map { it -> [file(it).getName().replace('.csv',''), file(it)] }
      .groupTuple()
      //.view()

    // Join the CSV and files together
    csv_and_files = files_by_shard.join(csv_by_shard)
      //.view()

    // For each of those batches/shards, run the indicated analysis
    CellProfiler(
      csv_and_files,
      input_h5
    )

    // Get the list of files per shard and associate them with a tuple
    cellprofiler_out_by_shard = CellProfiler.out

    Format_CellProfiler_Output(
      cellprofiler_out_by_shard
      )

    // Take the resulting files, split & group them by name
    // Use the size and remainder arguments in groupTuple()
    // to control the size of the inputs to the concat() process
    profiler_results_ch = Format_CellProfiler_Output.out.txt
        .flatten()
        .map({ i -> [ i.name, i ]})
        .groupTuple(size: params.concat_n , remainder: true)

    // For each group of files, concatenate them together
    ConcatFiles_Round1(
        profiler_results_ch
      )

    // Take the results from the first round of concatenation,
    // group them by name, so they can all be concatenated together
    concat_ch = ConcatFiles_Round1.out
        .flatten()
        .map({ i -> [ i.name, i ]})
        .groupTuple()

    // Concatenate all files of the same name together
    ConcatFiles_Round2(
        concat_ch
      )

}


process ParseCsv {
  container "$params.container_pandas"
  publishDir path: "${params.output}/csv/" , mode: 'copy', pattern: "*.csv", overwrite: true
  label 'io_limited'

  input:
    path("input/*")

  output:
    path("*.csv")
    //name them by group number

  script:
    template 'parse_csv.py'
}


process CellProfiler {
  container "$params.container_cellprofiler"
  publishDir path: "${params.output}/tiff/" , mode: 'copy', pattern: "output/*.tiff", overwrite: true
  label 'mem_veryhigh'

  input:
    tuple val(shard_id), path("input/*"), path("shard.csv")
    path analysis_h5

  output:
    tuple val(shard_id), path("output/**")

  script:
  """#!/bin/bash
set -Eeuo pipefail

mkdir -p output

# Run CellProfiler on this batch of images
cellprofiler -r -c -o output/ -i input/ -p ${analysis_h5} --data-file shard.csv output/OUTPUT
cp shard.csv output/
  """
}


process Format_CellProfiler_Output {
  container "$params.container_pandas"
  // mode: copy because the default is symlink to /fh/scratch/ (i.e. ephemeral)
  publishDir path: "${params.output}/txt/" , mode: 'copy', pattern: "*.txt", overwrite: true
  label 'mem_medium'

  input:
    tuple val(shard_id), path("input/*")

  output:
    path "*.txt", emit: txt
    path "**", emit: all

  script:
    template "format_cellprofiler_output.py"
}


process ConcatFiles_Round1 {
  container "$params.container_cellprofiler"
  label 'mem_medium'

  input:
    tuple val(filename), path("input*/*")

  output:
    path "$filename"

  """#!/bin/bash
set -Eeuo pipefail

# first, save the header
FIRSTFILE="\$(ls input*/* | head -n 1)"
head -n 1 \$FIRSTFILE > $filename

# now concatenate all of the files, skipping the first row
awk 'FNR>1' input*/* >> $filename
  """
}


process ConcatFiles_Round2 {
  container "$params.container_cellprofiler"
  // mode: copy because the default is symlink to /fh/scratch/ (i.e. ephemeral)
  publishDir path: params.output , mode: 'copy'
  label 'mem_medium'

  input:
    tuple val(filename), path("input*/*")

  output:
    path "$filename"

  """#!/bin/bash
set -Eeuo pipefail

# first, save the header
FIRSTFILE="\$(ls input*/* | head -n 1)"
head -n 1 \$FIRSTFILE > $filename

# now concatenate all of the files, skipping the first row
awk 'FNR>1' input*/* | sort -n >> $filename
  """
}