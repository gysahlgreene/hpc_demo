#!/bin/bash -l
# A GPU job using the PyTorch environment from examples/gpu/setup_torch_env.sh.
# Each node has ONE GPU. Ask for the CPUs your data loading needs, not the whole
# node: the rest of the node can then run other people's jobs.
#SBATCH --job-name=my-gpu            # CHANGE: a short name
#SBATCH --partition=physical-gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=9            # CHANGE: data-loader workers + 1 (see docs/gpu_guide.md)
#SBATCH --mem=32G                    # CHANGE: peak memory plus a margin (check MaxRSS with sacct)
#SBATCH --time=02:00:00              # CHANGE: expected run time plus a margin
#SBATCH --output=%x-%j.out           # %x = job name, %j = job ID

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

# The GPU nodes have no `module` command: activate your environment directly.
source "$HOME/venvs/hpc-torch/bin/activate"   # CHANGE if you use another environment

# Record GPU use every 30 seconds; check it afterwards to see if the GPU was kept busy.
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 30 \
  > "gpu-usage-${SLURM_JOB_ID}.csv" &

# In your code, use SLURM_CPUS_PER_TASK - 1 data-loader workers (see docs/gpu_guide.md).
python3 train.py                     # CHANGE: your command
