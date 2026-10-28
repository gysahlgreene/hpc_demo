#!/bin/bash -l
# OpenFOAM in parallel with MPI: the lid-driven cavity tutorial on a finer mesh.
#
#   sbatch examples/openfoam/cavity.slurm                              # one run on 8 ranks
#   sbatch --nodes=4 examples/openfoam/cavity.slurm 1 2 4 8 16 32      # scaling study
#
# Arguments are rank counts to try (default: all the job's tasks). The mesh is
# MESH x MESH cells (default 200) and the run is STEPS time steps (default 100):
#
#   sbatch --export=ALL,MESH=100 examples/openfoam/cavity.slurm
#
#SBATCH --job-name=openfoam-cavity
#SBATCH --partition=physical
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --hint=nomultithread
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=openfoam-cavity-%j.out

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
module load openmpi/5.0.5-vzxfkrh   # the MPI build OpenFOAM was compiled with

# The openfoam module doesn't load on Boole at the moment, so use OpenFOAM's own
# setup script instead. It reads unset variables, so relax `set -u` around it.
OPENFOAM_DIR=/opt/spack/spack/opt/spack/linux-cascadelake/openfoam-2412-apc5rmqfcstzgka25loohisejf6flusj
set +u
source "$OPENFOAM_DIR/etc/bashrc"
set -u

MESH="${MESH:-200}"
STEPS="${STEPS:-100}"
RANKS=("$@")
(( ${#RANKS[@]} > 0 )) || RANKS=("$SLURM_NTASKS")
WORK="$SUBMIT_DIR/openfoam-cavity-$SLURM_JOB_ID"
export PMIX_MCA_psec=native

echo "OpenFOAM $WM_PROJECT_VERSION on $(scontrol show hostnames "$SLURM_JOB_NODELIST" | tr '\n' ' ')"
echo "Mesh ${MESH} x ${MESH} = $(( MESH * MESH )) cells, ${STEPS} time steps. Cases in ${WORK}"
echo

fail() { echo "$1 failed on $ranks ranks: see $case_dir/log.$1" >&2; exit 1; }

results=""
for ranks in "${RANKS[@]}"; do
  if (( ranks > SLURM_NTASKS )); then
    echo "Skipping $ranks ranks: this job only has $SLURM_NTASKS tasks."
    continue
  fi
  # Fill one node before using the next: ranks on the same node talk fastest.
  nodes=$(( (ranks + SLURM_NTASKS_PER_NODE - 1) / SLURM_NTASKS_PER_NODE ))
  case_dir="$WORK/ranks-$ranks"
  mkdir -p "$WORK"
  cp -r "$FOAM_TUTORIALS/incompressible/icoFoam/cavity/cavity" "$case_dir"
  cd "$case_dir"

  # Finer mesh, a time step small enough to stay stable (Courant number about 0.5),
  # STEPS steps writing results only at the end, and room for the pressure
  # solver to take more iterations, which a finer mesh needs.
  dt=$(awk -v m="$MESH" 'BEGIN { print 0.05 / m }')
  sed -i "s/(20 20 1)/($MESH $MESH 1)/" system/blockMeshDict
  foamDictionary -entry deltaT -set "$dt" system/controlDict > /dev/null 2>&1
  foamDictionary -entry endTime -set "$(awk -v d="$dt" -v s="$STEPS" 'BEGIN { print d * s }')" system/controlDict > /dev/null 2>&1
  foamDictionary -entry writeControl -set timeStep system/controlDict > /dev/null 2>&1
  foamDictionary -entry writeInterval -set "$STEPS" system/controlDict > /dev/null 2>&1
  for p in p pFinal; do
    foamDictionary -entry "solvers/$p/maxIter" -add 10000 system/fvSolution > /dev/null 2>&1
  done
  blockMesh > log.blockMesh 2>&1 || fail blockMesh

  # Split the mesh into one piece per rank, run the solver on all ranks, join the result.
  foamDictionary -entry numberOfSubdomains -set "$ranks" system/decomposeParDict > /dev/null 2>&1
  foamDictionary -entry method -set scotch system/decomposeParDict > /dev/null 2>&1
  start=$(date +%s.%N)
  if (( ranks == 1 )); then
    srun --nodes=1 --ntasks=1 icoFoam > log.icoFoam 2>&1 || fail icoFoam
  else
    decomposePar -force > log.decomposePar 2>&1 || fail decomposePar
    srun --mpi=pmix_v5 --nodes="$nodes" --ntasks="$ranks" icoFoam -parallel > log.icoFoam 2>&1 || fail icoFoam
    reconstructPar -latestTime > log.reconstructPar 2>&1 || fail reconstructPar
  fi
  seconds=$(awk -v s="$start" -v e="$(date +%s.%N)" 'BEGIN { printf "%.1f", e - s }')

  echo "$ranks ranks on $nodes node(s): ${seconds} s   ($(grep '^Courant' log.icoFoam | tail -1))"
  results+="$ranks $nodes $(( MESH * MESH / ranks )) $seconds"$'\n'
  cd "$SUBMIT_DIR"
done

echo
awk 'BEGIN { printf "%6s %6s %11s %9s %8s %11s\n", "ranks", "nodes", "cells/rank", "seconds", "speedup", "efficiency" }
NF {
  if (!base) { base = $4 * $1 }   # time on the first row, scaled to one rank
  printf "%6d %6d %11d %9.1f %8.2f %10.0f%%\n", $1, $2, $3, $4, base / $4, 100 * base / $4 / $1
}' <<<"$results"
echo
echo "The last case is in $case_dir. To view it in ParaView, run: touch $case_dir/case.foam"
