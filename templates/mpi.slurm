#!/bin/bash -l
# An MPI program across several nodes: one rank per core.
#SBATCH --job-name=my-mpi            # CHANGE: a short name
#SBATCH --partition=physical
#SBATCH --nodes=2                    # CHANGE: nodes (physical has 4)
#SBATCH --ntasks-per-node=8          # CHANGE: ranks per node (at most 8 on physical)
#SBATCH --hint=nomultithread         # one rank per real core
#SBATCH --mem=8G                     # CHANGE: memory PER NODE, plus a margin
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

module load openmpi/5.0.5 python/3.11.9 py-mpi4py/4.0.1 py-numpy/2.1.2   # CHANGE if needed

export PMIX_MCA_psec=native          # avoids harmless "psec: munge" error messages
srun --mpi=pmix_v5 python3 my_mpi_script.py   # CHANGE: your command (keep srun in front)
