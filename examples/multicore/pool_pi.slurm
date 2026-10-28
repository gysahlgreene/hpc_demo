#!/bin/bash -l
# One program using several cores on one node, timed with 1, 2, 4 and 8 workers.
# Extra arguments go to pool_pi.py, e.g. `sbatch examples/multicore/pool_pi.slurm --workers 1`.
#SBATCH --job-name=pool-pi
#SBATCH --partition=physical
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --hint=nomultithread
#SBATCH --mem=4G
#SBATCH --time=00:10:00
#SBATCH --output=pool-pi-%j.out

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
module load python/3.11.9

if [[ -f "${SUBMIT_DIR}/pool_pi.py" ]]; then
  APP="${SUBMIT_DIR}/pool_pi.py"
elif [[ -f "${SUBMIT_DIR}/examples/multicore/pool_pi.py" ]]; then
  APP="${SUBMIT_DIR}/examples/multicore/pool_pi.py"
else
  echo "Could not find pool_pi.py from submit directory: ${SUBMIT_DIR}" >&2
  echo "Submit from the repo root or from examples/multicore." >&2
  exit 1
fi

echo "Running on host: $(hostname)"
echo "Job ID: ${SLURM_JOB_ID}"
echo

python3 "$APP" --sweep "$@"
