#!/bin/bash -l
# One program using several cores on one node (multiprocessing, joblib, OpenMP, R parallel).
# Your program must use $SLURM_CPUS_PER_TASK workers or threads, not os.cpu_count().
#SBATCH --job-name=my-job            # CHANGE: a short name
#SBATCH --partition=physical
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8            # CHANGE: cores (at most 8 on physical)
#SBATCH --hint=nomultithread         # whole cores, not hyperthreads
#SBATCH --mem=8G                     # CHANGE: peak memory plus a margin (check MaxRSS with sacct)
#SBATCH --time=01:00:00              # CHANGE: expected run time plus a margin
#SBATCH --output=%x-%j.out           # %x = job name, %j = job ID

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

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

export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"   # for libraries that use OpenMP threads
python3 my_script.py --workers "$SLURM_CPUS_PER_TASK"   # CHANGE: your command
