#!/bin/bash
#SBATCH --job-name=apptainer-hello
#SBATCH --output=apptainer-hello-%j.out
#SBATCH --partition=cloud
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00

set -euo pipefail

IMAGE="hello-world_latest.sif"

echo "Running on host: $(hostname)"

if [[ ! -f "$IMAGE" ]]; then
  apptainer pull docker://hello-world
fi

apptainer inspect "$IMAGE"
apptainer run "$IMAGE"
