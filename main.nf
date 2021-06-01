#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

// Set default parameters
params.help = false
params.input_h5 = false
params.input_txt = false
params.output = false
params.n = 1
params.concat_n = 100
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
      --concat_n            Number of tabular results to combine/concatenate in the first round (default: 100)
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

process CellProfiler {
  container "cellprofiler/cellprofiler:${params.version}"
  label 'mem_veryhigh'

  input:
    file "input/*"
    file analysis_h5

  output:
    file "output/*"

  """#!/bin/bash
mkdir -p output

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


# For all files in the output:
   * add the image name as the first column
   * remove the ImageNumber column if it exists
# Note: the files are renamed to hardcoded temporary files for simplicity
for f in output/* ; do 
    # remove carriage returns that are sometimes present
    cat \$f | tr -d '\\r' > output/tmptrimfile
    # remove the ImageNumber column if it exists
    imagenumbercol="\$(head -1 output/tmptrimfile | tr '\\t' '\\n' | cat -n | grep 'ImageNumber' | awk '{print \$1}')"
    if [[ ! -z "\$imagenumbercol" ]]
    then
        cut --complement -f\$imagenumbercol output/tmptrimfile > output/tmpcolfile
    else
        cp output/tmptrimfile output/tmpcolfile
    fi
    # add the image name column w/ header
    awk -v f=\$INPUTFILEBASE 'NR==1 {printf("%s\\t%s\\n", "ImageName", \$0)}  NR>1 && NF > 0 { printf("%s\\t%s\\n", f, \$0) }' output/tmpcolfile > output/tmpcopyfile
    cp output/tmpcopyfile \$f
    rm -f output/tmpcopyfile output/tmptrimfile output/tmpcolfile
    unset imagenumbercol
done
  """
}

process ConcatFiles_Round1 {
  container "cellprofiler/cellprofiler:${params.version}"
  label 'mem_medium'

  input:
    tuple val(filename), path("input*/*")

  output:
    file "$filename"

  """#!/bin/bash
# first, save the header
FIRSTFILE="\$(ls input*/* | head -n 1)"
head -n 1 \$FIRSTFILE > $filename

# now concatenate all of the files, skipping the first row
awk 'FNR>1' input*/* >> $filename
  """
}

process ConcatFiles_Round2 {
  container "cellprofiler/cellprofiler:${params.version}"
  // mode: copy because the default is symlink to /fh/scratch/ (i.e. ephemeral)
  publishDir path: params.output , mode: 'copy'
  label 'mem_medium'

  input:
    tuple val(filename), path("input*/*")

  output:
    file "$filename"

  """#!/bin/bash
# first, save the header
FIRSTFILE="\$(ls input*/* | head -n 1)"
head -n 1 \$FIRSTFILE > $filename

# now concatenate all of the files, skipping the first row
awk 'FNR>1' input*/* | sort -n >> $filename
  """
}