# Parallel Computing on Boole: Cores, Nodes and MPI

A job only runs faster on HPC if it uses the hardware it asks for. This guide
shows how to request the right shape of job for your work, and how to check
that you are getting your money's worth from it.

Every example output below comes from a real run on Boole. Timings vary from
run to run, sometimes by 20%, partly because of other jobs on the same nodes,
so yours won't match exactly.

Run every command from the repository folder (`cd ~/hpc_demo`). Output files
appear in that folder.

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

Some words first:

- A **node** is one computer in the cluster.
- A **socket** is one physical processor chip. A node can have more than one.
- A **core** is one independent processing unit on a chip. It runs one
  stream of instructions at full speed.
- A **hyperthread** is a way for one core to run two streams of instructions
  by sharing its parts between them. The operating system shows each
  hyperthread as a separate "CPU", but two hyperthreads on one core are not
  twice as fast as one.

| Partition | Nodes | Per node | Slurm "CPU" means |
| --- | --- | --- | --- |
| `cloud` | 2 (`cpt2-3`) | 8 cores, 22 GB RAM (virtual machines) | a core |
| `physical` | 4 (`h17u17,22,24,25`) | 2 sockets x 4 cores x 2 hyperthreads = 16 CPUs, 256 GB RAM | **a hyperthread** |
| `physical-gpu` | 2 (`gpu0-1`) | 64 cores, 480 GB RAM, 1 NVIDIA A100 | a core |

Check this yourself with `scontrol show node`: multiply `Sockets` by
`CoresPerSocket` to get the real cores, and look at `ThreadsPerCore`.

The `physical` nodes have Intel Xeon Gold 5222 processors. They are also
faster per core than the `cloud` nodes: the same single-core Python
calculation took 9.7 s on `physical` and 14.3 s on `cloud`.

### Hyperthreads Are Not Cores

A `physical` node reports 16 CPUs but has **8 physical cores**. For
number-crunching code, the second hyperthread on a core adds almost nothing.
On these nodes, CPU `N` and CPU `N+8` are the two hyperthreads of the same
core (`lscpu -e` on a node shows the mapping).

Slurm hands out hyperthreads on `physical`, so by default a request for 8 CPUs
gives you **4 cores** (both hyperthreads of each). Add `--hint=nomultithread`
to get whole cores, one task or thread per core:

```bash
#SBATCH --partition=physical
#SBATCH --cpus-per-task=8
#SBATCH --hint=nomultithread   # 8 real cores, not 4 cores x 2 hyperthreads
```

Section 4 shows the difference: the same program ran more than twice as fast
with the hint. All the `physical` examples in this repository use it. On
`cloud` and `physical-gpu` a CPU is already a core, so the hint makes no
difference there.

## 2. The Slurm Options That Shape a Job

| Option | Meaning |
| --- | --- |
| `--nodes=N` | Number of machines. |
| `--ntasks=N` | Number of copies of your program (processes) that `srun` starts. For MPI, each task is one **rank**. |
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
  4 tasks x 4 CPUs each = 16 CPUs
```

Tasks are separate processes, each with its own memory. They can be on
different nodes, so they can only cooperate by sending each other messages.
CPUs within one task share memory, so threads or worker processes there can
share data directly.

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
- **If the work splits into independent pieces, use a job array.** It needs no
  code changes and no communication. The scheduler can also fit many small
  jobs into gaps where one big job would have to wait.

All the examples compute pi as the area under `4 / (1 + x^2)` between 0 and
1, approximated with `n` thin rectangles. That lets you compare the parallel
patterns on the same problem. Each prints its error so you can see it is
still right.

## 4. Many Cores on One Node

`examples/multicore/pool_pi.py` splits the rectangles between worker
processes with Python's `multiprocessing.Pool`. `pool_pi.slurm` asks for 8
whole cores and times 1, 2, 4 and 8 workers:

```bash
sbatch examples/multicore/pool_pi.slurm
cat pool-pi-<jobid>.out
```

```text
os.cpu_count() = 16: every CPU on this node, not just yours.
This job may use: 8 physical cores (16 hyperthreads).
SLURM_CPUS_PER_TASK = 8, so this program uses up to 8 worker process(es).

