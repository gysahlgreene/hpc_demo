#!/bin/bash -l
# One-off setup: a Python environment with PyTorch for the GPU examples.
# Run it once, on the login node (it only downloads and installs, about 5.5 GB and 3 minutes):
#
#   bash examples/gpu/setup_torch_env.sh

set -euo pipefail

VENV="$HOME/venvs/hpc-torch"

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

if "$VENV/bin/python" -c "import torch, pynvml, numpy" 2>/dev/null; then
  echo "Already set up: $VENV"
  exit 0
fi

echo "Creating $VENV and installing PyTorch. This takes a few minutes."
start=$SECONDS
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --no-cache-dir --upgrade pip
# torch is pinned to the version tested on Boole's GPU driver.
"$VENV/bin/pip" install --quiet --no-cache-dir torch==2.14.1 numpy nvidia-ml-py
echo "Done in $(( SECONDS - start )) s, using $(du -sh "$VENV" | cut -f1) in $VENV"
"$VENV/bin/python" -c "import torch; print('PyTorch', torch.__version__, 'built for CUDA', torch.version.cuda)"
