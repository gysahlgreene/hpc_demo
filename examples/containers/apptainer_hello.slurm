#!/bin/bash
#SBATCH --job-name=apptainer-hello
#SBATCH --output=apptainer-hello-%j.out
#SBATCH --partition=cloud
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00

set -euo pipefail

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$SUBMIT_DIR"

IMAGE="${SUBMIT_DIR}/hello-world_latest.sif"

echo "Running on host: $(hostname)"
echo "Submit directory: ${SUBMIT_DIR}"
echo "Container image: ${IMAGE}"

if [[ ! -f "$IMAGE" ]]; then
  apptainer pull docker://hello-world
fi

apptainer inspect "$IMAGE"
apptainer run "$IMAGE"
