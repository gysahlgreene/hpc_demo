#!/bin/bash -l
# A program in your own Conda environment (see the Conda section of the platform guide).
# Don't load the cluster's python modules in the same job.
#SBATCH --job-name=my-job            # CHANGE: a short name
#SBATCH --partition=cloud            # CHANGE if needed: cloud or physical
#SBATCH --cpus-per-task=1            # CHANGE: more only if your program uses them
#SBATCH --mem=2G                     # CHANGE: peak memory plus a margin (check MaxRSS with sacct)
#SBATCH --time=01:00:00              # CHANGE: expected run time plus a margin
#SBATCH --output=%x-%j.out           # %x = job name, %j = job ID

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

source "$HOME/miniforge3/bin/activate" my_env   # CHANGE: your environment name

python my_script.py                  # CHANGE: your command
