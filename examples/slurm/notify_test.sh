#!/bin/bash
#SBATCH --job-name=notify_test
#SBATCH --output=notify_test_%j.out
#SBATCH --partition=cloud
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=you@example.com   # replace on the command line: sbatch --mail-user=...

set -euo pipefail

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$SUBMIT_DIR"

echo "Job running on $(hostname)"
echo "Submit directory: ${SUBMIT_DIR}"
echo "You should get an email when this job ends."
sleep 60
echo "Job finished."
