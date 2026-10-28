#!/bin/bash -l
# Job array: 6 independent single-core jobs, one per problem size.
# Each array task gets its own SLURM_ARRAY_TASK_ID (1..6) and its own output file.
# Add a throttle such as --array=1-6%2 to run at most 2 at a time.
#SBATCH --job-name=array-sweep
#SBATCH --partition=cloud
#SBATCH --array=1-6
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:02:00
#SBATCH --output=array-sweep-%A_%a.out

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

N=$(( 10 ** SLURM_ARRAY_TASK_ID ))
echo "Array job ${SLURM_ARRAY_JOB_ID}, task ${SLURM_ARRAY_TASK_ID} on $(hostname): n=${N}"
python3 "$APP" --n "$N"

sleep 30  # Only so the tasks stay in squeue long enough to watch. Remove in real work.
