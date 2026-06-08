#!/bin/bash -l
#SBATCH --job-name=mpi-demo
#SBATCH --partition=physical
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --time=00:05:00
#SBATCH --output=mpi-demo-%j.out

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

if [[ -f "${SUBMIT_DIR}/mpi_hello.py" ]]; then
  MPI_APP="${SUBMIT_DIR}/mpi_hello.py"
elif [[ -f "${SUBMIT_DIR}/examples/mpi/mpi_hello.py" ]]; then
  MPI_APP="${SUBMIT_DIR}/examples/mpi/mpi_hello.py"
else
  echo "Could not find mpi_hello.py from submit directory: ${SUBMIT_DIR}" >&2
  echo "Submit from the repo root or from examples/mpi." >&2
  exit 1
fi

echo "Running MPI demo"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Submit directory: ${SUBMIT_DIR}"
echo "MPI application: ${MPI_APP}"
echo "Python: $(command -v python3)"
python3 --version
module list
echo "Nodes allocated:"
scontrol show hostnames "$SLURM_JOB_NODELIST"
echo

mpirun python3 "$MPI_APP"
