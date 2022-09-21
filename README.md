# Bacterial genome assembly pipeline

This repo contains a set of [Nextflow](https://www.nextflow.io/) workflows to automatize basecalling and assembling bacterial genomes from Nanopore sequencing. It can be run in parallel for different barcodes, and uses the SLURM protocol to dispatch jobs on a cluster. It is based on [trycycler](https://github.com/rrwick/Trycycler). This is currently a work in progress.

## Setup

## Assembly pipeline

### Assemble

The `assemble` workflow takes care of assembling genomes following trycyler's procedure. It can be run with: 

```bash
nextflow run assemble.nf \
  -profile cluster \
  --run test_run \
  -resume
```

As for basecalling, the `-profile` option can be set to either `cluster` or `standard`, the latter is for a local execution.

### Reconcile

The `trycycle reconcile` step is executed by the `reconcile.nf` workflow. This workflow tries to reconcile in parallel al clusters for all barcodes. It produces a `reconcile_log.txt` file for each cluster, with the output of the command. This file can be used to correct the dataset and possibly remove some contigs. It also produces a `reconcile_summary.txt` file in the `clustering` folder, with a summary of which clusters have been successfully reconciled.

This command should be run multiple times with the `-resume` option, correcting every time the content of the clusters that failed to reconcile, until all clusters are successfully reconciled.

```bash
nextflow run reconcile.nf \
  -profile cluster \
  --run test_run \
  -resume
```

### Consensus

The workflow `consensus.nf` takes care of building a consensus read. It also polisheds the genome using `medaka` and adds annotations with `prokka`.

```bash
nextflow run consensus.nf \
   -profile cluster \
   --run test_run \
   -resume
```

Nb: if the computational node has no access to the internet, `medaka` could fail because it cannot download the appropriate model `r941_min_high_g360`. In this case on the login node, where internet is available, one must manually (only once) download the model. This can be done in the following two steps:

1. Activate the conda environment for `medaka`. The environment is created by nextflow and stored in the `work/conda` folder. One can retrieve its location also by running `conda env list`.
2. Once the corresponding conda environment is activated, the model can be installed by running `medaka tools download_models --models r941_min_high_g360`


## Helper scripts

## import_data.py

This script is used to archive the result of basecalling nanopore reads to the proper folder the cluster.
For details on how to use it see `scripts/archive_README.md`.