# Getting the Most from Boole's GPUs

Boole has **two** GPU nodes, `gpu0` and `gpu1`, in the `physical-gpu`
partition. Each has:

- **one** NVIDIA A100 GPU (80 GB),
- 64 CPU cores,
- 480 GB of RAM.

This guide shows how to size a GPU job so the GPU stays busy, without holding
resources it doesn't need. All the numbers come from real runs on Boole.

## Why Sizing Matters Here

Each GPU node has one GPU, but also the cluster's biggest CPUs and memory.
`physical-gpu` accepts CPU-only jobs too, so whatever a GPU job doesn't
reserve can run someone else's work.

In 30 days of Slurm records, jobs on the GPU nodes reserved **48,000
CPU-hours (one core for one hour each) but used only 6% of them**. Most of that came from jobs asking for
30-60 cores and 200-400 GB alongside a single GPU. Those cores and memory sat
idle, and nobody else could use them.

## Set Up PyTorch (Once)

There is no PyTorch module on Boole, and **the GPU nodes have no `module`
command**. Instead, create a Python **virtual environment** ("venv"): a
folder in your home directory holding its own Python packages, which you
switch on with `source <folder>/bin/activate`. Run this once, on the login
node:

```bash
cd ~/hpc_demo
bash examples/gpu/setup_torch_env.sh
```

```text
Creating /home/<you>/venvs/hpc-torch and installing PyTorch. This takes a few minutes.
Done in 162 s, using 5.4G in /home/<you>/venvs/hpc-torch
PyTorch 2.14.1+cu130 built for CUDA 13.0
```

GPU job scripts then use it with
`source "$HOME/venvs/hpc-torch/bin/activate"`. See
[templates/gpu.slurm](../templates/gpu.slurm). PyTorch brings its own CUDA
libraries (`cu130` = CUDA 13.0), so the separate `nvcc` 12.0 on the GPU
nodes doesn't matter for it.

## How Many CPUs Does a GPU Job Need?

Training needs data. In PyTorch, a `DataLoader` prepares each batch of
images (reading, decoding, augmenting) on the CPU, using `num_workers`
**data-loader workers**: separate processes, one per CPU core. With
`num_workers=0` the main Python process prepares every batch itself, between
training steps. If the CPU can't keep up, the GPU waits.

`examples/gpu/gpu_dataloader.py` trains a small network on images that each
take a little CPU time to prepare, like real image data. It times the same
training with 0, 1, 2, 4, 8 and 15 workers, and samples how busy the GPU is:

```bash
sbatch examples/gpu/gpu_dataloader.slurm
cat gpu-dataloader-<jobid>.out
```

```text
GPU: NVIDIA A100-SXM4-80GB
CPU cores this job may use: 16
(trimmed: each row is followed by a RESULT line)

workers  images/s  GPU busy
      0      2376       15%
      1      2428       15%
      2      4994       30%
      4      9976       56%
      8     15814       81%
     15     15191       82%
```

What this shows:

- **With 0 or 1 workers, the GPU was idle 85% of the time**, waiting for the
  CPU. Most GPU jobs that "run slowly" look like this.
- **8 workers made training 6.7 times faster**, and the GPU 81% busy.
- **15 workers were no faster than 8.** Past this point the GPU is the limit,
  and extra CPUs only sit idle.

So for this job, ask for **9 CPUs** (8 workers plus the main Python process),
not 16, and certainly not 64. With only 4 CPUs (`--cpus-per-task=4`, 3
workers) it managed 7,276 images/s, less than half the speed. Too few CPUs
wastes the GPU; too many wastes the CPUs.

Your own code will have a different sweet spot. Find it the same way: run a
short training with a few `num_workers` values and stop adding workers when
images/s stops rising. In PyTorch:

```python
import os
from torch.utils.data import DataLoader

workers = len(os.sched_getaffinity(0)) - 1   # CPUs given to this job, minus the main process
loader = DataLoader(dataset, batch_size=256, num_workers=workers)
```

## How Much Memory?

The 16-CPU run above used at most 2.4 GB of RAM (`MaxRSS`, the peak memory
`sacct` reports; see below), so
`--mem=8G` is plenty. The GPU's own 80 GB of memory is separate and doesn't
need requesting: you get all of it with `--gres=gpu:1`.

## Is My GPU Busy?

**During a job**, look at the GPU from the login node:

```bash
srun --jobid=<jobid> --overlap nvidia-smi
```

`GPU-Util` is the share of time the GPU was running work. Below about 50%
often means it is waiting for data: add data-loader workers (and CPUs), or
increase `batch_size` in your code.

**For the whole job**, have it log GPU use as it runs. `gpu_dataloader.slurm`
and [templates/gpu.slurm](../templates/gpu.slurm) start this in the
background:

```bash
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used --format=csv -l 30 \
  > "gpu-usage-${SLURM_JOB_ID}.csv" &
```

Read it afterwards as a table with `column -s, -t < gpu-usage-<jobid>.csv`.

**After a job**, check CPU and memory as for any job:

```bash
sacct -j <jobid> --format=JobID,JobName,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State,NodeList
```

```text
JobID           JobName  AllocCPUS    Elapsed    CPUTime   TotalCPU     MaxRSS      State        NodeList
------------ ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------------
19162        gpu-datal+         16   00:01:04   00:17:04  03:16.871             COMPLETED            gpu0
19162.batch       batch         16   00:01:04   00:17:04  03:16.866   2371960K  COMPLETED            gpu0
```

`TotalCPU / CPUTime` is only 19% here, because the sweep spends part of its
time on 0-4 workers, and 15 workers were more than needed.

## Interactive GPU Sessions

Jupyter and CloudCIX AI Lab can start on a GPU in
[Open OnDemand](ondemand_guide.md). There are only two GPUs, so:

- ask for 4-8 CPU cores and 32 GB, not the maximum,
- **delete the session when you stop working**, since a closed browser tab
  keeps holding the GPU,
- move long training runs into a batch job.

## Checklist

- [ ] `--gres=gpu:1`. There is one GPU per node, so never more.
- [ ] `--cpus-per-task` = data-loader workers + 1, found with a short sweep.
- [ ] `--mem` = `MaxRSS` from a test run plus a margin.
- [ ] `num_workers` in your code is the CPUs you were given, minus one.
- [ ] Checked that the GPU is busy (`nvidia-smi`, or the usage log).
- [ ] Interactive GPU sessions deleted when finished.
