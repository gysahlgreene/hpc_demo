# Boole HPC Platform Guide

## Contents

- [Introduction](#introduction)
- [Slurm Basics](#slurm-basics)
- [Conda / Miniforge](#conda--miniforge)
- [Accessing Object Storage from the Boole HPC Platform](#accessing-object-storage-from-the-boole-hpc-platform)
- [Running Docker Images with Apptainer on HPC](#running-docker-images-with-apptainer-on-hpc)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Introduction

The **Boole High Performance Computing (HPC) Platform** is operated by
**CloudCIX**. It provides compute resources for interactive data exploration,
batch processing, parallel workloads, GPU jobs, containers, and object storage
access.

Use this guide as a practical starting point for:

- Accessing Boole HPC.
- Running interactive and batch Slurm jobs.
- Running CPU, GPU, and MPI examples.
- Loading software modules and managing Python environments.
- Using object storage and Apptainer containers.

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

> **Important: Default Resource Allocation**
>
> The default resource allocation is **1 CPU and 1 GB of memory per node**.
> If your job needs more resources, request them in your `srun` command or
> `sbatch` script.

### Available Partitions

| Partition | Use |
| --- | --- |
| `cloud` | Virtualized cloud infrastructure. Suitable for smaller or flexible workloads. |
| `physical` | Dedicated bare-metal compute nodes. Use this for high-performance CPU jobs. |
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

Submit it:

```bash
sbatch examples/gpu/gpu_test.sh
```

### MPI Demonstration with Slurm

MPI is a standard for parallel computing. It allows multiple processes to
communicate while running across one or more compute nodes.

In this example, we will:

- Create a simple MPI application.
- Submit the application to Slurm.
- Run MPI tasks across multiple nodes.
- Verify that MPI ranks are distributed across the allocated nodes.

#### Prerequisites

Ensure the following are available:

- Python 3
- OpenMPI or another MPI implementation
- `mpi4py`

If `mpi4py` is not already installed, it can be installed with:

```bash
pip install --user mpi4py
```

#### Create the MPI Application

The runnable MPI application is `examples/mpi/mpi_hello.py`.

It:

- Retrieves the MPI rank, or process number.
- Retrieves the total number of MPI processes.
- Prints the hostname on which each rank is running.

#### Create the Slurm Job Script

The runnable Slurm script is `examples/mpi/mpi_demo.slurm`.

This configuration launches a total of **8 MPI ranks** across **2 nodes**.

#### Submit the MPI Job

Submit the job to Slurm:

```bash
cd examples/mpi
sbatch mpi_demo.slurm
```

#### Monitor the MPI Job

Check the job status:

```bash
squeue -u $USER
```

#### View the Results

Once the job has completed:

```bash
cat mpi-demo-*.out
```

Example output:

```text
Running MPI demo
Nodes allocated:
pcpt01
pcpt02

Hello from rank 0 of 8 on pcpt01
Hello from rank 1 of 8 on pcpt01
Hello from rank 2 of 8 on pcpt01
Hello from rank 3 of 8 on pcpt01
Hello from rank 4 of 8 on pcpt02
Hello from rank 5 of 8 on pcpt02
Hello from rank 6 of 8 on pcpt02
Hello from rank 7 of 8 on pcpt02
```

This demonstrates that:

- Slurm allocated two compute nodes.
- MPI launched eight parallel processes.
- The MPI ranks were distributed across both nodes.

#### Scaling the Example

To run across more nodes or launch more MPI processes, modify the Slurm
directives.

For example:

```bash
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=8
```

This configuration launches:

- 4 compute nodes
- 8 MPI ranks per node
- 32 total MPI processes

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

## Accessing Object Storage from the Boole HPC Platform

`s3cmd` is available to all users in the cluster for accessing S3-compatible
object storage services.

### Configure s3cmd

```bash
s3cmd --configure
```

When prompted, enter the following configuration details:

```text
Access Key: <your access key>
Secret Key: <your secret access key>
Default Region: <your default region>
S3 Endpoint: <your S3 endpoint>
DNS-style: no
Encryption password: [Press Enter]
Path to GPG program: [Press Enter]
Use HTTPS protocol: [Press Enter]
HTTP Proxy server name: [Press Enter]
Save settings? [y/N] y
```

### Example: CloudCIX Object Storage Configuration

Configuring `s3cmd` to use **CloudCIX Object Storage**:

```text
Access Key: <your access key>
Secret Key: <your secret access key>
Default Region: boole-zonegroup
S3 Endpoint: s3-boole.cloudcix.com
DNS-style: no
Encryption password: [Press Enter]
Path to GPG program: [Press Enter]
Use HTTPS protocol: [Press Enter]
HTTP Proxy server name: [Press Enter]
Save settings? [y/N] y
```

### Basic Usage Examples

The runnable command reference is `examples/object-storage/s3cmd_examples.sh`.

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
| Memory | `--mem=XG` | `--mem=16G` |
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
