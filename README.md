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

5. If GPU nodes are available to you, submit the GPU example:

   ```bash
   sbatch examples/gpu/gpu_test.sh
   cat gpu_test_<jobid>.out
   ```

6. Explore the container and object storage examples when those topics come up
   in the presentation.

## Repository Layout

```text
.
├── docs/
│   └── boole_hpc_platform_guide.md
├── examples/
│   ├── containers/
│   ├── gpu/
│   ├── mpi/
│   ├── object-storage/
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

Do not put credentials in this repository. Object storage examples use
placeholders for access keys, bucket names, and endpoints.
