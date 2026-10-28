#!/bin/bash -l
# The same program on many input files: one array task per line of inputs.txt.
# Make the list, then submit one task per line (at most 10 running at once):
#
#   ls data/*.csv > inputs.txt
#   sbatch --array=1-$(wc -l < inputs.txt)%10 array_files.slurm
#
# (If you forget --array, the job fails and explains why in
# <job name>-<jobid>_4294967294.out.)
#
#SBATCH --job-name=my-array          # CHANGE: a short name
#SBATCH --partition=cloud            # CHANGE if needed: cloud or physical
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G                     # CHANGE: peak memory of ONE task plus a margin
#SBATCH --time=00:30:00              # CHANGE: run time of ONE task plus a margin
#SBATCH --output=%x-%A_%a.out        # %A = array job ID, %a = task number

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

: "${SLURM_ARRAY_TASK_ID:?Submit with sbatch --array=1-N, one task per line of inputs.txt}"
INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" inputs.txt)
if [[ -z "$INPUT" ]]; then
  echo "inputs.txt has no line ${SLURM_ARRAY_TASK_ID}" >&2
  exit 1
fi
echo "Task ${SLURM_ARRAY_TASK_ID}: $INPUT"

# --- Boole module setup: keep as it is ---
unset -f module ml 2>/dev/null || true
if [[ -r /etc/profile.d/lmod.sh ]]; then
  source /etc/profile.d/lmod.sh
elif [[ -r /usr/share/lmod/lmod/init/bash ]]; then
  source /usr/share/lmod/lmod/init/bash
fi
module purge
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
# --- end of module setup ---

module load python/3.11.9            # CHANGE: the software your program needs

python3 my_script.py "$INPUT"        # CHANGE: your command
