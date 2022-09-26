# Genome assembly pipeline

This repo contains a set of [Nextflow](https://www.nextflow.io/) workflows to parallelize the assembly of bacterial genomes using [trycycler](https://github.com/rrwick/Trycycler). It also polishes the created assemblies using [medaka](https://github.com/nanoporetech/medaka) and annotates them with [prokka](https://github.com/tseemann/prokka). It uses the SLURM protocol to dispatch jobs on a cluster.



## Setup

To initialize the pipeline create the `g-assembly` conda environment from the provided environment file `base_env.yml`. This requires a working installation of [conda](https://docs.conda.io/en/latest/). The environment can be created and activated with the following command:

```bash
conda env create --file base_env.yml
conda activate g-assembly
```

This will automatically install nextflow and other dependencies.


## Preparing the input

Input is provided as a series of `<sample-id>.fastq.gz` files. These must be placed in the following folder structure:
```
runs
└── <run-id>
    └── reads
        ├── <sample_1>.fastq.gz
        ├── <sample_2>.fastq.gz
        ├── ...
        └── <sample_N>.fastq.gz
```
The name of the `<run-id>` folder is passed as `--run` argument to each workflow. Data for each run are always loaded and saved inside this folder.

For convenience we provide the script `load_data_utils/import_data.py`, which can be used to easily import and format data from the `nccr-antiresist` folder on scicore. For details on how to use it see `load_data_utils/archive_README.md`.


## Assembling the genomes

Genome assembly requires the execution of three different workflows in order:
1. `assemble.nf`: build three different assemblies from raven, flye and miniasm+minipolish.
2. `reconcile.nf`: try to reconcile the three assemblies into one. Might need manual intervention of the user to exclude incompatible contigs.
3. `consensus.nf`: once reconciliation is successful combines all the contigs in a single assembly. Each assembly is then polished with [medaka](https://github.com/nanoporetech/medaka) and annotated with [prokka](https://github.com/tseemann/prokka).


### Assemble

The `assemble` workflow takes care of assembling genomes following trycyler's procedure, using raven, flye and miniasm+minipolish. It can be run with:

```bash
nextflow run assemble.nf \
  -profile cluster \
  --run test_run \
  -resume
```

As for basecalling, the `-profile` option can be set to either `cluster` or `standard`, the latter is for a local execution.

### Reconcile

The `trycycle reconcile` step is executed by the `reconcile.nf` workflow. This workflow tries to reconcile in parallel al clusters for all samples. It produces a `reconcile_log.txt` file for each cluster, with the output of the command. This file can be used to correct the dataset and possibly remove some contigs. It also produces a `reconcile_summary.txt` file in the `clustering` folder, with a summary of which clusters have been successfully reconciled.

This command should be run multiple times with the `-resume` option, [progressively removing contigs that are not compatible with the cluster](https://github.com/rrwick/Trycycler/wiki/Reconciling-contigs), until all clusters are successfully reconciled.

```bash
nextflow run reconcile.nf \
  -profile cluster \
  --run test_run \
  -resume
```

### Consensus, polishing and annotation

The workflow `consensus.nf` takes care of building a consensus read. It also polisheds the genome using `medaka` and adds annotations with `prokka`.

```bash
nextflow run consensus.nf \
   -profile cluster \
   --run test_run \
   -resume
```

**Nb:** if local execution has no access to the internet, `medaka` could fail because it cannot download the appropriate model `r941_min_high_g360`. In the workflow this is taken care of by the `medaka_setup` process, which is executed locally. If this process fails because internet connection is not available, one must manually (only once) download the model. This can be done in the following two steps:

1. Activate the conda environment for `medaka`. The environment is created by nextflow and stored in the `work/conda` folder. One can retrieve its location by running `conda env list`.
2. Once the corresponding conda environment is activated, the model can be installed by running `medaka tools download_models --models r941_min_high_g360`


## Output format

At the end of the three step for each sample a folder `runs/<run-id>/clustering/<sample-id>` will have been created. It will contain the following files:

- `filtlong_reads.fastq`: applied filtlong to discard short reads (<1 kbp) and very bad reads (the worst 5%). 
- `contigs.newick`: a tree of the contigs built from the distance matrix.
- `cluster_XXX` directories, one per cluster, each containing:
  - `1_contigs`: folder containing `X_contig.fasta` files, one per contig
  - `2_all_seqs.fasta`: sequence of each of the reconciled contigs, used for multiple sequence alignment.
  - `3_msa.fasta`: multiple sequence alignment of the contigs, used to generate a consensus.
  - `4_reads.fastq`: share of the total reads set that best align with the considered cluster.
  - `7_final_consensus`: final consensus assembly generated by trycycler.
  - `8_medaka.fasta`: assembly polished by medaka. This is done using raw fastq reads.
  - `prokka` directory: contains files with the annotated genome in various format, including `<sample-id>.gbk`.

  A more complete description for the meaning of these files can be found in the [Trycycler wiki](https://github.com/rrwick/Trycycler/wiki).

  ## References

  paper describing the Trycycler pipeline: [Wick RR, Judd LM, Cerdeira LT, Hawkey J, Méric G, Vezina B, Wyres KL, Holt KE. Trycycler: consensus long-read assemblies for bacterial genomes. Genome Biology. 2021. doi:10.1186/s13059-021-02483-z.](https://doi.org/10.1186/s13059-021-02483-z)