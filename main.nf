#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

// Set default parameters
params.help = false
params.input_h5 = false
params.input_txt = false
params.output = false
params.n = 1
params.reduce_n = 100
params.version = "4.1.3"

// Docker containers reused across processes
container__cellprofiler = "cellprofiler/cellprofiler:${params.version}"
container__pandas = "quay.io/fhcrc-microbiome/python-pandas:v1.0.3"


// Function which prints help message text
def helpMessage() {
    log.info"""
    Usage:

    nextflow run FredHutch/cellprofiler-batch-nf <ARGUMENTS>

    Required Arguments:
      --input_h5            Batch file created by the CellProfiler GUI interface defining the analysis to run
      --input_txt           List of images to process using the specified analysis
      --output              Path to output directory

    Optional Arguments:
      --n                   Number of images to analyze in each batch (default: 1000)
      --reduce_n            Number of tabular results to combine/concatenate in the first round (default: 100)
      --version             Software version CellProfiler (default: 4.1.3)
                            Must correspond to tag available at hub.docker.com/r/cellprofiler/cellprofiler/tags

    CellProfiler Citations: See https://cellprofiler.org/citations
    Workflow: https://github.com/FredHutch/cellprofiler-batch-nf

    """.stripIndent()
}


workflow {

    // Show help message if the user specifies the --help flag at runtime
    if (params.help || !params.input_h5 || !params.input_txt || !params.output){
        // Invoke the function above which prints the help message
        helpMessage()
        // Exit out and do not run anything else
        exit 0
    }

    // Point to the input file for the workflow
    input_h5 = file(params.input_h5)

    // Split up the list of input files
    // map the file on each line to a file object
    // group into batches of size --n
    // assign the channel to img_list_ch
    Channel
        .fromPath(params.input_txt)
        .splitText()
        .map({ i -> file(i.trim()) })
        .collate(params.n)
        .set { img_list_ch }

    // For each of those batches, run the indicated analysis
    CellProfiler(
      img_list_ch,
      input_h5
    )

    // Take the resulting files, split & group them by name
    // Use the size and remainder arguments in groupTuple()
    // to control the size of the inputs to the concat() process
    profiler_results_ch = CellProfiler.out
        .flatten()
        .map({ i -> [ i.name, i ]})
        .groupTuple(size: params.reduce_n , remainder: true)

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

process CellProfiler {
  container "cellprofiler/cellprofiler:${params.version}"
  label 'mem_veryhigh'
  maxForks 100
  errorStrategy 'retry'
  maxRetries 3 //slurm tends to SIGTERM jobs

  input:
    file "input/*"
    file analysis_h5

  output:
    file "output/*"

  """#!/bin/bash

# Run CellProfiler on this batch of images
cellprofiler -r -c -o output/ -i input/ -p ${analysis_h5} output/OUTPUT

# Remove the Experiment file
# Note: this seems fragile, relying on Experiment.txt. 
#       Check for all non-tabular results instead?
#       Maybe move the non-tabular results to a separate output folder,
#       take the first result, and publish the result?
REMOVE_FILE="\$(ls output/* | grep Experiment.txt)"
rm \$REMOVE_FILE

# Get the name of the input image file
export INPUTFILE="\$(ls input/* | head -n 1)"
export INPUTFILEBASE="\$(basename \$INPUTFILE)"
echo "input base is \$INPUTFILEBASE ."

# For all files in the output, add the image name as an additional column
# Note: the files are renamed to hardcoded temporary files for simplicity
for f in output/* ; do 
    # remove carriage returns that are sometimes present
    cat \$f | tr -d '\\r' > output/tmptrimfile
    # add the image name & a header column
    awk -v f=\$INPUTFILEBASE 'NR==1 {printf("%s\\t%s\\n", \$0, "ImageName")}  NR>1 && NF > 0 { printf("%s\\t%s\\n", \$0, f) }' output/tmptrimfile > output/tmpcopyfile
    cp output/tmpcopyfile \$f
    rm -f output/tmpcopyfile
    rm -f output/tmptrimfile
done
  """
}

process ConcatFiles_Round1 {
  container "cellprofiler/cellprofiler:${params.version}"
  label 'mem_medium'
  errorStrategy 'retry'
  maxRetries 3 //slurm tends to SIGTERM jobs

  input:
    tuple val(filename), path("input???/*")

  output:
    file "$filename"

  """#!/bin/bash
mkdir -p output

# first, save the header
FIRSTFILE="\$(ls input*/* | head -n 1)"
head -n 1 \$FIRSTFILE > $filename

# now concatenate all of the files, skipping the first row
awk 'FNR>1' input*/* >> $filename
  """
}

process ConcatFiles_Round2 {
  container "cellprofiler/cellprofiler:${params.version}"
  publishDir path: params.output
  label 'mem_medium'
  errorStrategy 'retry'
  maxRetries 3 //slurm tends to SIGTERM jobs

  input:
    tuple val(filename), path("input??/*")

  output:
    file "$filename"

  """#!/bin/bash
mkdir -p output

# first, save the header
FIRSTFILE="\$(ls input*/* | head -n 1)"
head -n 1 \$FIRSTFILE > $filename

# now concatenate all of the files, skipping the first row
awk 'FNR>1' input*/* >> $filename
  """
}