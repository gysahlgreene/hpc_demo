# Parallel Computing on Boole: Cores, Nodes and MPI

A job only runs faster on HPC if it uses the hardware it asks for. This guide
shows how to request the right shape of job for your work, and how to check
that you are getting your money's worth from it. Every example output below
comes from a real run on Boole.

## Contents

- [1. Know Your Hardware](#1-know-your-hardware)
- [2. The Slurm Options That Shape a Job](#2-the-slurm-options-that-shape-a-job)
- [3. Pick the Right Pattern](#3-pick-the-right-pattern)
- [4. Many Cores on One Node](#4-many-cores-on-one-node)
- [5. Many Independent Jobs: Job Arrays](#5-many-independent-jobs-job-arrays)
- [6. Many Nodes: MPI](#6-many-nodes-mpi)
- [7. Scaling: Does More Cores Mean Faster?](#7-scaling-does-more-cores-mean-faster)
- [8. Hybrid MPI and Threads](#8-hybrid-mpi-and-threads)
- [9. Was My Job Efficient?](#9-was-my-job-efficient)
- [10. Checklist](#10-checklist)

## 1. Know Your Hardware

| Partition | Nodes | Per node | Slurm "CPU" means |
| --- | --- | --- | --- |
| `cloud` | 2 (`cpt2-3`) | 8 cores, 22 GB RAM | a core |
| `physical` | 4 (`h17u17,22,24,25`) | 2 sockets x 4 cores x 2 hyperthreads = 16 CPUs, 256 GB RAM | **a hyperthread** |
| `physical-gpu` | 2 (`gpu0-1`) | 64 cores, 480 GB RAM, 1 NVIDIA A100 | a core |

Check this yourself with `sinfo` and `scontrol show node`: multiply `Sockets`
by `CoresPerSocket` to get the real cores, and look at `ThreadsPerCore`.

### Hyperthreads Are Not Cores

A `physical` node reports 16 CPUs but has **8 physical cores**. Each core runs
two hyperthreads, and the two share that core's arithmetic units. For
number-crunching code a second hyperthread adds almost nothing. On these
nodes, CPU `N` and CPU `N+8` are the two hyperthreads of the same core
(`lscpu -e` shows the mapping).

Slurm hands out hyperthreads on `physical`, so by default a request for 8 CPUs
gives you **4 cores** (both hyperthreads of each). Add `--hint=nomultithread`
to get whole cores, one task or thread per core:

```bash
#SBATCH --partition=physical
#SBATCH --cpus-per-task=8
#SBATCH --hint=nomultithread   # 8 real cores, not 4 cores x 2 hyperthreads
```

Section 4 shows the difference: the same program ran twice as fast with the
hint. All the `physical` examples in this repository use it. On `cloud` and
`physical-gpu` a CPU is already a core, so the hint makes no difference there.

## 2. The Slurm Options That Shape a Job

| Option | Meaning |
| --- | --- |
| `--nodes=N` | Number of machines. |
| `--ntasks=N` | Number of processes `srun` starts in total. For MPI, one task = one rank. |
| `--ntasks-per-node=N` | Tasks on each node (use with `--nodes`). |
| `--cpus-per-task=N` | CPUs each task may use for its own threads or worker processes. |
| `--mem=XG` | Memory **per node**. The default is only 1 GB per node. |
| `--mem-per-cpu=XG` | Memory per allocated CPU, so memory grows with the CPU count. |
| `--hint=nomultithread` | Whole cores only (matters on `physical`). |
| `--array=1-100` | Submit many copies of the script as one job array. |

For example, `--nodes=2 --ntasks-per-node=2 --cpus-per-task=4` asks for:

```text
 node 1                          node 2
+-----------------------------+  +-----------------------------+
| task 0       task 1         |  | task 2       task 3         |
| [c][c][c][c] [c][c][c][c]   |  | [c][c][c][c] [c][c][c][c]   |
+-----------------------------+  +-----------------------------+
  4 tasks (MPI ranks) x 4 CPUs each = 16 CPUs
```

Tasks are separate processes, each with its own memory. They can be on
different nodes, so they can only cooperate by sending messages (MPI). CPUs
within one task share memory, so threads or worker processes there can share
data directly.

## 3. Pick the Right Pattern

| Your work looks like | Pattern | Request | Example |
| --- | --- | --- | --- |
| Many independent runs: parameter sweeps, one file at a time | Job array | `--array=1-100`, small jobs | `examples/multicore/array_sweep.slurm` |
| One program using threads or worker processes (`multiprocessing`, joblib, OpenMP, R `parallel`) | One node, many cores | `--nodes=1 --ntasks=1 --cpus-per-task=N` | `examples/multicore/pool_pi.slurm` |
| An MPI program | Many nodes | `--nodes=M --ntasks-per-node=K` | `examples/mpi/mpi_scaling.slurm` |
| An MPI program whose ranks also use threads | Hybrid | `--ntasks-per-node=K --cpus-per-task=T` | `examples/mpi/mpi_hybrid.slurm` |

Two rules:

- **Asking for more cores never makes code parallel.** Slurm reserves the cores;
  your program has to use them. A plain Python, R or MATLAB script uses one
  core however many you request. Section 9 shows how to check.
- **If the work splits into independent pieces, use a job array.** No code
  changes, no communication, and the scheduler can fit many small jobs into
  gaps that a single big job would wait hours for.

All the examples compute pi as the area under `4 / (1 + x^2)` between 0 and
1, approximated with `n` thin rectangles, so you can compare the parallel
patterns on the same problem. Each prints its error so you can see it is
still right.

## 4. Many Cores on One Node

`examples/multicore/pool_pi.py` splits the rectangles between worker
processes with Python's `multiprocessing.Pool`. `pool_pi.slurm` asks for 8
whole cores and times 1, 2, 4 and 8 workers:

```bash
cd examples/multicore
sbatch pool_pi.slurm
cat pool-pi-<jobid>.out
```

```text
os.cpu_count()             = 16  <- every CPU on the node, not yours
logical CPUs you may use   = 16
physical cores behind them = 8
SLURM_CPUS_PER_TASK        = 8

workers  seconds  speedup efficiency     error
      1     9.89     1.00       100%   6.3e-13
      2     4.94     2.00       100%   1.2e-13
      4     2.46     4.03       101%   1.1e-13
      8     1.43     6.91        86%   2.2e-14
```

Things to notice:

- **`os.cpu_count()` reports the whole node, not your allocation.** A program
  that starts one worker per `os.cpu_count()` (or uses `n_jobs=-1` in joblib,
  or `detectCores()` in R) can start more workers than you have cores, and
  they slow each other down. Size worker pools from `SLURM_CPUS_PER_TASK`.
- With `--hint=nomultithread` your 8 cores bring both of their hyperthreads,
  so 16 logical CPUs show up. Run one worker per core (8), not 16.
- 8 workers gave a 6.9x speedup, not 8x. Starting the workers and gathering
  results costs time that does not shrink as you add workers.

The same job with `--hint=nomultithread` removed, and with 16 CPUs:

```text
--cpus-per-task=8, no hint: 4 physical cores behind 8 CPUs
workers  seconds  speedup efficiency     error
      4     2.47     4.02       101%   1.1e-13
      8     2.85     3.49        44%   2.2e-14

--cpus-per-task=16, no hint: 8 physical cores behind 16 CPUs
workers  seconds  speedup efficiency     error
      8     1.33     7.44        93%   2.2e-14
     16     1.45     6.83        43%   9.0e-14
```

Without the hint, 8 workers on 4 cores took twice as long as on 8 cores. With
16 hyperthreads, 16 workers were no faster than 8. **Count cores, not CPUs.**

### Threads, Processes and Python

- **Pure-Python loops don't speed up with threads.** Python's global
  interpreter lock (GIL) runs one thread at a time. Use processes:
  `multiprocessing` or `concurrent.futures.ProcessPoolExecutor`.
- **numpy releases the GIL** during array maths, so threads can overlap in
  numpy code, but section 8 shows how little that gains in practice.
- On Boole, numpy's maths library (the `openblas` module) is built
  single-threaded, so `numpy` matrix operations use one core however many you
  request. To use more cores, split the work yourself as these examples do.
- If you use a library that runs OpenMP threads, set
  `export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK` in your script.

## 5. Many Independent Jobs: Job Arrays

`examples/multicore/array_sweep.slurm` submits 6 single-core jobs at once.
Each one gets a different `SLURM_ARRAY_TASK_ID` (1 to 6) and uses it to pick
its problem size, `n = 10^ID`:

```bash
#SBATCH --array=1-6
#SBATCH --cpus-per-task=1
#SBATCH --output=array-sweep-%A_%a.out   # %A = array job ID, %a = task ID

N=$(( 10 ** SLURM_ARRAY_TASK_ID ))
python3 "$APP" --n "$N"
```

```bash
cd examples/multicore
sbatch array_sweep.slurm
squeue -u "$USER"                        # pending tasks show as <jobid>_[2-6]
tail -qn1 array-sweep-<jobid>_*.out      # last line of every task
```

```text
      1     0.22     1.00       100%   8.3e-04
      1     0.31     1.00       100%   8.3e-06
      1     0.26     1.00       100%   8.3e-08
      1     0.29     1.00       100%   8.3e-10
      1     0.30     1.00       100%   8.4e-12
      1     0.44     1.00       100%   2.9e-14
```

Each time `n` grows ten times, the error shrinks a hundred times, until it
reaches the limit of floating-point rounding.

Useful array options:

- `--array=1-1000%20`: run at most 20 tasks at a time, so you leave room for
  other users.
- `--array=1,5,9`: only some IDs. This is handy to re-run the ones that
  failed.
- `scancel <jobid>_7` cancels one task; `scancel <jobid>` cancels them all.
- In real work the ID usually picks a line from a file:
  `INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" inputs.txt)`.

## 6. Many Nodes: MPI

One node has at most 8 real cores on `physical`. To use more, the work must be
split across separate processes on several nodes, which can only cooperate by
sending messages. **MPI** (Message Passing Interface) is the standard way to
do that. Each process is a **rank**, numbered `0` to `size - 1`, and all
ranks run the same program on their own share of the data.

The MPI examples need these modules (the scripts load them for you):

```bash
module purge
module unuse /opt/spack/spack/share/spack/lmod/linux-ubuntu22.04-x86_64/Core
module use /opt/spack/spack/share/spack/lmod/linux-ubuntu24.04-x86_64/Core
module load openmpi/5.0.5 python/3.11.9 py-mpi4py/4.0.1 py-numpy/2.1.2
```

Start MPI programs with `srun`, not `mpirun`. `srun` starts one rank per
Slurm task and tells each rank where the others are:

```bash
export PMIX_MCA_psec=native
srun --mpi=pmix_v5 python3 my_mpi_program.py
```

### Where Did My Ranks Land?

`examples/mpi/mpi_demo.slurm` starts 8 ranks on 2 nodes and runs
`mpi_hello.py`, which prints where each rank is and which CPUs it is pinned
to:

```bash
cd examples/mpi
sbatch mpi_demo.slurm
cat mpi-demo-<jobid>.out
```

```text
Hello from rank 0 of 8 on h17u22.boole.cloudcix.com (cpus [1])
Hello from rank 1 of 8 on h17u22.boole.cloudcix.com (cpus [3])
Hello from rank 2 of 8 on h17u22.boole.cloudcix.com (cpus [5])
Hello from rank 3 of 8 on h17u22.boole.cloudcix.com (cpus [7])
Hello from rank 4 of 8 on h17u25.boole.cloudcix.com (cpus [0])
Hello from rank 5 of 8 on h17u25.boole.cloudcix.com (cpus [2])
Hello from rank 6 of 8 on h17u25.boole.cloudcix.com (cpus [4])
Hello from rank 7 of 8 on h17u25.boole.cloudcix.com (cpus [6])
```

Lines arrive in any order (sorted here). Each rank has its own core. Without
`--hint=nomultithread`, the same job put ranks on CPUs `0, 8, 2, 10`, which
are only two physical cores.

### Collectives: Everyone Takes Part

`examples/mpi/mpi_pi.py` gives each rank an equal slice of the rectangles. The
ranks only talk twice: at the start, rank 0 shares the problem size, and at
the end the partial sums are added up on rank 0:

```python
n = comm.bcast(args.n if rank == 0 else None, root=0)   # rank 0 -> everyone
first, last = n * rank // size, n * (rank + 1) // size  # my slice
...
pi = comm.reduce(local, op=MPI.SUM, root=0)              # everyone -> rank 0
```

`bcast`, `reduce`, `allreduce` (reduce, then share the answer with every
rank), `gather` and `scatter` are **collectives**. Every rank in the
communicator must call them.

### Point-to-Point: Talking to Neighbours

Most real simulations split space, not a list of independent sums.
`examples/mpi/mpi_heat.py` models heat spreading along a ring of cells. Each
rank owns a strip of cells, but updating a cell needs its neighbours, and the
cells at each end of a strip live on another rank. So each rank keeps one
**ghost cell** at each end and refreshes it from its neighbour every step:

```text
        rank 0                 rank 1                 rank 2
 [g| a . . . b |g]      [g| c . . . d |g]      [g| e . . . f |g]

 every step:  b -> rank 1's left ghost     c -> rank 0's right ghost
              d -> rank 2's left ghost     e -> rank 1's right ghost   ...
```

```python
comm.Sendrecv(u[1:2], dest=left, recvbuf=u[-1:], source=right)
comm.Sendrecv(u[-2:-1], dest=right, recvbuf=u[:1], source=left)
u[1:-1] += 0.25 * (u[:-2] - 2 * u[1:-1] + u[2:])
heat = comm.allreduce(u[1:-1].sum())   # like a solver's convergence check
```

This **halo exchange** happens every step, so this program communicates much
more than `mpi_pi.py`. Section 7 shows what that costs.

Both programs print a `RESULT` line whose `value` must be the same however
many ranks you use. If it changes, the work is being split wrongly.

## 7. Scaling: Does More Cores Mean Faster?

Run the same problem on `p` ranks and compare with one rank:

- **Speedup** `S(p) = T(1) / T(p)`. Ideal: `p`.
- **Efficiency** `E(p) = S(p) / p`. Ideal: 100%.

`examples/mpi/mpi_scaling.slurm` takes all 4 `physical` nodes and runs an MPI
program on 1, 2, 4, 8, 16 and 32 ranks, filling one node before using the
next:

```bash
cd examples/mpi
sbatch mpi_scaling.slurm                              # mpi_pi.py
sbatch mpi_scaling.slurm mpi_heat.py                  # halo exchange
sbatch mpi_scaling.slurm mpi_heat.py --n 200000       # same, 40x smaller
```

**`mpi_pi.py`** (little communication):

```text
 ranks  nodes   seconds  speedup  efficiency           value
     1      1     16.25     1.00        100%    3.1415926536
     2      1      8.19     1.98         99%    3.1415926536
     4      1      4.11     3.96         99%    3.1415926536
     8      1      2.08     7.83         98%    3.1415926536
    16      2      1.03    15.77         99%    3.1415926536
    32      4      0.53    30.79         96%    3.1415926536
```

**`mpi_heat.py`** (8 million cells, halo exchange + allreduce every step):

```text
 ranks  nodes   seconds  speedup  efficiency           value
     1      1     39.67     1.00        100%    0.9999999996
     2      1     19.38     2.05        102%    0.9999999996
     4      1     10.18     3.90         97%    0.9999999996
     8      1      5.89     6.74         84%    0.9999999996
    16      2      2.26    17.57        110%    0.9999999996
    32      4      1.03    38.40        120%    0.9999999996
```

**`mpi_heat.py --n 200000`** (40 times less work per step, same messages):

```text
 ranks  nodes   seconds  speedup  efficiency           value
     1      1      0.38     1.00        100%    0.9999993744
     2      1      0.20     1.90         95%    0.9999993744
     4      1      0.10     3.84         96%    0.9999993744
     8      1      0.07     5.59         70%    0.9999993744
    16      2      0.15     2.60         16%    0.9999993744
    32      4      0.20     1.92          6%    0.9999993744
```

What the three tables show:

- **`mpi_pi.py` scales almost perfectly**: 31x faster on 32 ranks. The ranks
  only talk twice, so nothing slows them down. Work this independent could
  also run as a job array.
- **`mpi_heat.py` with 8 million cells did better than ideal.** The usual
  cause of efficiency above 100% is the CPU cache: as the job spreads over
  more nodes, each node's share of the data shrinks and more of it fits in
  the cache, which is much faster than main memory. The 8-rank row (84%) shows the opposite effect:
  8 ranks on one node compete for that node's memory bandwidth. Each extra
  node brings its own memory as well as its own cores.
- **The same program, 40 times smaller, got slower when it left the node.**
  Each step now has very little arithmetic per rank but the same three
  messages. Messages within a node are fast; messages between nodes take
  much longer, and with 500 steps they dominate. The best choice here is 8
  ranks on one node. Asking for 32 made it about 3 times slower and tied up
  4 nodes.

> **Where data lives matters too.** A first version of `mpi_pi.py` handed
> numpy 1 million rectangles per call. Each call then worked on 8 MB arrays,
> too big for the CPU cache, so it ran at the speed of main memory. One rank
> took 35.5 s instead of 16.3 s, and 8 ranks on one node reached only 70%
> efficiency because they were all queueing for the same memory. Cutting the
> calls down to 32,768 rectangles made it twice as fast and fixed the
> scaling.

This is **Amdahl's law** in practice. Any part of the run that does not get
faster with more ranks (messages, synchronisation, serial setup) sets a limit.
If 5% of the run time can't be parallelised, no number of cores gets you past
a 20x speedup.

How to use this for your own code:

1. Before a big campaign, run a short version at 1, 2, 4, 8, ... cores.
2. Choose the largest core count that still gives about **70% efficiency or
   better**. Beyond that, extra cores mostly sit waiting, and big jobs queue
   longer.
3. A bigger problem usually scales further (**weak scaling**). Grow the
   problem with the core count if your science allows it.

## 8. Hybrid MPI and Threads

A hybrid job runs a few MPI ranks per node, and each rank runs several
threads. `mpi_pi.py` starts `SLURM_CPUS_PER_TASK` threads in each rank, so the
same program can be run with different layouts of the same 16 cores:

```bash
cd examples/mpi
sbatch mpi_hybrid.slurm                                            # 4 ranks x 4 threads
sbatch --ntasks-per-node=8 --cpus-per-task=1 mpi_hybrid.slurm      # 16 ranks x 1 thread
sbatch --ntasks-per-node=1 --cpus-per-task=8 mpi_hybrid.slurm      # 2 ranks x 8 threads
```

Options on the `sbatch` command line override the `#SBATCH` lines in the
script. The script first runs `mpi_hello.py`, so you can check each rank got
its cores:

```text
Hello from rank 0 of 4 on h17u17.boole.cloudcix.com (cpus [0, 2, 4, 6])
Hello from rank 1 of 4 on h17u17.boole.cloudcix.com (cpus [1, 3, 5, 7])
Hello from rank 2 of 4 on h17u25.boole.cloudcix.com (cpus [0, 2, 4, 6])
Hello from rank 3 of 4 on h17u25.boole.cloudcix.com (cpus [1, 3, 5, 7])
```

| Layout (2 nodes, 16 cores) | Seconds |
| --- | --- |
| 16 ranks x 1 thread | 1.04 |
| 4 ranks x 4 threads | 3.02 |
| 2 ranks x 8 threads | 15.81 |

Pure MPI won by a wide margin. With 8 threads per rank, the whole 16-core job
took almost as long as one rank on one core (16.3 s, section 7). This is Python's GIL again. numpy releases it while it works on
each chunk, but every thread needs the GIL back between numpy calls, so 8
threads spend most of their time queueing for it.

So in Python, use processes (MPI ranks or `multiprocessing`) rather than
threads for CPU-heavy work. Hybrid jobs pay off for compiled programs that use
OpenMP threads, which many simulation codes offer. In those codes threads have
no GIL, and hybrid runs bring two benefits:

- **Memory.** Every MPI rank holds its own copy of shared data such as lookup
  tables or meshes. Threads in one rank share a single copy.
- **Fewer messages.** Fewer ranks means fewer, larger messages between nodes.

For an OpenMP program, use the same `#SBATCH` layout and add
`export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK`. Then check the `cpus` lists, as
above, to confirm each rank got its own cores.

In `srun`, pass `--cpus-per-task="$SLURM_CPUS_PER_TASK"` explicitly, as
`mpi_hybrid.slurm` does. Some Slurm versions do not pass it from `sbatch` to
`srun`, and every rank then gets a single CPU.

## 9. Was My Job Efficient?

`seff` is not installed on Boole, but `sacct` has everything needed:

```bash
sacct -j <jobid> --format=JobID,JobName,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State
```

- `CPUTime` = `Elapsed` x `AllocCPUS`: what you **reserved**.
- `TotalCPU`: what your processes actually **used**.
- **CPU efficiency = TotalCPU / CPUTime.**

Two runs of `pool_pi.slurm`, each holding 8 CPUs (columns trimmed):

```text
JobID     JobName  AllocCPUS  Elapsed   CPUTime   TotalCPU
19042     pool-pi          8  00:00:19  00:02:32  00:40.540   <- normal sweep
19045     pool-pi          8  00:00:11  00:01:28  00:10.297   <- --workers 1
```

- `--workers 1`: 10.3 s used out of 88 s reserved = **12%**. Seven of the
  eight cores sat idle. This is what a serial script looks like when it asks
  for 8 CPUs.
- The normal sweep: 40.5 / 152 = **27%**. Most of its run time was the 1- and
  2-worker rounds. A job's efficiency is dragged down by its serial parts.

Also compare `MaxRSS` (peak memory) with what you requested. If you ask for
far more than you use, your jobs wait longer for no reason. Boole samples
memory every 30 seconds, so very short jobs can under-report it.

While a job is running:

```bash
sstat -j <jobid> --format=JobID,AveCPU,MaxRSS     # live usage of each step
srun --jobid=<jobid> --overlap --pty top          # watch it on the node itself
```

In `top`, a busy single-threaded process shows about 100% CPU. A process using
8 cores well shows about 800%.

## 10. Checklist

- [ ] Does my program actually use more than one core? If not, request 1 CPU
      and use a job array for many runs.
- [ ] On `physical`, did I add `--hint=nomultithread` and count cores, not
      CPUs?
- [ ] Do my worker or thread counts come from `SLURM_CPUS_PER_TASK`, not
      `os.cpu_count()`?
- [ ] For MPI, did I launch with `srun` and check placement with
      `mpi_hello.py`?
- [ ] Did I run a short scaling test and pick a core count with about 70%
      efficiency or better?
- [ ] After the job, did `TotalCPU / CPUTime` and `MaxRSS` match what I
      asked for?