workers  seconds  speedup efficiency     error
      1     9.75     1.00       100%   6.3e-13
      2     4.89     1.99       100%   1.2e-13
      4     2.52     3.87        97%   1.1e-13
      8     1.26     7.73        97%   2.2e-14
```

**Speedup** is how many times faster than one worker. **Efficiency** is
speedup divided by workers: 100% means every worker is fully used.

Things to notice:

- **`os.cpu_count()` reports the whole node, not your allocation.** A program
  that starts one worker per `os.cpu_count()` can start more workers than you
  have cores, and they then slow each other down. joblib's `n_jobs=-1` and
  R's `detectCores()` can make the same mistake. Size worker pools from
  `SLURM_CPUS_PER_TASK`.
- With `--hint=nomultithread` your 8 cores bring both of their hyperthreads,
  so 16 hyperthreads show up. Run one worker per core (8), not 16.
- 8 workers gave a 7.7x speedup. That is close to perfect, because the
  workers never need to talk to each other.

The same program with the hint turned off (`--hint=multithread`), and then
also with 16 CPUs:

```text
--cpus-per-task=8. This job may use: 4 physical cores (8 hyperthreads).
workers  seconds  speedup efficiency     error
      4     2.51     4.22       105%   1.1e-13
      8     2.85     3.71        46%   2.2e-14

--cpus-per-task=16. This job may use: 8 physical cores (16 hyperthreads).
workers  seconds  speedup efficiency     error
      8     1.50     6.42        80%   2.2e-14
     16     1.51     6.38        40%   9.0e-14
```

Without the hint, 8 workers shared 4 cores and took more than twice as long
as on 8 real cores. With 16 hyperthreads, 16 workers were no faster than 8.
**Count cores, not CPUs.**

### Processes, Threads and Python

A **process** is a running program with its own memory. A **thread** is a
second line of work inside one process, sharing its memory. Most languages
can use many cores with threads, but Python has a catch:

- **Python's global interpreter lock (GIL)** lets only one thread run Python
  code at a time. Pure-Python loops don't speed up with threads, so use
  processes: `multiprocessing` or `concurrent.futures.ProcessPoolExecutor`.
- **numpy releases the GIL** while it computes, so threads can overlap in
  numpy-heavy code. Section 8 shows when that is worth it.
- On Boole, numpy's maths library (the `openblas` module) is built
  single-threaded, so numpy matrix operations use one core however many you
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

Each task also sleeps for 30 seconds, only so you have time to watch it in
`squeue`. Submit it with a limit of 2 tasks running at once:

```bash
sbatch --array=1-6%2 examples/multicore/array_sweep.slurm
squeue -u "$USER"
```

```text
        JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
19089_[3-6%2]     cloud array-sw     eoin PD       0:00      1 (JobArrayTaskLimit)
      19089_1     cloud array-sw     eoin  R       0:12      1 cpt2
      19089_2     cloud array-sw     eoin  R       0:12      1 cpt2
```

When all six have finished, collect the last line of each:

```bash
tail -qn1 array-sweep-<jobid>_*.out
```

```text
      1     0.09     1.00       100%   8.3e-04
      1     0.08     1.00       100%   8.3e-06
      1     0.10     1.00       100%   8.3e-08
      1     0.10     1.00       100%   8.3e-10
      1     0.09     1.00       100%   8.4e-12
      1     0.25     1.00       100%   2.9e-14
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

One `physical` node has 8 real cores. To use more, the work must be split
across separate processes on several nodes, which can only cooperate by
sending messages. **MPI** (Message Passing Interface) is the standard way to
do that. Each process is a **rank**, numbered `0` to `size - 1`, and all
ranks run the same program on their own share of the data. In mpi4py,
`MPI.COMM_WORLD` (the **communicator**) is the group of all ranks in the job.

