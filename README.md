# cellprofiler-batch-nf

Batch execution of CellProfiler analyses using Nextflow

# Purpose

Parallelize the execution of CellProfiler analysis using batch computing
or HPC services using the Nextflow workflow management system. This relies
upon the free and open-source tool for image analysis: [CellProfiler](https://cellprofiler.org/).

The user starts by setting up an analysis in the CellProfiler GUI, and then
selecting the "Create Batch File" option to create a batch file which can
be used as the input to this workflow.
When this workflow is run on that batch file, the analyses specified by the user
is split up and distributed across multiple nodes for more rapid execution.

# Usage

```
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
```