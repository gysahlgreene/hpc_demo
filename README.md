# Boole HPC Slurm Workshop

This repository accompanies a short introduction to running work on the
CloudCIX Boole HPC platform with Slurm.

Participants can clone the repo, inspect the examples, submit jobs, monitor
them, and compare the output with the explanations in the guide.

## Quick Start

Open a terminal on Boole, for example through **Boole Shell Access** in the CloudCIX dashboard, and run:

```bash
git clone <repository-url>
cd hpc_demo
```

If you already have this repository:

```bash
git pull
```

## Workshop Flow

1. Read the platform overview in [docs/boole_hpc_platform_guide.md](docs/boole_hpc_platform_guide.md),
   then [docs/parallel_computing_guide.md](docs/parallel_computing_guide.md)
   for using many cores and nodes.
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

4. Use many cores on one node, then many independent jobs:

   ```bash
   cd examples/multicore
   sbatch pool_pi.slurm
   sbatch array_sweep.slurm
   cd ../..
   ```

5. Run MPI across nodes, then measure how it scales:

   ```bash
   cd examples/mpi
   sbatch mpi_demo.slurm
   sbatch mpi_scaling.slurm
   sbatch mpi_scaling.slurm mpi_heat.py
   sbatch mpi_hybrid.slurm
   cd ../..
   ```

   The MPI jobs load `openmpi/5.0.5`, `python/3.11.9`, `py-mpi4py/4.0.1`,
   and `py-numpy/2.1.2` inside the batch script. The
   [Parallel Computing Guide](docs/parallel_computing_guide.md) explains
   these examples step by step, with real output from Boole.

6. If GPU nodes are available to you, submit the GPU example:

   ```bash
   sbatch examples/gpu/gpu_test.sh
   cat gpu_test_<jobid>.out
   ```

   The GPU job prints `nvidia-smi` and `nvcc --version` from the allocated GPU
   node.

7. Explore the container example when that topic comes up in the presentation.

## Repository Layout

```text
.
├── docs/
│   ├── boole_hpc_platform_guide.md
│   └── parallel_computing_guide.md
├── examples/
│   ├── containers/
│   ├── gpu/
│   ├── mpi/          # MPI demo, scaling study, hybrid job
│   ├── multicore/    # one node, many cores; job arrays
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

`mpi_scaling.slurm` takes all four `physical` nodes for about a minute and a
half. In a busy session, have one person run it and share the output.

The Slurm scripts use `SLURM_SUBMIT_DIR`, which is the directory where you ran
`sbatch`. Submit from the repo root or from the example directory shown in the
workshop flow.

Do not put credentials in this repository.
