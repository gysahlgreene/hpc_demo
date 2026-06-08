#!/bin/bash
#SBATCH --job-name=gpu_test
#SBATCH --output=gpu_test_%j.out
#SBATCH --partition=physical-gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:10:00

set -euo pipefail

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$SUBMIT_DIR"

module purge
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
module load cuda/12.9.0

echo "Running on host: $(hostname)"
echo "Job ID: ${SLURM_JOB_ID:-not-running-under-slurm}"
echo "Submit directory: ${SUBMIT_DIR}"
echo "CUDA visible devices: ${CUDA_VISIBLE_DEVICES:-not set}"
module list

nvidia-smi
nvcc --version

python3 - <<'PY'
print("GPU allocation test complete. Add your CUDA or ML workload here.")
PY
