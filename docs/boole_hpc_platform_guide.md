# Boole HPC Platform Guide

## Contents

- [Introduction](#introduction)
- [Slurm Basics](#slurm-basics)
- [Parallel Computing Guide](parallel_computing_guide.md) (separate page)
- [Conda / Miniforge](#conda--miniforge)
- [Running Docker Images with Apptainer on HPC](#running-docker-images-with-apptainer-on-hpc)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Introduction

The **Boole High Performance Computing (HPC) Platform** is operated by
**CloudCIX**. It provides compute resources for interactive data exploration,
batch processing, parallel workloads, GPU jobs, and containers.

Use this guide as a practical starting point for:

- Accessing Boole HPC.
- Running interactive and batch Slurm jobs.
- Running CPU, GPU, and MPI examples.
- Loading software modules and managing Python environments.
- Using Apptainer containers.

### Access Methods

The main access point is **Open OnDemand**:

- <https://hpc.cloudcix.com>

From Open OnDemand, you can upload data, launch jobs, and start interactive
applications. Available apps include:

| Application | Use |
| --- | --- |
| **Boole Shell Access** | Browser-based terminal access to the cluster. |
| **Remote Desktop** | Full remote desktop environment for GUI-based workflows. |
| **CloudCIX AI Lab** | AI and machine learning workspace. |
| **Jupyter Notebook** | Python, data analysis, and scientific computing. |
| **Jupyter + Spark** | Jupyter environment with Spark for distributed data processing. |
| **RStudio Server** | Browser-based R environment for statistics, analysis, and visualization. Bioconductor is pre-installed. |
| **VS Code Server** | Browser-based Visual Studio Code development environment. |
| **ParaView** | Visualization and analysis for scientific datasets. |
| **nf-core pipelines** | Bioinformatics workflow pipelines. |

You can also connect directly to the HPC system using SSH or transfer files via
`rsync` **from HEAnet and CloudCIX IP addresses only**.

### Getting Started

We recommend watching the short **Boole HPC Basics** video for an overview of
the platform:

- <https://youtu.be/h9gYU5s88NY?si=XL_WhoS5PJtkCS3P>

## Slurm Basics

**Slurm** is the workload manager used to run jobs on Boole HPC.

Use:

- `srun` for interactive jobs.
- `sbatch` for batch scripts.
- `squeue` and `scontrol` to monitor jobs.

Jobs are submitted to **partitions**. A partition is a queue for a particular
type of hardware or workload.

Slurm also records the directory where you ran `sbatch` as `SLURM_SUBMIT_DIR`.
The example scripts in this repository change into that directory before doing
work, so generated files and relative paths are easier to reason about.
Scripts that load software modules run under a login shell and reset the
inherited `module` function before selecting the Ubuntu 24.04 Spack module
tree.

> **Important: Default Resource Allocation**
>
> The default resource allocation is **1 CPU and 1 GB of memory per node**.
> If your job needs more resources, request them in your `srun` command or
> `sbatch` script.

### Available Partitions

| Partition | Use |
| --- | --- |
| `cloud` | Virtualized cloud infrastructure. Suitable for smaller or flexible workloads. |
| `physical` | Dedicated bare-metal compute nodes. Use this for high-performance CPU jobs. Each node has 8 cores shown as 16 hyperthread CPUs; see the [Parallel Computing Guide](parallel_computing_guide.md#hyperthreads-are-not-cores). |
| `physical-gpu` | Bare-metal nodes with GPUs, such as NVIDIA A100. Use this for GPU-accelerated workloads. |

### Available Resources

To see available RAM, CPU, and GPU resources per node, run:

```bash
scontrol show node
```

### Interactive Jobs with `srun`

The `srun` command launches an interactive session on a compute node. This is
useful for debugging, testing code, or short experimental runs.

Example: request 2 CPU cores and 4 GB of memory for 1 hour on the `cloud`
partition:

```bash
srun --partition=cloud --cpus-per-task=2 --mem=4G --time=01:00:00 --pty bash
```

Once the session starts, you will be inside a compute node shell where you can
run your program interactively.

### Batch CPU Job

The runnable version of this example is `examples/slurm/cpu_test.sh`.

Submit it:

```bash
sbatch examples/slurm/cpu_test.sh
```

Check the output:

```bash
cat cpu_test_<jobid>.out
```

### Batch GPU Job

For GPU workloads, request GPUs with `--gres=gpu:<N>`. Example with 1 GPU on
`physical-gpu`:

Interactive session:

```bash
srun --partition=physical-gpu --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=01:00:00 --pty bash
```

The runnable batch script is `examples/gpu/gpu_test.sh`.
It prints both `nvidia-smi` and `nvcc --version` from the allocated GPU node.

Submit it:

```bash
sbatch examples/gpu/gpu_test.sh
```

### Parallel Jobs and MPI

To use more than one core, or more than one node, see the
[Parallel Computing Guide](parallel_computing_guide.md). It covers:

- How cores, hyperthreads and nodes map to Slurm options on each partition.
- Using many cores on one node, and running many jobs with job arrays.
- MPI, scaling studies, hybrid jobs, and checking whether a job used what it
  asked for.

To check that MPI works for you, submit the demo:

```bash
cd examples/mpi
sbatch mpi_demo.slurm
cat mpi-demo-<jobid>.out
```

It starts 8 MPI ranks on 2 `physical` nodes with `srun`. Each rank prints its
node and the CPUs it is pinned to:

```text
Hello from rank 0 of 8 on h17u22.boole.cloudcix.com (cpus [1])
Hello from rank 1 of 8 on h17u22.boole.cloudcix.com (cpus [3])
...
Hello from rank 7 of 8 on h17u25.boole.cloudcix.com (cpus [6])
```

### Monitoring Jobs

List your jobs:

```bash
squeue -u $USER
```

Cancel a job:

```bash
scancel <jobid>
```

Show job details:

```bash
scontrol show job <jobid>
```

### Email Notifications

Slurm can send you an email when your job **starts**, **ends**, **fails**, or is
**cancelled**. To enable this, add the following options to your `srun` command
or `sbatch` script:

| Option | Description |
| --- | --- |
| `--mail-type=TYPE` | Event or events that trigger an email. |
| `--mail-user=EMAIL` | Email address to send notifications to. |

Valid `TYPE` values:

| Type | Meaning |
| --- | --- |
| `BEGIN` | Job starts running. |
| `END` | Job finishes successfully. |
| `FAIL` | Job fails. |
| `CANCEL` | Job is cancelled. |
| `ALL` | Shorthand for all events above. |

The runnable notification example is `examples/slurm/notify_test.sh`.

### Loading Software with Modules

Boole uses **Lmod** through Spack for managing software. Before running your
jobs, you may need to load specific compilers, libraries, or applications.

List available modules:

```bash
module avail
```

Search for a module by keyword:

```bash
module spider gcc
```

Load a module:

```bash
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
module load gcc-runtime/13.2.0
```

Show loaded modules:

```bash
module list
```

## Conda / Miniforge

For users who want to manage Python environments and packages independently of
the cluster-wide software modules, we recommend using **Miniforge** or
**Conda** in your home directory. This allows you to create isolated
environments and install Python packages without affecting other users.

### Installing Miniforge

Download the latest Miniforge installer:

```bash
cd $HOME
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
```

Run the installer:

```bash
bash Miniforge3-Linux-x86_64.sh
```

Follow the prompts:

- Accept the license.
- Install into your home directory. The default path is `$HOME/miniforge3`.
- Allow the installer to initialize Conda by modifying your shell startup file.

Activate Conda:

```bash
source $HOME/miniforge3/bin/activate
```

You can also add the initialization to your shell automatically:

```bash
conda init
```

### Creating and Managing Environments

Create a new environment:

```bash
conda create --name my_env python=3.11
```

Activate the environment:

```bash
conda activate my_env
```

Deactivate the environment:

```bash
conda deactivate
```

List all environments:

```bash
conda env list
```

### Installing Packages

Within an activated environment, you can install Python packages independently:

```bash
conda install numpy scipy matplotlib
```

Or use `pip` inside the environment:

```bash
pip install pandas seaborn
```

Update packages:

```bash
conda update numpy
```

Remove packages:

```bash
conda remove matplotlib
```

Delete an environment:

```bash
conda env remove --name my_env
```

### Best Practices

- Always **activate your environment** before running Python programs.
- Keep separate environments for different projects to avoid package conflicts.
- Avoid installing packages directly into the base Conda environment; use named
  environments instead.

## Running Docker Images with Apptainer on HPC

This guide shows how to pull and run a Docker image using **Apptainer** in an
HPC environment managed by **Slurm**.

Apptainer is the container platform available on Boole HPC. It allows you to
package applications, dependencies, and environments into portable **container
images** that can run across all partitions: `cloud`, `physical`, and
`physical-gpu`.

### Step 1: Request an Interactive Slurm Session

Start an interactive session using `srun`:

```bash
srun --partition=cloud --cpus-per-task=2 --mem=4G --time=01:00:00 --pty bash
```

### Step 2: Pull the Docker Image

Pull a Docker image and convert it to a **SIF** file:

```bash
apptainer pull docker://hello-world
```

This creates a file named `hello-world_latest.sif` in your current directory.

### Step 3: Run the Container

Run the container with:

```bash
apptainer run hello-world_latest.sif
```

Expected output:

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

### Step 4: Optional: Inspect or Enter the Container

Inspect metadata:

```bash
apptainer inspect hello-world_latest.sif
```

Run a command inside the container:

```bash
apptainer exec hello-world_latest.sif ls /
```

Interactive shell inside the container:

```bash
apptainer shell hello-world_latest.sif
```

The runnable Slurm example is `examples/containers/apptainer_hello.slurm`.

## Quick Reference

### Common Slurm Commands

| Command | Description |
| --- | --- |
| `squeue -u $USER` | Show your running or pending jobs. |
| `sbatch script.sh` | Submit a batch job script. |
| `scancel <jobid>` | Cancel a specific job. |
| `sinfo` | Show partition and node status. |
| `scontrol show job <jobid>` | Show detailed job information. |
| `sacct -j <jobid>` | Show job accounting information. |

### Common Resource Requests

| Resource Type | Slurm Option | Example |
| --- | --- | --- |
| CPU cores | `--cpus-per-task=N` | `--cpus-per-task=4` |
| Nodes | `--nodes=N` | `--nodes=2` |
| Tasks (MPI ranks) | `--ntasks=N` or `--ntasks-per-node=N` | `--ntasks-per-node=8` |
| Whole cores only (`physical`) | `--hint=nomultithread` | `--hint=nomultithread` |
| Memory per node | `--mem=XG` | `--mem=16G` |
| Memory per CPU | `--mem-per-cpu=XG` | `--mem-per-cpu=2G` |
| Job array | `--array=RANGE` | `--array=1-100%10` |
| GPUs | `--gres=gpu:N` | `--gres=gpu:2` |
| Time limit | `--time=HH:MM:SS` | `--time=02:30:00` |
| Partition | `--partition=NAME` | `--partition=physical-gpu` |

## Troubleshooting

### Common Issues and Solutions

**Job stuck in pending state**

- Check partition availability with `sinfo`.
- Reduce resource requirements such as CPUs, memory, or time.
- Consider using a different partition.

**Out of memory errors**

- Increase the `--mem` parameter.
- Check actual memory usage with
  `sacct -j <jobid> --format=JobID,MaxRSS`.

**Module not found**

- Use `module spider <software>` to search.
- Check if the module name includes a version number.
- Try `module avail` to see all available modules.

**Container permission errors**

- Ensure the SIF file has correct permissions.
- Try rebuilding the container image.
- Check if the container requires specific bind mounts.

### Getting Help

- **System Status**: Check <https://hpc.cloudcix.com> for announcements.
- **Documentation**: This guide and Open OnDemand help pages.
- **Support**: Contact CloudCIX support at support@cloudcix.com.

## Additional Resources

- **Slurm Official Documentation**: <https://slurm.schedmd.com/documentation.html>
- **Apptainer Documentation**: <https://apptainer.org/docs/>
- **Conda User Guide**: <https://docs.conda.io/projects/conda/en/latest/user-guide/>
