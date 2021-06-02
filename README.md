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

Here's an example of how to run this workflow, in six steps.

1. Make/find a source folder. Put the images there.

```bash
mkdir -p WORK_DIR/EXAMPLE_IMAGES/
```

2. Make the output folder. This is where the workflow results will go.

```bash
mkdir -p WORK_DIR/EXAMPLE_OUTPUT/
```

3. Make a 'project' folder to put the workflow & code. 
  * Put your project file (a `.cppipe` file) there. This file is created by using the CellProfiler app, usually on your desktop/laptop. 

```bash
mkdir -p WORK_DIR/EXAMPLE_PROJECT/
```

4. Make a file with a list of images to run. For example, let's say we want to process all the `.tif` images in the source folder. We'll get the list of files, and put them into a text file in the project folder. This will be used by the workflow.

```bash
cd WORK_DIR/EXAMPLE_PROJECT/
ls WORK_DIR/EXAMPLE_IMAGES/*tif > filelist.txt
```

5. Make a 'run' script. This has all of the variables needed to run Nextflow. It also makes reproducibility easy: just re-run the script.

Here's an example run script, which we'll call `run.sh`. Save it to the project folder (e.g. `WORK_DIR/EXAMPLE_PROJECT/`)

```bash
#!/bin/bash

# INPUT
INPUT_H5='EXAMPLE_PROJECT.cppipe'
INPUT_TXT='filelist.txt'
INPUT_CONCAT_N=100

#OUTPUT
PROJECT=EXAMPLE_PROJECT
OUTPUT_DIR=WORK_DIR/EXAMPLE_OUTPUT/

# Profile (used to allocate resources)
PROFILE=standard

# Run the workflow
NXF_VER=20.10.0 \
nextflow \
    run \
    -c nextflow.config \
    -profile $PROFILE \
    FredHutch/cellprofiler-batch-nf \
    --input_h5 "${INPUT_H5}" \
    --input_txt "${INPUT_TXT}" \
    --output ${OUTPUT_DIR} \
    -with-report $PROJECT.report.html \
    -with-trace $PROJECT.trace.tsv \
    -resume \
    -latest

```

The script is creating bash variables for the workflow parameters and then running the Nextflow workflow.

6. Finally, run the script.

```bash
cd WORK_DIR/EXAMPLE_PROJECT/
. run.sh
```

The script will run and put the output in the output folder/directory. In testing, processing ~480 images took 10-18 minutes.



### Using Multiple Configs

If you have a Nextflow config file that is used to execute workflows in your environment, Nextflow [can combine it](https://www.nextflow.io/docs/latest/config.html) with the GitHub repo's `nextflow.config`. 

For example, let's say you have a `default.nextflow.config` file that is used to run in your environment (e.g. to support AWS Batch, or Slurm, or Singularity). You'd update the script to include a `BASE_CONFIG` variable, and update the `nextflow run` command parameters to include it.


```bash

BASE_CONFIG=WORK_DIR/default.nextflow.config

# Run the workflow
NXF_VER=20.10.0 \
nextflow \
    run \
    -c $BASE_CONFIG \
    -c nextflow.config \
    -profile $PROFILE \
    FredHutch/cellprofiler-batch-nf \
    --input_h5 "${INPUT_H5}" \
    --input_txt "${INPUT_TXT}" \
    --output ${OUTPUT_DIR} \
    -with-report $PROJECT.report.html \
    -with-trace $PROJECT.trace.tsv \
    -resume \
    -latest

```
