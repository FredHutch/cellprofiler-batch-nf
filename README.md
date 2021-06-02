# cellprofiler-batch-nf

Batch execution of CellProfiler analyses using Nextflow

# Purpose

Parallelize the execution of CellProfiler analysis using batch computing or HPC services using the Nextflow workflow management system. This relies upon the free and open-source tool for image analysis: [CellProfiler](https://cellprofiler.org/).

The user starts by setting up an analysis in the CellProfiler GUI, and then selecting the "Create Batch File" option to create a batch file which can be used as the input to this workflow.

When this workflow is run on that batch file, the analyses specified by the user is split up and distributed across multiple nodes for more rapid execution.

# Usage

```
    Usage:

    nextflow run FredHutch/cellprofiler-batch-nf <ARGUMENTS>
    
    Required Arguments:
      --input_h5            Batch file created by the CellProfiler GUI interface defining the analysis to run
      --input_txt           List of images to process using the specified analysis
      --output              Path to output directory

    Optional Arguments:
      --concat_n            Number of tabular results to combine/concatenate in the first round (default: 100)
      --version             Software version CellProfiler (default: 4.1.3)
                            Must correspond to tag available at hub.docker.com/r/cellprofiler/cellprofiler/tags

    CellProfiler Citations: See https://cellprofiler.org/citations
    Workflow: https://github.com/FredHutch/cellprofiler-batch-nf
```


## Example

Here's an example of how to run this workflow, in six steps. This example is designed to be run on Rhino.

1. Make/find a source folder. Put the images there.

```bash
mkdir -p /fh/scratch/delete30/EXAMPLE_PI/EXAMPLE_IMAGES/
```

2. Make the output folder. This is where the workflow results will go.

```bash
mkdir -p /fh/scratch/delete30/EXAMPLE_PI/EXAMPLE_OUTPUT/
```

3. Make a 'project' folder to put the workflow & code. 
  * Put your project file (a `.cppipe` file) there. This file is created by using the CellProfiler app, usually on your desktop/laptop. 
  * Put the `nextflow.config` file there.
  * Put the `main.nf` file there.

```bash
mkdir -p /fh/fast/EXAMPLE_PI/EXAMPLE_PROJECT/
```

4. Make a list of image files to run. For example, let's say we want to process all the `.tif` images in the source folder. We'll get the list of files, and put them into a text file. This will be used by the workflow.

```bash
cd /fh/fast/EXAMPLE_PI/EXAMPLE_PROJECT/
ls /fh/scratch/delete30/EXAMPLE_PI/EXAMPLE_IMAGES/*tif > filelist.txt
```

5. Make a 'run' script. This has all of the variables needed to run Nextflow. It also makes reproducibility easy: you just re-run the run script.

Here's an example run script, which we'll call `run.sh`. Save it to the project folder (e.g. `/fh/fast/EXAMPLE_PI/EXAMPLE_PROJECT/`)

```bash
#!/bin/bash

# INPUT
INPUT_H5='EXAMPLE_PROJECT.cppipe'
INPUT_TXT='filelist.txt'
INPUT_CONCAT_N=100

#OUTPUT
PROJECT=EXAMPLE_PROJECT
OUTPUT_DIR=/fh/scratch/delete30/EXAMPLE_PI/EXAMPLE_OUTPUT/

# Configuration, saved to /fh/fast/_SR/DataApplications/assets/nextflow/
NXF_CONFIG=/fh/fast/_SR/DataApplications/assets/nextflow/nextflow.singularity.config

# Profile (used to allocate resources)
PROFILE=standard

# Load singularity
ml Singularity
export PATH=$SINGULARITYROOT/bin/:$PATH

# Load nextflow
ml nextflow

# Run the workflow
NXF_VER=20.10.0 \
nextflow \
    run \
    -c $NXF_CONFIG \
    -c nextflow.config \
    -profile $PROFILE \
    main.nf \
    --input_h5 "${INPUT_H5}" \
    --input_txt "${INPUT_TXT}" \
    --output ${OUTPUT_DIR} \
    -with-report $PROJECT.report.html \
    -with-trace $PROJECT.trace.tsv \
    -resume \
    -latest

```

There's a lot there. The script is creating bash variables for the workflow parameters, loading the `nextflow` module, and then running the Nextflow workflow.

6. Finally, run the script.

```bash
cd /fh/fast/EXAMPLE_PI/EXAMPLE_PROJECT/
. run.sh
```

The script will run and put the output in the output folder/directory. In testing, processing ~480 images took 10-18 minutes.
