#!/bin/bash -l
#SBATCH --job-name=cpu_test
#SBATCH --output=cpu_test_%j.out
#SBATCH --partition=physical
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:10:00

set -euo pipefail

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$SUBMIT_DIR"

unset -f module ml 2>/dev/null || true
if [[ -r /etc/profile.d/lmod.sh ]]; then
  source /etc/profile.d/lmod.sh
elif [[ -r /usr/share/lmod/lmod/init/bash ]]; then
  source /usr/share/lmod/lmod/init/bash
fi

module purge
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
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
