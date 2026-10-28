#!/bin/bash -l
# One program on one CPU core. Copy this file and edit the lines marked CHANGE.
#SBATCH --job-name=my-job            # CHANGE: a short name
#SBATCH --partition=cloud            # CHANGE if needed: cloud or physical
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G                     # CHANGE: peak memory plus a margin (check MaxRSS with sacct)
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

python3 my_script.py                 # CHANGE: your command
