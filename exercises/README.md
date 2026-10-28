# Workshop Exercises

Work through these in order. Each exercise says what to read first, what to
run, and what you should see. Click **Answers** under an exercise to check
yourself.

## Before You Start

- **Run everything from the repository folder.** After cloning, every
  command below assumes you are here:

  ```bash
  cd ~/hpc_demo
  ```

  If you get `sbatch: error: Unable to open file`, you are in the wrong
  folder: run `cd ~/hpc_demo` again.

- **Job IDs.** `sbatch` replies `Submitted batch job 19086`. That number is
  the job ID. Wherever you see `<jobid>`, type your number without the
  `< >`, e.g. `cat cpu_test_19086.out`.

- **Is my job finished?** `squeue -u "$USER"` lists your jobs that are
  waiting (`PD`) or running (`R`). A finished job disappears from the list,
  and its output file is in `~/hpc_demo`. `ls -t *.out | head` shows the
  newest output files.

- **Don't edit the scripts.** Options given to `sbatch` on the command line
  override the `#SBATCH` lines in a script, so the exercises change things
  that way and every script stays as it was.

- **The cluster is small and shared.** Keep the resource requests as shown,
  and `exit` interactive sessions when you're done with them.

| Part | Exercises | Time, including reading |
| --- | --- | --- |
| 1. Slurm basics | 1-4 | 45 min |
| 2. Using many cores | 5-7 | 40 min |
| 3. MPI, scaling and OpenFOAM | 8-12 | 65 min |
| 4. GPUs, containers and interactive apps (optional) | 13-15 | 30 min |
| 5. Your own work | 16 | 15 min |

When the whole room submits at once, jobs may wait a few minutes in the
queue. Read the next section while you wait.

---

## Part 1: Slurm Basics

