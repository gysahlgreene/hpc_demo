#!/bin/bash -l
# Hybrid MPI x threads: 2 nodes x 2 ranks per node x 4 threads per rank = 16 cores.
# Extra arguments go to mpi_pi.py, e.g. `sbatch examples/mpi/mpi_hybrid.slurm --chunk 262144`.
#SBATCH --job-name=mpi-hybrid
#SBATCH --partition=physical
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=4
#SBATCH --hint=nomultithread
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --output=mpi-hybrid-%j.out

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
module load openmpi/5.0.5
module load python/3.11.9
module load py-mpi4py/4.0.1
module load py-numpy/2.1.2

if [[ -f "${SUBMIT_DIR}/mpi_pi.py" ]]; then
  APP_DIR="${SUBMIT_DIR}"
elif [[ -f "${SUBMIT_DIR}/examples/mpi/mpi_pi.py" ]]; then
  APP_DIR="${SUBMIT_DIR}/examples/mpi"
else
  echo "Could not find mpi_pi.py from submit directory: ${SUBMIT_DIR}" >&2
  echo "Submit from the repo root or from examples/mpi." >&2
  exit 1
fi

echo "Job ID: ${SLURM_JOB_ID}"
echo "${SLURM_NTASKS} ranks x ${SLURM_CPUS_PER_TASK} CPUs per rank"
echo

export PMIX_MCA_psec=native
# Passed explicitly because some Slurm versions don't hand --cpus-per-task from sbatch on to srun.
srun --mpi=pmix_v5 --cpus-per-task="$SLURM_CPUS_PER_TASK" python3 "${APP_DIR}/mpi_hello.py"
echo
srun --mpi=pmix_v5 --cpus-per-task="$SLURM_CPUS_PER_TASK" python3 "${APP_DIR}/mpi_pi.py" "$@"
