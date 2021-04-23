#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

// Set default parameters
params.help = false
params.input_h5 = false
params.input_txt = false
params.output = false
params.n = 1000
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

}

process CellProfiler {
  container "cellprofiler/cellprofiler:${params.version}"

  input:
    file "input/*"
    file analysis_h5

  output:
    file "output/*"

  """#!/bin/bash

# Run CellProfiler on this batch of images
cellprofiler -c -o output/ -i input/ --project ${analysis_h5} output/OUTPUT

  """
}