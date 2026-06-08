#!/bin/bash
#SBATCH --job-name=mpi-demo
#SBATCH --partition=physical
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --time=00:05:00
#SBATCH --output=mpi-demo-%j.out

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

echo "Running MPI demo"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Nodes allocated:"
scontrol show hostnames "$SLURM_JOB_NODELIST"

mpirun python3 mpi_hello.py