The MPI examples load these modules for you (see
[Loading Software with Modules](boole_hpc_platform_guide.md#loading-software-with-modules)):

```bash
module load openmpi/5.0.5 python/3.11.9 py-mpi4py/4.0.1 py-numpy/2.1.2
```

Start MPI programs with `srun`. Inside a batch job, `srun` starts one copy of
the program per task and connects them:

```bash
export PMIX_MCA_psec=native               # avoids harmless "psec: munge" error messages
srun --mpi=pmix_v5 python3 my_mpi_program.py
```

`--mpi=pmix_v5` is Boole's default, but writing it keeps the script working
elsewhere. Don't use `mpirun` inside Slurm jobs on Boole: in testing it
refused to start ("not enough slots available").

### Where Did My Ranks Land?

`examples/mpi/mpi_demo.slurm` starts 8 ranks on 2 nodes and runs
`mpi_hello.py`. Each rank prints its node and the CPUs it is **pinned** to
(the only CPUs it is allowed to run on):

```bash
sbatch examples/mpi/mpi_demo.slurm
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

The lines arrive in any order (they are sorted here). `srun` pins each rank
to the CPUs of its task, here one CPU each. With `--hint=nomultithread`
every rank gets its own physical core, and only one of that core's two
hyperthreads is listed. (A program run directly by the batch script, like
`pool_pi.py`, isn't pinned this way and sees the whole allocation.) With `--hint=multithread`, ranks 0-3 landed on CPUs `0, 8, 2, 10`. That
is only two physical cores, each running two ranks.

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
rank owns a strip of cells. To update a cell you need its neighbours, and
the cells at each end of a strip live on another rank. So each rank keeps one
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

This **halo exchange** happens every step, so this program sends far more
messages than `mpi_pi.py`. Messages are cheap within a node and much dearer
between nodes. On Boole, a small message took **0.7 µs** between two ranks on
the same node and **22 µs** between nodes, about 30 times longer. Section 7
shows what that costs.

Both programs print a `RESULT` line whose `value` must be the same however
many ranks you use. If it changes, the work is being split wrongly.

## 7. Scaling: Does More Cores Mean Faster?

Run the same problem on `p` ranks and compare with one rank:

- **Speedup** `S(p) = T(1) / T(p)`. Ideal: `p`.
- **Efficiency** `E(p) = S(p) / p`. Ideal: 100%.

`examples/mpi/mpi_scaling.slurm` takes all 4 `physical` nodes and runs an MPI
program on 1, 2, 4, 8, 16 and 32 ranks, filling one node before using the
next. Each run takes under a minute, but it blocks the whole partition for
everyone else, so in a workshop the instructor runs these:

```bash
sbatch examples/mpi/mpi_scaling.slurm                          # mpi_pi.py
sbatch examples/mpi/mpi_scaling.slurm mpi_heat.py              # halo exchange
sbatch examples/mpi/mpi_scaling.slurm mpi_heat.py --n 200000   # same, 40x smaller
```

**`mpi_pi.py`** (little communication):

```text
 ranks  nodes   seconds  speedup  efficiency           value
     1      1      8.01     1.00        100%    3.1415926536
     2      1      4.08     1.97         98%    3.1415926536
     4      1      2.01     3.98        100%    3.1415926536
     8      1      1.04     7.68         96%    3.1415926536
    16      2      0.52    15.29         96%    3.1415926536
    32      4      0.26    30.94         97%    3.1415926536
```

**`mpi_heat.py`** (8 million cells, halo exchange + allreduce every step):

```text
 ranks  nodes   seconds  speedup  efficiency           value
     1      1     19.85     1.00        100%    0.9999999998
     2      1      9.62     2.06        103%    0.9999999998
     4      1      5.14     3.86         96%    0.9999999998
     8      1      2.98     6.66         83%    0.9999999998
    16      2      1.15    17.23        108%    0.9999999998
    32      4      0.55    35.83        112%    0.9999999998
```

**`mpi_heat.py --n 200000`** (40 times less work per step, same messages):

```text
 ranks  nodes   seconds  speedup  efficiency           value
     1      1      0.19     1.00        100%    0.9999996869
     2      1      0.10     1.93         96%    0.9999996869
     4      1      0.05     3.75         94%    0.9999996869
     8      1      0.04     4.78         60%    0.9999996869
    16      2      0.08     2.36         15%    0.9999996869
    32      4      0.10     1.84          6%    0.9999996869
```

What the three tables show:

- **`mpi_pi.py` scales almost perfectly**: 31x faster on 32 ranks. The ranks
  only talk twice, so nothing slows them down. Work this independent could
  also run as a job array.
- **`mpi_heat.py` with 8 million cells did better than ideal on 2 and 4
  nodes.** The most likely cause is the processors' **cache**, a small amount
  of very fast memory on each chip (33 MB per node here). On one node the
  simulation's data is far bigger than the cache, so the cores wait on main
  memory. On 2 or more nodes, each node's share starts to fit in its cache
  and runs faster. Each extra node brings its own cache and memory as well
  as its own cores. The 8-rank row (83%) is the same effect in reverse: 8
  ranks on one node share one node's memory.
- **The same program, 40 times smaller, got slower when it left the node.**
  Each step now has very little arithmetic per rank but the same messages,
  and messages between nodes take 30 times longer. The best choice here is
  4-8 ranks on one node. Asking for 32 made it 2.5 times slower than 8 and
  tied up 4 nodes.

**How a program uses memory matters too.** `mpi_pi.py` works through its
rectangles in chunks of 32,768 (`--chunk`). With bigger chunks of 262,144,
one rank was a little faster (6.9 s instead of 8.0 s). But 8 ranks on one
node then reached only 55% efficiency, because their larger arrays no longer
fit in cache and the ranks queued for the same memory:

```text
 ranks  nodes   seconds  speedup  efficiency           value     (--chunk 262144)
     1      1      6.86     1.00        100%    3.1415926536
     8      1      1.57     4.37         55%    3.1415926536
    32      4      0.41    16.70         52%    3.1415926536
```

All of this is **Amdahl's law** in practice. Any part of the run that does
not get faster with more ranks sets a limit: messages, waiting for memory,
synchronisation, serial setup. If 5% of the run time can't be parallelised,
no number of cores gets you past a 20x speedup.

How to use this for your own code:

1. Before a big campaign, run a short version at 1, 2, 4, 8, ... cores.
2. Choose the largest core count that still gives about **70% efficiency or
   better**. Beyond that, extra cores mostly sit waiting, and big jobs queue
   longer.
3. A bigger problem usually scales further. Grow the problem with the core
   count if your science allows it.

## 8. Hybrid MPI and Threads

A hybrid job runs a few MPI ranks per node, and each rank runs several
threads. `mpi_pi.py` starts `SLURM_CPUS_PER_TASK` threads in each rank, so the
same program can run with different layouts of the same 16 cores:

```bash
sbatch examples/mpi/mpi_hybrid.slurm                                         # 4 ranks x 4 threads
sbatch --ntasks-per-node=8 --cpus-per-task=1 examples/mpi/mpi_hybrid.slurm   # 16 ranks x 1 thread
sbatch --ntasks-per-node=1 --cpus-per-task=8 examples/mpi/mpi_hybrid.slurm   # 2 ranks x 8 threads
```

The script first runs `mpi_hello.py`, so you can check each rank got its
cores:

```text
Hello from rank 0 of 4 on h17u24.boole.cloudcix.com (cpus [0, 2, 4, 6])
Hello from rank 1 of 4 on h17u24.boole.cloudcix.com (cpus [1, 3, 5, 7])
Hello from rank 2 of 4 on h17u25.boole.cloudcix.com (cpus [0, 2, 4, 6])
Hello from rank 3 of 4 on h17u25.boole.cloudcix.com (cpus [1, 3, 5, 7])
```

Extra arguments go to `mpi_pi.py`, so you can also try bigger chunks, e.g.
`sbatch examples/mpi/mpi_hybrid.slurm --chunk 262144`. One rank on one core
takes 8.0 s, so 16 cores would ideally take 0.50 s:

| Layout (2 nodes, 16 cores) | Seconds, `--chunk 32768` (default) | Seconds, `--chunk 262144` |
| --- | --- | --- |
| 16 ranks x 1 thread | **0.53** | 0.84 |
| 4 ranks x 4 threads | 1.48 | 0.79 |
| 2 ranks x 8 threads | 7.97 | 1.12 |

What this shows:

- **With small chunks, threads made things worse.** 8 threads per rank were
  15 times slower than 8 separate ranks. Each thread needs the GIL back
  after every numpy call, and with small chunks that is thousands of times a
  second, so the threads mostly queue for it.
- **With bigger chunks, threads worked**, but the bigger arrays ran into the
  memory limits from section 7.
- **The fastest layout was pure MPI with small chunks**, within 6% of ideal.

So in Python, use processes (MPI ranks or `multiprocessing`) rather than
threads for CPU-heavy work. Hybrid jobs pay off for compiled programs that
use OpenMP threads, which many simulation codes offer. Those threads have no
GIL, and hybrid runs bring two benefits:

- **Memory.** Every MPI rank holds its own copy of shared data such as lookup
  tables or meshes. Threads in one rank share a single copy.
- **Fewer messages.** Fewer ranks means fewer messages between nodes.

For an OpenMP program, use the same `#SBATCH` layout and add
`export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK`. Then check the `cpus` lists, as
above, to confirm each rank got its own cores.

`mpi_hybrid.slurm` passes `--cpus-per-task="$SLURM_CPUS_PER_TASK"` to `srun`.
Slurm 23.11, which Boole runs, would pass it on anyway. Slurm 22.05 to 23.02
don't, and every rank then gets a single CPU, so writing it keeps your
script safe on other clusters.

## 9. Was My Job Efficient?

`seff` is not installed on Boole, but `sacct` has everything needed:

```bash
sacct -j <jobid> --format=JobID,JobName,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State
```

- `CPUTime` = `Elapsed` x `AllocCPUS`: what you **reserved**.
- `TotalCPU`: what your processes actually **used**.
- **CPU efficiency = TotalCPU / CPUTime**, read from the first line.

Two runs of `pool_pi.slurm`, each holding 8 CPUs:

```text
JobID           JobName  AllocCPUS    Elapsed    CPUTime   TotalCPU     MaxRSS      State
------------ ---------- ---------- ---------- ---------- ---------- ---------- ----------
19090           pool-pi          8   00:00:19   00:02:32  00:39.558             COMPLETED
19090.batch       batch          8   00:00:19   00:02:32  00:39.556      1704K  COMPLETED
19090.extern     extern          8   00:00:19   00:02:32  00:00.002       256K  COMPLETED
19095           pool-pi          8   00:00:10   00:01:20  00:10.008             COMPLETED
19095.batch       batch          8   00:00:10   00:01:20  00:10.007       996K  COMPLETED
19095.extern     extern          8   00:00:10   00:01:20  00:00.001          0  COMPLETED
```

- **19095** was run with `--workers 1`: 10 s used out of 80 s reserved =
  **12%**. Seven of the eight cores sat idle. This is what a serial script
  looks like when it asks for 8 CPUs.
- **19090** was the normal sweep: 39.6 / 152 = **26%**. Most of its run time
  was the 1- and 2-worker rounds, so a job's efficiency is dragged down by
  its serial parts.

`MaxRSS` (peak memory) is on the `.batch` line, and on one line per `srun`
step if your script uses `srun` (section 6). Compare it with what you
requested: if you ask for far more than you use, your jobs wait longer for no
reason. Slurm samples memory every 30 seconds, so for jobs shorter than a
minute `MaxRSS` can be far too low. Treat it as a lower bound, and check a
longer run before cutting your request close.

While a job is running:

```bash
sstat -a -j <jobid> --format=JobID,AveCPU,MaxRSS   # live usage of each step
srun --jobid=<jobid> --overlap --pty top           # watch it on the node (q to quit)
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
