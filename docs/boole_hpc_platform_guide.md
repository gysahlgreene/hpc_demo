# Boole HPC Platform Guide

## Contents

- [Introduction](#introduction)
- [Slurm Basics](#slurm-basics)
  - [Your First Batch Job](#your-first-batch-job)
- [Parallel Computing Guide](parallel_computing_guide.md) (separate page)
- [OpenFOAM Guide](openfoam_guide.md) (separate page)
- [GPU Guide](gpu_guide.md) (separate page)
- [Interactive Apps in Open OnDemand](ondemand_guide.md) (separate page)
- [Loading Software with Modules](#loading-software-with-modules)
- [Conda / Miniforge](#conda--miniforge) (optional)
- [Running Docker Images with Apptainer](#running-docker-images-with-apptainer) (optional)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Introduction

The **Boole High Performance Computing (HPC) Platform** is operated by
**CloudCIX**. It provides compute resources for interactive data exploration,
batch processing, parallel workloads, GPU jobs, and containers.

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

Each interactive app runs as a Slurm job that holds the cores, memory and GPU
you choose until you end it. See
[Interactive Apps in Open OnDemand](ondemand_guide.md) for what to request.

You can also connect directly to the HPC system using SSH or transfer files via
`rsync` **from HEAnet and CloudCIX IP addresses only**.

We recommend watching the short **Boole HPC Basics** video for an overview of
the platform:

- <https://youtu.be/h9gYU5s88NY?si=XL_WhoS5PJtkCS3P>

## Slurm Basics

### Login Node and Compute Nodes

When you open a terminal on Boole you are on the **login node**. Many people
share it, and it is only for light work: editing files, moving data, and
submitting jobs. **Do not run heavy computations on the login node.**

The real work runs on **compute nodes**. You get time on them by asking
**Slurm**, the scheduler. Slurm queues your request until the CPUs, memory and
time you asked for are free, then runs your work there. Your home directory is
the same on every node, so files you create on the login node are visible from
your jobs, and the other way round.

There are two ways to run work on compute nodes:

- **Interactive job** (`srun ... --pty bash`): you get a shell on a compute
  node and type commands yourself. Good for testing and debugging.
- **Batch job** (`sbatch script.sh`): you write the commands in a script, submit
  it, and Slurm runs it when resources are free, even after you log out. This
  is how most real work runs.

### Partitions

Jobs are submitted to **partitions**. A partition is a queue for one type of
hardware:

| Partition | Nodes | Each node | Max job time | Use |
| --- | --- | --- | --- | --- |
| `cloud` (default) | 2 | 8 cores, 22 GB RAM | 14 days | Smaller or flexible jobs on virtual machines. |
| `physical` | 4 | 8 cores (shown as 16 hyperthreads), 256 GB RAM | 10 days | High-performance CPU jobs on dedicated hardware. See [Hyperthreads Are Not Cores](parallel_computing_guide.md#hyperthreads-are-not-cores). |
| `physical-gpu` | 2 | 64 cores, 480 GB RAM, 1 NVIDIA A100 GPU | 7 days | GPU-accelerated work. |

See the live state with `sinfo`, and each node's details with
`scontrol show node`.

> **Important: Default Resource Allocation**
>
> If you don't ask for more, a job gets **1 CPU and 1 GB of memory**. Request
> what you need with `--cpus-per-task`, `--mem` and `--time` in your `srun`
> command or `sbatch` script. Ask for what you will use, not the maximum: a
> smaller request starts sooner and leaves room for others.

### Interactive Jobs with `srun`

Request 1 CPU and 1 GB of memory for 15 minutes on the `cloud` partition:

```bash
srun --partition=cloud --cpus-per-task=1 --mem=1G --time=00:15:00 --pty bash
```

When the job starts, your prompt changes to show a compute node name, such as
`cpt2`. Run your commands, then type `exit` to end the job and return to the
login node. The job also ends when its time runs out.

### Your First Batch Job

A batch script is a shell script with `#SBATCH` lines at the top. Slurm reads
those lines as options; bash treats them as comments. Comments after an
`#SBATCH` option are fine, but never put one on the `#!` first line: the
script then fails with `bash: invalid option`. This is
`examples/slurm/cpu_test.sh`, with explanations:

```bash
#!/bin/bash -l
# The line above runs this script with bash, as a login shell (needed for modules).
#SBATCH --job-name=cpu_test           # name shown in squeue
#SBATCH --output=cpu_test_%j.out      # output file; %j becomes the job ID
#SBATCH --partition=cloud             # which partition to run on
#SBATCH --cpus-per-task=2             # CPUs (on cloud, 1 CPU = 1 core)
#SBATCH --mem=2G                      # memory for the job
#SBATCH --time=00:10:00               # time limit (HH:MM:SS); the job is killed after this

set -euo pipefail                     # stop at the first error

SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"   # the directory you ran sbatch from
cd "$SUBMIT_DIR"

# --- Boole module setup: copy these lines as they are into your own scripts ---
unset -f module ml 2>/dev/null || true
if [[ -r /etc/profile.d/lmod.sh ]]; then
  source /etc/profile.d/lmod.sh
elif [[ -r /usr/share/lmod/lmod/init/bash ]]; then
  source /usr/share/lmod/lmod/init/bash
fi
module purge
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
# --- end of module setup ---

module load python/3.11.9             # the software this job needs

echo "Running on host: $(hostname)"
...                                   # your commands
```

The module lines are explained in
[Loading Software with Modules](#loading-software-with-modules).

From the repository folder, submit the script:

```bash
cd ~/hpc_demo
sbatch examples/slurm/cpu_test.sh
```

Slurm replies with the **job ID**:

```text
Submitted batch job 19086
```

Use that number wherever these guides write `<jobid>`, without the `< >`.
Check on the job:

```bash
squeue -u "$USER"
```

```text
  JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
  19086     cloud cpu_test     eoin PD       0:00      1 (Priority)
```

The `ST` column is the state: `PD` means pending (waiting for resources; the
reason is in the last column), and `R` means running. **When the job finishes
it disappears from `squeue`.** This job takes about a second, so it is often
gone by the time you look. Then read its output file, which appears in the
directory you submitted from:

```bash
cat cpu_test_19086.out
```

```text
Running on host: cpt2.boole.cloudcix.com
Job ID: 19086
Submit directory: /home/eoin/hpc_demo
Allocated CPUs: 2
...
Hello from Slurm on cpt2.boole.cloudcix.com.
This task can use 2 CPU core(s).
```

If you lose track of a job ID, `ls -t *.out | head` lists the newest output
files, and `sacct -u "$USER" -S today` lists your jobs from today.

Options given to `sbatch` on the command line override the `#SBATCH` lines in
the script, so you can try different requests without editing it:

```bash
sbatch --cpus-per-task=4 examples/slurm/cpu_test.sh
```

### Monitoring and Cancelling Jobs

| Command | What it does |
| --- | --- |
| `squeue -u $USER` | Your pending and running jobs. |
| `scancel <jobid>` | Cancel a job. |
| `scontrol show job <jobid>` | Full details of a pending or running job. |
| `sacct -j <jobid>` | Record of a finished job (state, run time, memory). |

`sacct` shows several lines per job: one for the whole job, then one per
**step**. `.batch` is your script, `.extern` is Slurm's own bookkeeping, and
each `srun` inside the script adds a numbered step (`.0`, `.1`, ...). Memory
use (`MaxRSS`) appears on the step lines, not the first line.

### Batch GPU Job

Request GPUs with `--gres=gpu:<N>`. Each `physical-gpu` node has **one** GPU,
so ask for `--gres=gpu:1`. Interactive session:

```bash
srun --partition=physical-gpu --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=00:15:00 --pty bash
```

The batch example `examples/gpu/gpu_test.sh` prints `nvidia-smi` (the GPU and
its driver) and `nvcc --version` (the CUDA compiler) from the GPU node:

```bash
sbatch examples/gpu/gpu_test.sh
cat gpu_test_<jobid>.out
```

```text
|   0  NVIDIA A100-SXM4-80GB          Off |   00000000:08:00.0 Off |                    0 |
...
Cuda compilation tools, release 12.0, V12.0.140
```

To choose how many CPUs and how much memory to request with a GPU, and to
check that the GPU is kept busy, see the [GPU Guide](gpu_guide.md).

### Parallel Jobs and MPI

To use more than one core, or more than one node, see the
[Parallel Computing Guide](parallel_computing_guide.md). It covers:

- How cores, hyperthreads and nodes map to Slurm options on each partition.
- Using many cores on one node, and running many jobs with job arrays.
- MPI, scaling studies, hybrid jobs, and checking whether a job used what it
  asked for.

### Email Notifications

Slurm can email you when a job **starts**, **ends**, **fails**, or is
**cancelled**. Add these options to your `srun` command or `sbatch` script:

| Option | Description |
| --- | --- |
| `--mail-type=TYPE` | Event or events that trigger an email: `BEGIN`, `END`, `FAIL`, `CANCEL`, or `ALL`. Combine with commas, e.g. `END,FAIL`. |
| `--mail-user=EMAIL` | Email address to send notifications to. |

`examples/slurm/notify_test.sh` waits a minute and emails you when it ends.
Give your own address on the command line:

```bash
sbatch --mail-user=your.name@example.org examples/slurm/notify_test.sh
```

## Loading Software with Modules

Software on Boole is provided as **modules**, managed by **Lmod**. Nothing is
available until you load it: `module load python/3.11.9` puts that Python on
your `PATH`, and `module purge` unloads everything.

Boole has two software trees, one built for Ubuntu 22.04 and one for Ubuntu
24.04. The compute nodes run Ubuntu 24.04, but the 22.04 tree is listed first
by default. **Run these two lines before loading modules**, on the login node
and in every job script:

```bash
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
```

Then:

```bash
module avail                # everything you can load
module spider gcc           # search by name, and list versions
module load python/3.11.9   # load a module
module list                 # what is loaded now
```

The workshop examples use `python/3.11.9`, `openmpi/5.0.5`, `py-mpi4py/4.0.1`
and `py-numpy/2.1.2`.

**The GPU nodes (`physical-gpu`) don't have the `module` command.** GPU jobs
use a Python environment in your home directory instead; see the
[GPU Guide](gpu_guide.md). Load `python` before Python packages such as
`py-numpy`.

In batch scripts, the lines before `module purge` in the examples (`unset -f`
and `source ... lmod`) make the `module` command work reliably inside jobs.
Copy the whole block as it is.

## Conda / Miniforge

*Optional; not needed for the workshop exercises.*

To manage your own Python packages independently of the cluster modules, use
**Miniforge** (a free Conda installer) in your home directory. You can create
isolated environments and install packages without affecting other users.

### Installing Miniforge

```bash
cd $HOME
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
```

Follow the prompts: accept the license and install into the default
`$HOME/miniforge3`. If asked whether to initialize Conda, answering `yes`
edits your `~/.bashrc` so Conda's `base` environment is active in every new
shell. Then activate Conda in your current shell:

```bash
source $HOME/miniforge3/bin/activate
```

### Creating and Managing Environments

```bash
conda create --name my_env python=3.11   # create an environment
conda activate my_env                    # use it
conda deactivate                         # leave it
conda env list                           # list environments
conda env remove --name my_env           # delete one
```

### Installing Packages

Within an activated environment:

```bash
conda install numpy scipy matplotlib     # from conda-forge
pip install pandas seaborn               # or with pip
conda update numpy
conda remove matplotlib
```

### Best Practices

- **Activate your environment** in the job script before running Python
  (`source $HOME/miniforge3/bin/activate my_env`).
- Use one environment per project.
- Don't install packages into `base`; use named environments.
- Don't mix a Conda environment and the cluster's `python` modules in the same
  job. Use one or the other.

## Running Docker Images with Apptainer

*Optional.*

**Apptainer** runs containers on HPC. It can turn a Docker image into a
single **SIF** file and run it on any partition, without needing Docker or
administrator rights.

Start an interactive job, then pull a Docker image:

```bash
srun --partition=cloud --cpus-per-task=1 --mem=2G --time=00:15:00 --pty bash
apptainer pull docker://hello-world
```

This creates `hello-world_latest.sif` in the current directory. Run it:

```bash
apptainer run hello-world_latest.sif
```

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

Other useful commands:

```bash
apptainer inspect hello-world_latest.sif   # metadata
apptainer exec hello-world_latest.sif ls / # run one command inside
apptainer shell hello-world_latest.sif     # a shell inside the container
```

Type `exit` to leave the container shell, and again to end the job.

The batch version is `examples/containers/apptainer_hello.slurm`. It pulls the
image the first time and prints `WARNING: passwd file doesn't exist in
container`; that warning is harmless.

## Quick Reference

### Common Slurm Commands

| Command | Description |
| --- | --- |
| `sinfo` | Show partition and node status. |
| `squeue -u $USER` | Show your running or pending jobs. |
| `sbatch script.sh` | Submit a batch job script. |
| `scancel <jobid>` | Cancel a specific job. |
| `scontrol show job <jobid>` | Show detailed job information. |
| `sacct -j <jobid>` | Show job accounting information. |

### Common Resource Requests

| Resource Type | Slurm Option | Example |
| --- | --- | --- |
| Partition | `--partition=NAME` | `--partition=physical` |
| Time limit | `--time=HH:MM:SS` | `--time=02:30:00` |
| CPUs per task (cores on `cloud`, hyperthreads on `physical`) | `--cpus-per-task=N` | `--cpus-per-task=4` |
| Nodes | `--nodes=N` | `--nodes=2` |
| Tasks (MPI ranks) | `--ntasks=N` or `--ntasks-per-node=N` | `--ntasks-per-node=8` |
| Whole cores only (`physical`) | `--hint=nomultithread` | `--hint=nomultithread` |
| Memory per node | `--mem=XG` | `--mem=16G` |
| Memory per CPU | `--mem-per-cpu=XG` | `--mem-per-cpu=2G` |
| GPUs | `--gres=gpu:N` | `--gres=gpu:1` |
| Job array | `--array=RANGE` | `--array=1-100%10` |

## Troubleshooting

**`sbatch: error: Unable to open file`**

- You are in the wrong directory. `cd ~/hpc_demo` and use the path shown in
  the instructions.

**`cat: ...out: No such file or directory`**

- The job hasn't started yet (check `squeue -u $USER`), or you replaced
  `<jobid>` wrongly. `ls -t *.out | head` shows the newest output files.

**Job stuck in pending state (`PD`)**

- The last column of `squeue` gives the reason. `Resources` and `Priority`
  mean it is waiting its turn.
- Check how busy the partition is with `sinfo`.
- Reduce the CPUs, memory or time you request, or use a different partition.

**Out of memory errors**

- Increase `--mem`.
- Check what a finished job really used with
  `sacct -j <jobid> --format=JobID,MaxRSS`.

**Module not found**

- Did you run the `module unuse` / `module use` lines first?
- Use `module spider <software>` to search, and include the version number.

**Container permission errors**

- Ensure the SIF file has correct permissions.
- Try pulling the image again.
- Check whether the container needs specific bind mounts.

### Getting Help

- **System Status**: Check <https://hpc.cloudcix.com> for announcements.
- **Documentation**: This guide and Open OnDemand help pages.
- **Support**: Contact CloudCIX support at support@cloudcix.com.

## Additional Resources

- **Slurm Official Documentation**: <https://slurm.schedmd.com/documentation.html>
- **Apptainer Documentation**: <https://apptainer.org/docs/>
- **Conda User Guide**: <https://docs.conda.io/projects/conda/en/latest/user-guide/>
