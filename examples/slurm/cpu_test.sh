#!/bin/bash
#SBATCH --job-name=cpu_test
#SBATCH --output=cpu_test_%j.out
#SBATCH --partition=physical
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:10:00

set -euo pipefail

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$SUBMIT_DIR"

module load gcc-runtime/13.2.0

echo "Running on host: $(hostname)"
echo "Job ID: ${SLURM_JOB_ID:-not-running-under-slurm}"
echo "Submit directory: ${SUBMIT_DIR}"
echo "Allocated CPUs: ${SLURM_CPUS_PER_TASK:-unknown}"
echo "Job started at: $(date)"

python3 - <<'PY'
import os
import socket

host = socket.gethostname()
cpus = os.environ.get("SLURM_CPUS_PER_TASK", "unknown")

print(f"Hello from Slurm on {host}.")
print(f"This task can use {cpus} CPU core(s).")
PY

echo "Job finished at: $(date)"
