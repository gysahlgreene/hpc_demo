#!/bin/bash
#SBATCH --job-name=notify_test
#SBATCH --output=notify_test_%j.out
#SBATCH --partition=physical
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=you@example.com

set -euo pipefail

echo "Job running on $(hostname)"
echo "Replace --mail-user before using this in a real workshop account."
sleep 60
echo "Job finished."
