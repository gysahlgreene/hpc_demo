#!/bin/bash -l
# Strong-scaling study: run the same MPI problem on 1, 2, 4, ... 32 ranks
# and print speedup and parallel efficiency.
#
#   sbatch mpi_scaling.slurm                 # mpi_pi.py (little communication)
#   sbatch mpi_scaling.slurm mpi_heat.py     # halo exchange every step
#   sbatch mpi_scaling.slurm mpi_heat.py --n 200000
#
# This uses every node in the physical partition, so keep runs short.
#SBATCH --job-name=mpi-scaling
#SBATCH --partition=physical
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=8
#SBATCH --hint=nomultithread
#SBATCH --mem=8G
#SBATCH --time=00:15:00
#SBATCH --output=mpi-scaling-%j.out

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

APP="${1:-mpi_pi.py}"
shift $(( $# > 0 ))
if [[ -f "${SUBMIT_DIR}/${APP}" ]]; then
  MPI_APP="${SUBMIT_DIR}/${APP}"
elif [[ -f "${SUBMIT_DIR}/examples/mpi/${APP}" ]]; then
  MPI_APP="${SUBMIT_DIR}/examples/mpi/${APP}"
else
  echo "Could not find ${APP} from submit directory: ${SUBMIT_DIR}" >&2
  echo "Submit from the repo root or from examples/mpi." >&2
  exit 1
fi

echo "Scaling study for: ${MPI_APP} $*"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Nodes allocated: $(scontrol show hostnames "$SLURM_JOB_NODELIST" | tr '\n' ' ')"
echo

export PMIX_MCA_psec=native
results=""
for ranks in 1 2 4 8 16 32; do
  (( ranks <= SLURM_NTASKS )) || break
  # Fill one node before using the next: ranks on the same node talk fastest.
  nodes=$(( (ranks + SLURM_NTASKS_PER_NODE - 1) / SLURM_NTASKS_PER_NODE ))
  output=$(srun --mpi=pmix_v5 --nodes="$nodes" --ntasks="$ranks" python3 "$MPI_APP" "$@")
  echo "$output"
  results+="nodes=${nodes} $(grep '^RESULT' <<<"$output")"$'\n'
done

echo
awk 'BEGIN { printf "%6s %6s %9s %8s %11s %15s\n", "ranks", "nodes", "seconds", "speedup", "efficiency", "value" }
NF {
  for (i = 1; i <= NF; i++) { split($i, kv, "="); f[kv[1]] = kv[2] }
  if (!base) base = f["seconds"]
  speedup = base / f["seconds"]
  printf "%6d %6d %9.2f %8.2f %10.0f%% %15s\n", f["ranks"], f["nodes"], f["seconds"], speedup, 100 * speedup / f["ranks"], f["value"]
}' <<<"$results"