Read first, in the platform guide:
[Login Node and Compute Nodes](../docs/boole_hpc_platform_guide.md#login-node-and-compute-nodes),
[Partitions](../docs/boole_hpc_platform_guide.md#partitions) and
[Interactive Jobs](../docs/boole_hpc_platform_guide.md#interactive-jobs-with-srun).

### Exercise 1: Inspect the Cluster (5 min)

```bash
sinfo
scontrol show node h17u17
```

Questions:

1. Which partitions can you see, and how many nodes does each have?
2. Which nodes are `idle` (free), `mix` (partly used) or `alloc` (full)?
3. Where would a small CPU test job fit best?
4. `h17u17` reports `CPUTot=16`. Using `Sockets` (processor chips),
   `CoresPerSocket` and `ThreadsPerCore`, how many physical cores does it
   really have?

<details>
<summary>Answers</summary>

1. `cloud` (2 nodes, the default, marked `*`), `physical` (4 nodes) and
   `physical-gpu` (2 nodes).
2. It changes all the time. Check the `STATE` column.
3. `cloud`: small, general-purpose, and it leaves the bare-metal nodes free
   for big jobs.
4. `Sockets=2` x `CoresPerSocket=4` = **8 physical cores**. `ThreadsPerCore=2`
   means each core has 2 hyperthreads, so Slurm counts 16 CPUs.

</details>

### Exercise 2: Start an Interactive Job (10 min)

```bash
srun --partition=cloud --cpus-per-task=1 --mem=1G --time=00:15:00 --pty bash
```

When the prompt changes (for example to `eoin@cpt2`), run:

```bash
hostname
echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "SLURM_JOB_NODELIST=$SLURM_JOB_NODELIST"
ls ~/hpc_demo
```

Then leave the job, which frees its CPU for others:

```bash
exit
```

Questions:

1. Did `hostname` change from the login node?
2. Can you see the same files in `~/hpc_demo` from the compute node?
3. What job ID did Slurm assign to the interactive session?

<details>
<summary>Answers</summary>

1. Yes: from `login1...` to a compute node such as `cpt2.boole.cloudcix.com`.
2. Yes. Home directories are shared by all nodes.
3. The number printed for `SLURM_JOB_ID`. Interactive sessions are jobs too,
   and appear in `squeue` while they run.

</details>

### Exercise 3: Your First Batch Job (10 min)

Read first: [Your First Batch Job](../docs/boole_hpc_platform_guide.md#your-first-batch-job),
which explains every line of the script. Then:

```bash
sbatch examples/slurm/cpu_test.sh
squeue -u "$USER"
```

The job takes about a second, so it may already be gone from `squeue`. Read
its output:

```bash
cat cpu_test_<jobid>.out
```

You should see:

```text
Running on host: cpt2.boole.cloudcix.com
Job ID: 19086
Submit directory: /home/<you>/hpc_demo
Allocated CPUs: 2
...
This task can use 2 CPU core(s).
```

Now ask for 4 CPUs instead, without editing the script:

```bash
sbatch --cpus-per-task=4 examples/slurm/cpu_test.sh
```

Questions:

1. Which lines of the new output changed?
2. Where did the output file appear, and why there?

<details>
<summary>Answers</summary>

1. `Allocated CPUs: 4` and `This task can use 4 CPU core(s).` The job ID and
   possibly the node also differ.
2. In `~/hpc_demo`, the folder you ran `sbatch` from (`SLURM_SUBMIT_DIR`).
   The script's `--output=cpu_test_%j.out` line names it, with `%j`
   replaced by the job ID.

</details>

### Exercise 4: Read a Job Record (10 min)

Use the job ID from Exercise 3:

```bash
sacct -j <jobid> --format=JobID,JobName,State,Elapsed,ReqMem,MaxRSS
```

```text
JobID           JobName      State    Elapsed     ReqMem     MaxRSS
------------ ---------- ---------- ---------- ---------- ----------
19086          cpu_test  COMPLETED   00:00:01         2G
19086.batch       batch  COMPLETED   00:00:01                  424K
19086.extern     extern  COMPLETED   00:00:01                     0
```

The first line is the whole job. `.batch` is your script, and `.extern` is
Slurm's own bookkeeping. Memory use (`MaxRSS`) appears on the `.batch` line.
To list all your jobs from today: `sacct -u "$USER" -S today`.

Questions:

1. Did the job finish successfully, and how long did it run?
2. How much memory did it request (`ReqMem`) and use (`MaxRSS`)?
3. What would you change before running hundreds of jobs like this?

<details>
<summary>Answers</summary>

1. `COMPLETED`, in about one second.
2. It requested 2 GB. `MaxRSS` shows a few MB at most. For a job this short
   that is an underestimate (Slurm samples memory every 30 seconds), but
   either way it is far below 2 GB.
3. Request much less memory (e.g. `--mem=500M`), and 1 CPU instead of 2: the
   Python in this script only ever uses one. Smaller requests start sooner
   and leave room for others. Leave some margin above the real memory use,
   because a job that exceeds its memory is killed.

</details>

---

## Part 2: Using Many Cores

Read first: sections 1-4 of the
[Parallel Computing Guide](../docs/parallel_computing_guide.md).

### Exercise 5: Use Every Core You Asked For (10 min)

`pool_pi.slurm` asks for 8 whole cores on a `physical` node and times the
same calculation with 1, 2, 4 and 8 worker processes:

```bash
sbatch examples/multicore/pool_pi.slurm
```

It runs for about 20 seconds. Then:

```bash
cat pool-pi-<jobid>.out
```

```text
os.cpu_count() = 16: every CPU on this node, not just yours.
This job may use: 8 physical cores (16 hyperthreads).
SLURM_CPUS_PER_TASK = 8, so this program uses up to 8 worker process(es).

workers  seconds  speedup efficiency     error
      1     9.75     1.00       100%   6.3e-13
...
      8     1.26     7.73        97%   2.2e-14
```

Now turn off whole-core allocation, and then also ask for 16 CPUs. Each of
these holds half or all of a `physical` node, so if you are working in pairs,
run one each and compare:

```bash
sbatch --hint=multithread examples/multicore/pool_pi.slurm
sbatch --hint=multithread --cpus-per-task=16 examples/multicore/pool_pi.slurm
```

Questions:

1. In the first run, how close to 8x was the speedup with 8 workers?
2. What would happen if the program started `os.cpu_count()` workers?
3. With `--hint=multithread`, how many physical cores did you get, and what
   happened to the 8-worker time?
4. With 16 CPUs, was 16 workers faster than 8?

<details>
<summary>Answers</summary>

1. Usually between 6.5x and 7.7x (roughly 80-97% efficiency); it varies from
   run to run, partly because of other jobs on the same node. The workers never talk to each other, so nearly all the
   time is useful work.
2. It would start 16 workers on 8 cores. They would compete for the cores
   and run no faster than 8, and on a smaller allocation (say 2 cores) much
   slower.
3. Only **4 physical cores** (8 hyperthreads). 8 workers took about 2.9 s
   instead of about 1.3 s, more than twice as slow, because pairs of workers
   shared a core.
4. No: 16 workers were no faster than 8 (both about 1.3-1.5 s). Hyperthreads
   don't add speed for this kind of work. **Count cores, not CPUs.**

</details>

### Exercise 6: Run Many Independent Jobs with an Array (10 min)

Read first: [section 5](../docs/parallel_computing_guide.md#5-many-independent-jobs-job-arrays).
Submit 6 tasks, at most 2 running at a time, then watch them for a minute:

```bash
sbatch --array=1-6%2 examples/multicore/array_sweep.slurm
squeue -u "$USER"
```

While tasks are still waiting, cancel the last one:

```bash
scancel <jobid>_6
```

Run `squeue -u "$USER"` again every 15 seconds or so. When all the tasks are
gone, collect the last line of each task's output:

```bash
tail -qn1 array-sweep-<jobid>_*.out
```

Questions:

1. How many tasks ran at the same time, and what reason did `squeue` give
   for the others?
2. How many output files did you get, and why?
3. How does the error (last column) change each time `n` grows ten times?

<details>
<summary>Answers</summary>

1. Two, because of the `%2` limit. The others showed `PD` with reason
   `JobArrayTaskLimit`, as one line such as `19089_[3-6%2]`. If the cluster
   is busy you may see `Resources` or `Priority` first: then even the first
   two are waiting for a free CPU.
2. Five: task 6 was cancelled before it started, so it never wrote a file.
3. It shrinks about a hundred times (`8.3e-04`, `8.3e-06`, ...), until it
   reaches the limit of floating-point rounding around `1e-14`.

</details>

### Exercise 7: Was My Job Efficient? (10 min)

Read first: [section 9](../docs/parallel_computing_guide.md#9-was-my-job-efficient).
Submit a job that holds 8 cores but only uses one:

```bash
sbatch examples/multicore/pool_pi.slurm --workers 1
```

(Arguments after the script name are passed to the program, here
`pool_pi.py`.) When it has finished, compare it with your first job from
Exercise 5. Give both job IDs, separated by a comma:

```bash
sacct -j <ex5_jobid>,<ex7_jobid> --format=JobID,JobName,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State
```

If you've lost a job ID, `sacct -u "$USER" -S today` lists all your jobs from
today.

`CPUTime` is what the job reserved (`Elapsed` x `AllocCPUS`). `TotalCPU` is
what it actually used. Read both from the first line.

Questions:

1. What CPU efficiency (`TotalCPU / CPUTime`) did each job get?
2. Why is even the normal sweep from Exercise 5 well below 100%?
3. The script requests 4 GB. Was that close to `MaxRSS`?

<details>
<summary>Answers</summary>

1. About **12%** for `--workers 1` (about 10 s used out of 80 s reserved),
   and about **25-30%** for the normal sweep.
2. The sweep spends most of its time on the 1- and 2-worker rounds, when
   most of the 8 cores are idle. A job's efficiency is dragged down by its
   serial parts.
3. No: `MaxRSS` was only a few MB. That is an underestimate for a job this
   short, but a real job of this kind could still ask for far less memory.

</details>

---

## Part 3: MPI and Scaling

Read first: [section 6](../docs/parallel_computing_guide.md#6-many-nodes-mpi).

### Exercise 8: Where Do MPI Ranks Run? (10 min)

```bash
sbatch examples/mpi/mpi_demo.slurm
cat mpi-demo-<jobid>.out
```

At the end of the output, each rank prints its node and the CPUs it is pinned
to:

```text
Hello from rank 0 of 8 on h17u22.boole.cloudcix.com (cpus [1])
Hello from rank 1 of 8 on h17u22.boole.cloudcix.com (cpus [3])
...
```

The lines arrive in any order. Now try two other layouts:

```bash
sbatch --ntasks-per-node=8 examples/mpi/mpi_demo.slurm
sbatch --hint=multithread examples/mpi/mpi_demo.slurm
```

Questions:

1. In the first run, how many ranks ran on each node?
2. With `--ntasks-per-node=8`, how many ranks are there in total?
3. With `--hint=multithread`, look at the `cpus` of the ranks on one node.
   On these nodes, CPU `N` and CPU `N+8` are the same physical core. Do any
   ranks share a core?

<details>
<summary>Answers</summary>

1. 4 per node, on 2 nodes: `--nodes=2 --ntasks-per-node=4` = 8 ranks.
2. 16 (2 nodes x 8), each on its own core, CPUs 0-7.
3. Yes. The ranks land on CPUs such as `0, 8, 2, 10`. 0 and 8 are one core,
   and 2 and 10 are another, so 4 ranks get only 2 cores.

</details>

### Exercise 9: Scaling Study (15 min, instructor demo)

Read first: [section 7](../docs/parallel_computing_guide.md#7-scaling-does-more-cores-mean-faster).

Each scaling run uses all four `physical` nodes, so **the instructor runs
these** and shares the output. The same tables are in section 7 of the
guide.

```bash
# Instructor only: each of these takes the whole physical partition.
# sbatch examples/mpi/mpi_scaling.slurm
# sbatch examples/mpi/mpi_scaling.slurm mpi_heat.py
# sbatch examples/mpi/mpi_scaling.slurm mpi_heat.py --n 200000
```

Questions:

1. Is the `value` column the same on every row? Why does that matter?
2. Does either program get close to the ideal 32x speedup on 32 ranks?
3. Some efficiencies for `mpi_heat.py` are above 100%. How can more ranks
   be more than proportionally faster?
4. For the small heat problem (`--n 200000`), what is the best number of
   ranks? What happens when the job spreads to a second node, and why?

<details>
<summary>Answers</summary>

1. Yes. It shows the parallel program still computes the same answer. A
   fast but wrong answer is worthless.
2. Both do. `mpi_pi.py` reaches about 31x because its ranks only talk twice.
   The big `mpi_heat.py` problem even beats 32x (see question 3).
3. Spread over more nodes, each node's share of the data shrinks until it
   fits in the processors' fast cache, so each rank works faster than the
   single rank did.
4. About 4-8 ranks on one node. On 2 or more nodes it gets *slower*: each
   step has little work but still exchanges messages, and a message between
   nodes takes about 30 times longer than within a node.

</details>

### Exercise 10: Hybrid MPI and Threads (10 min)

Read first: [section 8](../docs/parallel_computing_guide.md#8-hybrid-mpi-and-threads).
Each run uses 2 `physical` nodes, so **split these between the people at your
table** and compare results:

```bash
sbatch examples/mpi/mpi_hybrid.slurm                                         # 4 ranks x 4 threads
sbatch --ntasks-per-node=8 --cpus-per-task=1 examples/mpi/mpi_hybrid.slurm   # 16 ranks x 1 thread
sbatch --ntasks-per-node=1 --cpus-per-task=8 examples/mpi/mpi_hybrid.slurm   # 2 ranks x 8 threads
sbatch --ntasks-per-node=1 --cpus-per-task=8 examples/mpi/mpi_hybrid.slurm --chunk 262144
```

The `seconds=` value on the `RESULT` line is the run time.

Questions:

1. Check the `cpus` lists: did each rank get the cores you expected?
2. Which layout was fastest?
3. Why were 8 threads per rank so slow, and why did `--chunk 262144` help
   them?

<details>
<summary>Answers</summary>

1. Yes: 4 CPUs per rank, 1 per rank, or 8 per rank respectively.
2. 16 ranks x 1 thread (about 0.5 s), close to the ideal of 8.0 s / 16.
3. Python's GIL. Each thread needs it back after every numpy call. With
   small chunks that happens thousands of times a second, so the threads
   mostly wait. Bigger chunks mean fewer handovers, so the threads overlap
   more, but pure MPI was still faster.

</details>

### Exercise 11: OpenFOAM in Parallel (15 min)

Read first: the [OpenFOAM Guide](../docs/openfoam_guide.md).

Run the lid-driven cavity on 8 ranks of one node:

```bash
sbatch examples/openfoam/cavity.slurm
```

It takes about 10 seconds once it starts. Then:

```bash
cat openfoam-cavity-<jobid>.out
ls openfoam-cavity-<jobid>/ranks-8
```

```text
Mesh 200 x 200 = 40000 cells, 100 time steps. Cases in /home/<you>/hpc_demo/openfoam-cavity-<jobid>

8 ranks on 1 node(s): 7.3 s   (Courant Number mean: 0.100853 max: 0.49187)
```

Now run a mesh four times smaller:

```bash
sbatch --export=ALL,MESH=100 examples/openfoam/cavity.slurm
```

The scaling study across all four `physical` nodes is an instructor demo;
its tables are in the [OpenFOAM Guide](../docs/openfoam_guide.md#how-well-does-it-scale).

```bash
# Instructor only: these take the whole physical partition for about 10 minutes.
# sbatch --nodes=4 examples/openfoam/cavity.slurm 1 2 4 8 16 32
# sbatch --nodes=4 --export=ALL,MESH=300 examples/openfoam/cavity.slurm 1 2 4 8 16 32
```

Questions:

1. What is in the `ranks-8` folder, and why are there 8 `processor` folders?
2. How many cells did each rank get with `MESH=100`? Was it much faster
   than with 200?
3. In the scaling tables, why did 16 ranks on 2 nodes run slower than 8
   ranks on 1 node?
4. You have a 2-million-cell case. How would you choose how many ranks and
   nodes to use?

<details>
<summary>Answers</summary>

1. The case: `0` (start), `0.025` (the result after 100 time steps),
   `constant`, `system`, a log for each step, and `processor0` to
   `processor7`. `decomposePar` split the mesh into one piece per MPI rank,
   and each rank read and wrote only its own piece.
2. 10,000 cells / 8 ranks = 1,250 each. It took about 2 seconds instead of
   about 7: four times fewer cells, but not four times less communication.
3. The pressure solver exchanges data hundreds of times per time step, and
   each message between nodes takes about 30 times longer than within a
   node. The extra waiting outweighs the extra cores.
4. Measure: run a few time steps on 8 ranks (one node) and on 16 (two
   nodes), and keep the fastest that is still efficient. At 2 million cells
   you'd have 250,000 cells per rank on one node, so a second node *might*
   help, but on Boole today, check before assuming.

</details>

### Exercise 12 (Stretch): Point-to-Point Messages

Copy the pi program:

```bash
cp examples/mpi/mpi_pi.py examples/mpi/my_pi.py
```

Open it in an editor (`nano examples/mpi/my_pi.py`; save with Ctrl+O, Enter,
and quit with Ctrl+X). Replace the `comm.reduce(...)` line with point-to-point
messages. Every rank except 0 sends its `local` sum to rank 0 with
`comm.send(local, dest=0)`. Rank 0 adds its own `local` to
`comm.recv(source=r)` for each other rank `r`. Test it on one node with 1, 2,
4 and 8 ranks:

```bash
sbatch --nodes=1 examples/mpi/mpi_scaling.slurm my_pi.py --n 100000000
```

Check that the `value` column is still pi on every row. Then think: why do
MPI libraries provide `reduce` anyway?

<details>
<summary>Answers</summary>

```python
if rank == 0:
    pi = local + sum(comm.recv(source=r) for r in range(1, size))
else:
    comm.send(local, dest=0)
    pi = None
```

`reduce` is shorter and harder to get wrong. It is also faster on many
ranks: rank 0 above receives `size - 1` messages one after another, while
`reduce` combines partial sums in a tree, which takes about `log2(size)`
steps.

</details>

---

## Part 4: GPUs, Containers and Interactive Apps (Optional)

### Exercise 13: Size a GPU Job

Read first: the [GPU Guide](../docs/gpu_guide.md).

There are only 2 GPUs, so take turns. First check you can reach one:

```bash
sbatch examples/gpu/gpu_test.sh
cat gpu_test_<jobid>.out
```

You should see an `NVIDIA A100-SXM4-80GB` in the `nvidia-smi` table, and
`Cuda compilation tools, release 12.0` from `nvcc`.

The data-loader sweep needs a GPU for about a minute, plus queueing, so
**the instructor runs it** (you can run it yourself later, after
`bash examples/gpu/setup_torch_env.sh`). The output is in the
[GPU Guide](../docs/gpu_guide.md#how-many-cpus-does-a-gpu-job-need).

```bash
# Instructor, or later on your own:
# sbatch examples/gpu/gpu_dataloader.slurm
# sbatch --cpus-per-task=4 examples/gpu/gpu_dataloader.slurm
```

Questions:

1. With 0 data-loader workers, how busy was the GPU, and why?
2. How many CPUs should a job like this request, and why not 64?
3. What happened with only 4 CPUs?

<details>
<summary>Answers</summary>

1. About 15%. Every batch was prepared by the main process on one CPU core,
   and the GPU waited for it most of the time.
2. About 9: 8 workers plus the main process. Throughput stopped rising at 8
   workers (15 were no faster), so more CPUs would sit idle. The GPU node's
   other cores and memory can then run other people's jobs.
3. With 3 workers it reached about 7,300 images/s, less than half the speed
   with 8. Too few CPUs leave the GPU waiting.

</details>

### Exercise 14: Try a Container

Read first: [Running Docker Images with Apptainer](../docs/boole_hpc_platform_guide.md#running-docker-images-with-apptainer).

```bash
sbatch examples/containers/apptainer_hello.slurm
cat apptainer-hello-<jobid>.out
ls -lh hello-world_latest.sif
```

The output includes `Hello from Docker!`. The job converted the Docker image
into `hello-world_latest.sif` in `~/hpc_demo`, and the next run reuses that
file instead of downloading it again. The `WARNING: passwd file doesn't
exist` lines are harmless.

### Exercise 15: Size an Interactive Session

Read first: [Interactive Apps in Open OnDemand](../docs/ondemand_guide.md).

1. In [Open OnDemand](https://hpc.cloudcix.com), launch **Jupyter Notebook**
   with Partition **Cloud Compute**, **1** CPU core, **2** GB RAM and
   **1** hour.
2. When it starts, connect, open a new notebook and run:

   ```python
   import os
   print(os.cpu_count(), len(os.sched_getaffinity(0)), os.environ.get("SLURM_JOB_ID"))
   ```

3. Open a terminal (in Jupyter: **File → New → Terminal**) and run
   `squeue -u $USER`.
4. Go back to Open OnDemand, open **My Interactive Sessions**, and
   **Delete** the session.
5. In any terminal on Boole:

   ```bash
   sacct -u $USER -S today --name=sys/dashboard/sys/Jupyter \
         --format=JobID,JobName%30,AllocCPUS,Elapsed,CPUTime,TotalCPU,State
   ```

Questions:

1. How many CPUs does the node have, and how many could your notebook use?
2. What did your session look like in `squeue`?
3. What was the session's CPU efficiency (`TotalCPU / CPUTime`)? Why is it
   low, and what does that tell you about how much to ask for?

<details>
<summary>Answers</summary>

1. `os.cpu_count()` shows the whole node (8 on a `cloud` node), but the
   affinity count is the 1 CPU you asked for.
2. A running job (`R`) named `sys/dash...`, the start of
   `sys/dashboard/sys/Jupyter`. The session is an ordinary Slurm job.
3. Very low, probably a few percent. Most of an interactive session is
   reading and typing, so its cores sit idle. Ask for the minimum, and move
   heavy work into batch jobs.

</details>

---

## Part 5: Your Own Work

### Exercise 16: Adapt a Template

Read first: [templates/README.md](../templates/README.md).

Run one small program on many files using the job-array template. First make
five sample input files and a list of them:

```bash
mkdir -p mydata
for i in 1 2 3 4 5; do seq $((i * 100000)) > mydata/numbers_$i.txt; done
ls mydata/*.txt > inputs.txt
cat inputs.txt
```

Copy the template and open it in an editor:

```bash
cp templates/array_files.slurm my_array.slurm
nano my_array.slurm
```

Leave the other `CHANGE` lines as they are for now. Go to the last line,
`python3 my_script.py "$INPUT"`, delete it with Ctrl+K, and type this
instead, which counts the lines of each file:

```bash
wc -l "$INPUT"
```

Save (Ctrl+O, Enter) and quit (Ctrl+X). Then submit one task per line of
`inputs.txt`:

```bash
sbatch --array=1-$(wc -l < inputs.txt) my_array.slurm
```

When the tasks have finished:

```bash
cat my-array-<jobid>_*.out
```

Questions:

1. How many array tasks ran, and what did each one print?
2. How would you run your own analysis script on 200 data files, at most 10
   at a time?

<details>
<summary>Answers</summary>

1. Five, one per line of `inputs.txt`. Each printed its task number and file,
   then the line count, e.g. `Task 3: mydata/numbers_3.txt` and
   `300000 mydata/numbers_3.txt`.
2. List the files (`ls data/*.csv > inputs.txt`), put your command on the
   last line of the template (e.g. `python3 analyse.py "$INPUT"`), set the
   memory and time for **one** file, and submit with
   `sbatch --array=1-$(wc -l < inputs.txt)%10 my_array.slurm`.

</details>
