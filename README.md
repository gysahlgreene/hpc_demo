# Boole HPC Slurm Workshop

This repository accompanies a short introduction to running work on the
CloudCIX Boole HPC platform with Slurm.

Participants can clone the repo, inspect the examples, submit jobs, monitor
them, and compare the output with the explanations in the guide.

## Quick Start

Open a terminal on Boole, for example through **Boole Shell Access** in Open
OnDemand:

```bash
git clone <repository-url>
cd hpc_demo
```

If you already have this repository:

```bash
git pull
```

## Workshop Flow

1. Read the platform overview in [docs/boole_hpc_platform_guide.md](docs/boole_hpc_platform_guide.md).
2. Try an interactive Slurm allocation:

   ```bash
   srun --partition=cloud --cpus-per-task=2 --mem=4G --time=01:00:00 --pty bash
   ```

3. Submit the CPU batch example:

   ```bash
   sbatch examples/slurm/cpu_test.sh
   squeue -u "$USER"
   cat cpu_test_<jobid>.out
   ```

4. Submit the MPI example:

   ```bash
   cd examples/mpi
   sbatch mpi_demo.slurm
   cat mpi-demo-*.out
   ```

   The MPI job loads `openmpi/5.0.5`, `python/3.11.9`, and
   `py-mpi4py/4.0.1` inside the batch script.

5. If GPU nodes are available to you, submit the GPU example:

   ```bash
   sbatch examples/gpu/gpu_test.sh
   cat gpu_test_<jobid>.out
   ```

   The GPU job loads the Ubuntu 24.04 Spack module tree and `cuda/12.9.0`,
   then prints `nvidia-smi` and `nvcc --version`.

6. Explore the container example when that topic comes up in the presentation.

## Repository Layout

```text
.
├── docs/
│   └── boole_hpc_platform_guide.md
├── examples/
│   ├── containers/
│   ├── gpu/
│   ├── mpi/
│   └── slurm/
└── exercises/
```

## Common Slurm Commands

```bash
sinfo                         # Show partitions and node state
squeue -u "$USER"             # Show your jobs
sbatch path/to/script.sh       # Submit a batch job
scancel <jobid>                # Cancel a job
scontrol show job <jobid>      # Detailed job information
sacct -j <jobid>               # Accounting information after completion
```

## Notes for Participants

The examples request modest resources, but cluster availability changes during
the day. If a job sits pending, try the troubleshooting section in the guide:
check `sinfo`, reduce resources, shorten the time limit, or use a different
partition where appropriate.

The Slurm scripts use `SLURM_SUBMIT_DIR`, which is the directory where you ran
`sbatch`. Submit from the repo root or from the example directory shown in the
workshop flow.

Do not put credentials in this repository.
