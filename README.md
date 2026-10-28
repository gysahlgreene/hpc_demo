# Boole HPC Workshop: From Your First Job to Many Nodes

**This repository teaches you to run your work on the CloudCIX Boole HPC
cluster with Slurm, and to make it faster by using many CPU cores and many
nodes at once.**

It is hands-on. Every topic has a job script you submit on Boole, an output
file you read, and an exercise where you change something and see what
happens. All the sample output in the guides comes from real runs on Boole.

## Who It Is For

Researchers and students who can run a Python script on their own computer and
now want to run it on HPC. You need basic shell commands (`cd`, `ls`, `cat`).
You don't need to know Slurm or MPI beforehand. The examples are in Python,
but the ideas apply to any language.

## What You Will Learn

| # | By the end you can... | Read | Exercise |
| --- | --- | --- | --- |
| 1 | Submit, monitor and cancel interactive and batch jobs, and request CPUs, memory and time | [Slurm Basics](docs/boole_hpc_platform_guide.md#slurm-basics) | 1-4 |
| 2 | Tell real cores from hyperthreads, and request whole cores on the `physical` nodes | [Parallel guide §1-3](docs/parallel_computing_guide.md#1-know-your-hardware) | 1, 5, 8 |
| 3 | Use every core you asked for on one node, sizing your program from the allocation | [§4](docs/parallel_computing_guide.md#4-many-cores-on-one-node) | 5 |
| 4 | Run hundreds of independent jobs (parameter sweeps, many files) with job arrays | [§5](docs/parallel_computing_guide.md#5-many-independent-jobs-job-arrays) | 6 |
| 5 | Check whether a job used the CPUs and memory it reserved | [§9](docs/parallel_computing_guide.md#9-was-my-job-efficient) | 4, 7 |
| 6 | Run MPI programs across nodes with `srun`, check where ranks run, and pass messages between them | [§6](docs/parallel_computing_guide.md#6-many-nodes-mpi) | 8, 12 |
| 7 | Measure speedup and efficiency, and choose how many cores to use | [§7](docs/parallel_computing_guide.md#7-scaling-does-more-cores-mean-faster) | 9 |
| 8 | Lay out hybrid jobs (MPI ranks x threads), and know when they pay off | [§8](docs/parallel_computing_guide.md#8-hybrid-mpi-and-threads) | 10 |
| 9 | Run a real MPI application, OpenFOAM, in parallel, and judge how far it scales | [OpenFOAM guide](docs/openfoam_guide.md) | 11 |
| 10 | Size a GPU job so the GPU stays busy without holding a whole node, and run a container | [GPU guide](docs/gpu_guide.md), [containers](docs/boole_hpc_platform_guide.md#running-docker-images-with-apptainer) | 13, 14 |
| 11 | Size Jupyter, VS Code and other interactive sessions, and end them when done | [Open OnDemand guide](docs/ondemand_guide.md) | 15 |
| 12 | Turn your own work into a job script from a template | [templates](templates/README.md) | 16 |

The core of the workshop is rows 2-9: **getting the most out of the CPUs and
memory you request.** Rows 10-11 apply the same idea to GPUs and to
interactive sessions; they are optional in the workshop but important if you
use either. Asking for more cores never makes a program faster by itself. These
sections show how to make your work actually use them, and how to check that
it does.

## Not Covered

- Writing or optimising numerical code, or GPU programming itself (CUDA, or
  how to use PyTorch; the GPU guide only covers sizing GPU jobs).
- Compiled languages such as C, C++ or Fortran. The ideas carry over, but the
  examples are Python.
- Managing or administering the cluster.

## How to Start

1. Open a terminal on Boole, for example through **Boole Shell Access** at
   <https://hpc.cloudcix.com>.
2. Get the workshop files into your home directory:

   ```bash
   cd ~
   git clone https://github.com/gysahlgreene/hpc_demo.git
   cd ~/hpc_demo
   ```

   If you cloned it before, update it instead with
   `cd ~/hpc_demo && git pull`. If `git pull` complains about local changes,
   run `git stash` and then `git pull` again.
3. Allow about three hours, including reading. Parts 4 and 5 of the
   exercises are optional.
4. Open [exercises/README.md](exercises/README.md) and work through it in
   order. Each exercise links to the part of the guides to read first.

Run every command from `~/hpc_demo`. Output files appear there.

## Words You Will Meet

| Word | Meaning |
| --- | --- |
| **Login node** | The machine your terminal opens on. Shared by everyone; for editing and submitting, not heavy work. |
| **Compute node** | A machine that runs jobs. |
| **Slurm** | The scheduler that queues jobs and gives them compute nodes. |
| **Partition** | A queue for one type of node: `cloud`, `physical` or `physical-gpu`. |
| **Job / job ID** | One request to Slurm, and the number `sbatch` gives it. |
| **Module** | A piece of installed software you switch on with `module load`. |
| **Socket** | One physical processor chip in a node. A node can have more than one. |
| **Core** | One independent processing unit in a processor. |
| **Hyperthread** | Half of a core that the system shows as a separate CPU. Not as fast as a real core. |
| **Process / thread** | A running program with its own memory / a second line of work inside one process, sharing its memory. |
| **Task / rank** | One copy of your program started by Slurm. In MPI it is called a rank. |
| **MPI** | The standard way for processes on different nodes to cooperate by sending messages. |
| **Speedup / efficiency** | How many times faster with N cores / speedup divided by N (100% is perfect). |
| **Python virtual environment (venv)** | A folder holding its own Python packages, switched on with `source <folder>/bin/activate`. |
| **Data-loader worker** | A process that prepares training data on the CPU while the GPU trains. |

## Repository Layout

```text
.
├── docs/
│   ├── boole_hpc_platform_guide.md   # Slurm basics, modules, GPUs, containers
│   ├── parallel_computing_guide.md   # cores, arrays, MPI, scaling, efficiency
│   ├── openfoam_guide.md             # OpenFOAM with MPI, and how it scales
│   ├── gpu_guide.md                  # sizing and checking GPU jobs
│   └── ondemand_guide.md             # sizing interactive sessions
├── examples/
│   ├── slurm/        # first batch job, email notification
│   ├── multicore/    # one node, many cores; job arrays
│   ├── mpi/          # MPI demo, scaling study, hybrid job
│   ├── openfoam/     # OpenFOAM cavity case, in parallel
│   ├── gpu/          # GPU test, PyTorch setup, data-loader sweep
│   └── containers/
├── templates/        # job scripts to copy for your own work
└── exercises/
    └── README.md     # start here
```

## Common Slurm Commands

```bash
sinfo                         # Show partitions and node state
squeue -u "$USER"             # Show your jobs
sbatch path/to/script.sh      # Submit a batch job
scancel <jobid>               # Cancel a job
scontrol show job <jobid>     # Detailed job information
sacct -j <jobid>              # Accounting information after completion
```

## Notes for Instructors

The cluster has 2 `cloud` nodes (16 cores), 4 `physical` nodes (32 cores) and
2 GPUs, so plan for a full room:

- Exercise 9 (`mpi_scaling.slurm`) holds all four `physical` nodes for up to a
  minute per run. Run it yourself as a demo and share the output.
- Exercise 10 runs use 2 `physical` nodes each. Have each table split the
  layouts between them.
- Exercise 11's OpenFOAM scaling study holds all four `physical` nodes for
  about 10 minutes for both meshes: run it as a demo. Students' single runs
  use one node for about 10 seconds each.
- Exercise 13's GPU sweep needs a GPU for about a minute, and there are
  only two: run it as a demo. Students who want to run it later first need
  `bash examples/gpu/setup_torch_env.sh` (about 3 minutes and 5.5 GB in their
  home directory); ask them to do that before the session.
- Exercise 15 is done in the Open OnDemand web page. Even at 1 core each,
  the `cloud` partition fits 16 sessions at once, so expect a short queue
  with a full room.
- Everything else is small, but expect some queueing when 20 people submit
  at once.
- Every script, command and exercise answer was tested on Boole in October
  2026. If the software modules change, update the `module load` lines in
  `examples/` and the guides.

Do not put credentials in this repository.
