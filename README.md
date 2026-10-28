# Boole HPC Workshop: From Your First Job to Many Nodes

**This repository teaches you to run your work on the CloudCIX Boole HPC
cluster with Slurm, and to make it faster by using many CPU cores and many
nodes at once.**

It is hands-on. Every topic has a job script you submit on Boole, an output
file you read, and an exercise where you change something and see what
happens. All the sample output in the guides comes from real runs on Boole.

## Who It Is For

Researchers and students who can run a Python script on their own computer and
now want to run it on HPC. You don't need to know Slurm or MPI beforehand. The
examples are in Python, but the ideas apply to any language.

## What You Will Learn

| # | By the end you can... | Read | Run | Exercise |
| --- | --- | --- | --- | --- |
| 1 | Submit, monitor and cancel interactive and batch jobs, and request CPUs, memory and time | [Platform guide](docs/boole_hpc_platform_guide.md#slurm-basics) | `examples/slurm/` | 1-4 |
| 2 | Tell real cores from hyperthreads, and request whole cores on the `physical` nodes | [Parallel guide §1-3](docs/parallel_computing_guide.md#1-know-your-hardware) | `examples/mpi/mpi_demo.slurm` | 1, 5 |
| 3 | Use every core you asked for on one node, sizing your program from the allocation | [§4](docs/parallel_computing_guide.md#4-many-cores-on-one-node) | `examples/multicore/pool_pi.slurm` | 6 |
| 4 | Run hundreds of independent jobs (parameter sweeps, many files) with job arrays | [§5](docs/parallel_computing_guide.md#5-many-independent-jobs-job-arrays) | `examples/multicore/array_sweep.slurm` | 7 |
| 5 | Run MPI programs across nodes with `srun`, check where ranks run, and pass messages between them | [§6](docs/parallel_computing_guide.md#6-many-nodes-mpi) | `examples/mpi/` | 5, 11 |
| 6 | Measure speedup and efficiency, and choose how many cores to use | [§7](docs/parallel_computing_guide.md#7-scaling-does-more-cores-mean-faster) | `examples/mpi/mpi_scaling.slurm` | 8 |
| 7 | Lay out hybrid jobs (MPI ranks x threads), and know when they pay off | [§8](docs/parallel_computing_guide.md#8-hybrid-mpi-and-threads) | `examples/mpi/mpi_hybrid.slurm` | 9 |
| 8 | Check whether a finished job used the CPUs and memory it reserved | [§9](docs/parallel_computing_guide.md#9-was-my-job-efficient) | `sacct` | 4, 10 |
| 9 | Run a GPU job and an Apptainer container (short introductions) | [GPU](docs/boole_hpc_platform_guide.md#batch-gpu-job), [containers](docs/boole_hpc_platform_guide.md#running-docker-images-with-apptainer-on-hpc) | `examples/gpu/`, `examples/containers/` | 12 |

The exercises are in [exercises/README.md](exercises/README.md).

The core of the workshop is rows 2-8: **getting the most out of the CPUs you
request.** Asking for more cores never makes a program faster by itself. These
sections show how to make your work actually use them, and how to check that
it does.

## Not Covered

- Writing or optimising numerical code, or GPU programming (CUDA, PyTorch).
- Compiled languages such as C, C++ or Fortran. The ideas carry over, but the
  examples are Python.
- Managing or administering the cluster.

## Quick Start

Open a terminal on Boole, for example through **Boole Shell Access** in the CloudCIX dashboard, and run:

```bash
git clone https://github.com/gysahlgreene/hpc_demo.git
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
