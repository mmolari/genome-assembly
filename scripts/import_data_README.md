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
- `samples_yml`


an example of usage is:
```bash
python3 scripts/import_data.py \
  --samples_yml scripts/selected_samples_example.yml \
  --experiment_fld /scicore/home/nccr-antiresist/GROUP/unibas/neher/experiments \
  --runs_fld runs
```

## samples yaml file


```yaml
run-id: test_run
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
