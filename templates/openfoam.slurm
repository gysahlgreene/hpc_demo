#!/bin/bash -l
# Your own OpenFOAM case, in parallel with MPI. Submit it from inside the case
# folder (the one holding 0/, constant/ and system/):
#
#   cd ~/myproject/mycase
#   sbatch ~/myproject/openfoam.slurm
#
# The case needs a system/decomposeParDict; copy one from a tutorial if it has none.
#SBATCH --job-name=my-openfoam       # CHANGE: a short name
#SBATCH --partition=physical
#SBATCH --nodes=1                    # CHANGE: nodes (physical has 4)
#SBATCH --ntasks-per-node=8          # CHANGE: MPI ranks per node (at most 8 on physical)
#SBATCH --hint=nomultithread         # one rank per real core
#SBATCH --mem=16G                    # CHANGE: memory PER NODE, plus a margin
#SBATCH --time=02:00:00              # CHANGE: expected run time plus a margin
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

module load openmpi/5.0.5-vzxfkrh   # the MPI build OpenFOAM was compiled with
# The openfoam module doesn't load on Boole at the moment, so use OpenFOAM's own
# setup script. It reads unset variables, so relax `set -u` around it.
set +u
source /opt/spack/spack/opt/spack/linux-cascadelake/openfoam-2412-apc5rmqfcstzgka25loohisejf6flusj/etc/bashrc
set -u

SOLVER=simpleFoam                    # CHANGE: your solver (icoFoam, pimpleFoam, interFoam, ...)

fail() { echo "$1 failed: see log.$1 in $PWD" >&2; exit 1; }

# blockMesh > log.blockMesh 2>&1 || fail blockMesh   # CHANGE: uncomment if the mesh isn't built yet

# One mesh piece per MPI rank (scotch splits a mesh into any number of pieces),
# then the solver on all ranks, then join the pieces back together.
foamDictionary -entry numberOfSubdomains -set "$SLURM_NTASKS" system/decomposeParDict > /dev/null 2>&1
foamDictionary -entry method -set scotch system/decomposeParDict > /dev/null 2>&1
decomposePar -force > log.decomposePar 2>&1 || fail decomposePar

export PMIX_MCA_psec=native          # avoids harmless "psec: munge" error messages
srun --mpi=pmix_v5 "$SOLVER" -parallel > "log.$SOLVER" 2>&1 || fail "$SOLVER"

reconstructPar -latestTime > log.reconstructPar 2>&1 || fail reconstructPar
echo "Done: results for the last time step are in $PWD"
