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

    // Point to the input files
    input_txt = file(params.input_txt)
    input_h5 = file(params.input_h5)

    // Based on the number of images provided, format the commands to execute
    parseInputs(
      input_txt
    )

}

process parseInputs {
  container "quay.io/fhcrc-microbiome/python-pandas:latest"

  input:
    file input_txt

  output:
    file "cellprofiler.commands.txt"

  """#!/usr/bin/env python3

import pandas as pd

# Read in the file with the list of images to process
df = pd.read-csv("${input_txt}")

# Get the number of images to include in each batch
batch_size = int(${params.n})

assert batch_size > 0

# Keep a list of commands
cmd_list = []

# Iterate over the (1-based) index position each batch of images
for start_ix in range(1, df.shape[0] + 1, batch_size):

  # Get the end position
  end_ix = min(df.shape[0], start_x + batch_size - 1)

  # Format the command to run
  cmd_list.append(
    f"cellprofiler -f {start_ix} -l {end_ix}"
  )

# Write out the command to a file
with open("cellprofiler.commands.txt", "w") as handle:

    handle.write("\\n".join(cmd_list))

  """
}