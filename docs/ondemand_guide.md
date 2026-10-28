# Interactive Apps in Open OnDemand: Ask for What You Use

[Open OnDemand](https://hpc.cloudcix.com) can start Jupyter, VS Code Server,
RStudio, a Remote Desktop and other apps on Boole's compute nodes. They are
convenient, and also the easiest way to waste the cluster without noticing.

## A Session Is a Slurm Job

When you click **Launch**, Open OnDemand submits a Slurm job for you. The
cores, memory and GPU you choose are **reserved for you, and nobody else can
use them, until the session ends**, whether you are typing or not.

The launch form's fields map directly to the job options in the other guides:

| Form field | Slurm option | Notes |
| --- | --- | --- |
| Partition (Cloud Compute / Physical Compute / GPU Compute) | `--partition` | Cloud Compute is the default for most apps. |
| Number of CPU cores / Number cores | `--cpus-per-task` | On Physical, these are [hyperthreads](parallel_computing_guide.md#hyperthreads-are-not-cores). |
| RAM (in GB) / Memory (GB) | `--mem` | |
| GPUs | `--gres=gpu:1` | GPU Compute only. There are only 2 GPUs in the whole cluster. |
| Maximum job duration (hours) | `--time` | 1 to 24 hours. The session is ended when it runs out. |

While a session runs, it appears in `squeue -u $USER` with a name starting
`sys/dash` (in full, `sys/dashboard/sys/<app>`).

## What We See on Boole

In 30 days of Slurm records, most of the use of the `cloud` partition was VS
Code Server sessions that asked for **8 cores and 16 GB, the most the form
allows on Cloud Compute**. Together they used **less than 1%** of the CPU time they
reserved. Each `cloud` node has 8 cores, so two such sessions fill the whole
partition, and everyone else's jobs wait.

An editor needs one core. The cores were reserved "just in case" and then sat
idle.

## What to Ask For

| You want to... | App | Start with |
| --- | --- | --- |
| Edit code, look at files, submit jobs | VS Code Server | Cloud Compute, 1 core, 4 GB (the default) |
| Explore data or prototype in a notebook | Jupyter | Cloud Compute, 1-2 cores, 4-8 GB |
| Work in R | RStudio Server | Cloud Compute, 1-2 cores, 4-8 GB |
| Use graphical software | Remote Desktop | Cloud Compute, 1-2 cores, 4-8 GB |
| Try a model on a GPU interactively | Jupyter or CloudCIX AI Lab | GPU Compute, 1 GPU, 4-8 cores, 32 GB |

Then adjust from what you see:

- **Ask for more cores only if your code uses them.** A notebook running
  ordinary Python uses one core however many you request. See
  [Many Cores on One Node](parallel_computing_guide.md#4-many-cores-on-one-node).
- **Ask for memory you will use.** If your data is 2 GB in memory, ask for
  about 4-6 GB, not 64.
- **Ask for the hours you need today.** A shorter session also starts sooner
  when the cluster is busy.

## When You're Done, Delete the Session

**Closing the browser tab does not end the session.** The job keeps holding
its cores, memory and GPU until its time runs out. To end it:

- In Open OnDemand, open **My Interactive Sessions** and click **Delete** on
  the session, or
- from a terminal, `squeue -u $USER` to find its job ID, then
  `scancel <jobid>`.

## Big Computations: Submit a Batch Job Instead

Interactive apps are for interactive work. If something will run for more
than a few minutes, or needs many cores or a GPU for a long time:

1. Put it in a script (start from one of the [templates](../templates/README.md)).
2. Submit it with `sbatch` from the session's terminal.
3. Delete the interactive session while the batch job runs (a running
   session can't be resized; relaunch a small one if you need it).

The batch job uses exactly the resources it needs, for exactly as long as it
runs, and keeps going when you log out.

## Check What a Session Really Used

After deleting a session, look it up like any other job:

```bash
sacct -u $USER -S today --name=sys/dashboard/sys/Jupyter \
      --format=JobID,JobName%30,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State
```

Use `bc_osc_codeserver` instead of `Jupyter` for VS Code Server, or leave out
`--name` to see all your jobs. CPU efficiency is `TotalCPU / CPUTime`, as in
[Was My Job Efficient?](parallel_computing_guide.md#9-was-my-job-efficient)
For an interactive session this is always low, because you spend time
reading and typing. That is why a session should ask for as little as
possible.
