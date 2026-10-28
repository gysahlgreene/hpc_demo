#!/bin/bash -l
# How many CPU cores does a GPU job need? Times the same training with
# 0, 1, 2, 4, ... data-loader workers. Extra arguments go to gpu_dataloader.py.
# Needs the PyTorch environment: run `bash examples/gpu/setup_torch_env.sh` once first.
#SBATCH --job-name=gpu-dataloader
#SBATCH --partition=physical-gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=00:15:00
#SBATCH --output=gpu-dataloader-%j.out

set -euo pipefail

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$SUBMIT_DIR"

# The GPU nodes have no `module` command. The environment made by
# setup_torch_env.sh works without it.
VENV="$HOME/venvs/hpc-torch"
if [[ ! -f "$VENV/bin/activate" ]]; then
  echo "No PyTorch environment in $VENV. Run: bash examples/gpu/setup_torch_env.sh" >&2
  exit 1
fi
source "$VENV/bin/activate"

if [[ -f "${SUBMIT_DIR}/gpu_dataloader.py" ]]; then
  APP="${SUBMIT_DIR}/gpu_dataloader.py"
elif [[ -f "${SUBMIT_DIR}/examples/gpu/gpu_dataloader.py" ]]; then
  APP="${SUBMIT_DIR}/examples/gpu/gpu_dataloader.py"
else
  echo "Could not find gpu_dataloader.py from submit directory: ${SUBMIT_DIR}" >&2
  echo "Submit from the repo root." >&2
  exit 1
fi

echo "Running on host: $(hostname)"
echo "Job ID: ${SLURM_JOB_ID}"

# Record GPU use every 5 seconds for the whole job, in gpu-usage-<jobid>.csv.
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 5 \
  > "gpu-usage-${SLURM_JOB_ID}.csv" &

python3 "$APP" "$@"
