# Import data from experiment archive

The `import_data.py` script is an utility script that can be used to internally import data from the `nccr-antiresist` folder on `scicore`, and load it in a subfolder inside of the `runs` folder for later assembly.
The script has the following usage:

```
usage: import_data.py [-h] --samples_yml SAMPLES_YML --runs_fld RUNS_FLD [--experiment_fld EXPERIMENT_FLD]

Utility script used to import and set up data from the nccr experiment folder.
It creates links to basecalled genomes in the correct format for later processing with the assembly pipeline.

optional arguments:
  -h, --help            show this help message and exit
  --samples_yml SAMPLES_YML
                        the yaml file containing the list of selected samples to import.
  --runs_fld RUNS_FLD   the destination runs folder
  --experiment_fld EXPERIMENT_FLD
                        the experiment archive folder, containing one subfolder per experiment.
                        (default: /scicore/home/nccr-antiresist/GROUP/unibas/neher/experiments)
```
The arguments are:
- `--samples_yml`: yaml file specifying the selected samples that one wants to load
- `--runs_fld`: the destination folder in which the reads must be archived.
- `--experiment_fld`: the source archive folder in which all experiments are stored. Default value is `/scicore/home/nccr-antiresist/GROUP/unibas/neher/experiments`

an example of usage is:
```bash
python3 scripts/import_data.py \
  --samples_yml scripts/samples_example.yml \
  --runs_fld runs \
  --experiment_fld /scicore/home/nccr-antiresist/GROUP/unibas/neher/experiments
```


## selecting the samples

The yaml file passed as `--samples_yml` argument to the script must have the following structure:

```yaml
run-id: my_run
samples:
  experiment_1:
    - sample_1
    - sample_2
    - sample_3
  experiment_2:
    - sample_1
    - sample_2
    - sample_3
```
A concrete example is provided in the `samples_example.yml` file.
The value of `run-id` will be used to create a name for the subfolder of `runs` where the data are stored. This will be named `runs/<date>_<run-id>`. The following folder structure is created:

```
runs
└── <date>_<my_run>
    ├── imported_reads_info.csv
    └── reads
        ├── <date>_<experiment_1>_<sample_1>.fastq.gz
        ├── <date>_<experiment_1>_<sample_2>.fastq.gz
        ├── <date>_<experiment_1>_<sample_3>.fastq.gz
        ├── <date>_<experiment_2>_<sample_1>.fastq.gz
        ├── <date>_<experiment_2>_<sample_2>.fastq.gz
        └── <date>_<experiment_2>_<sample_3>.fastq.gz
```

The table `imported_reads_info.csv` contains a list of imported samples.