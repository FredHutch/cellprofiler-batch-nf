#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

// Set default parameters
params.help = false
params.input = false
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
      --input               Batch file created by the CellProfiler GUI interface

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
    if (params.help || !params.input){
        // Invoke the function above which prints the help message
        helpMessage()
        // Exit out and do not run anything else
        exit 0
    }

}