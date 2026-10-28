# Workshop Exercises

Use these short exercises during or after the presentation.

## Exercise 1: Inspect the Cluster

Run:

```bash
sinfo
scontrol show node
```

Questions:

* Which partitions are visible to you?
* Which nodes are idle, allocated, or down?
* Where would a small CPU test job fit best?
* A `physical` node reports `CPUTot=16`. Using `Sockets`, `CoresPerSocket`,
  and `ThreadsPerCore`, how many physical cores does it really have?

## Exercise 2: Start an Interactive Job

Request a short interactive shell on a compute node:

```bash
srun --partition=cloud --cpus-per-task=2 --mem=4G --time=00:15:00 --pty bash
```

Once the prompt changes, run:

```bash
hostname
echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "SLURM_JOB_NODELIST=$SLURM_JOB_NODELIST"
pwd
ls -la "$HOME"
```

Questions:

* Did `hostname` change from the login node?
* Can you see the same home directory contents from the compute node?
* What job ID did Slurm assign to the interactive session?

Leave the interactive job:

```bash
exit
```

## Exercise 3: Submit a CPU Job

Submit:

```bash
sbatch examples/slurm/cpu_test.sh
squeue -u "$USER"
```

After it completes, open the output file:

```bash
cat cpu_test_<jobid>.out
```

Change one resource request in the script, such as `--cpus-per-task` or
`--mem`, then submit it again.

## Exercise 4: Read a Job Record

Pick one completed job ID and run:

```bash
sacct -j <jobid> --format=JobID,JobName,State,Elapsed,MaxRSS
scontrol show job <jobid>
```

Questions:

* Did the job finish successfully?
* How long did it run?
* Did it use close to the memory requested?

## Exercise 5: Where Do MPI Ranks Run?

From the MPI example directory:

```bash
cd examples/mpi
sbatch mpi_demo.slurm
```

The MPI batch script loads the required `openmpi`, `python`, and `py-mpi4py`
modules before running. If `mpi4py` is missing, check the module names with:

```bash
module spider mpi4py
module spider openmpi
```

After it completes:

```bash
cat mpi-demo-<jobid>.out
```

Each line shows the rank, the node, and the CPUs the rank is pinned to.

* Change `--ntasks-per-node` to 8 and submit again. How many ranks run on
  each node now?
* Delete the `#SBATCH --hint=nomultithread` line and submit again. On the
  `physical` nodes CPU `N` and CPU `N+8` are the two hyperthreads of the same
  core. Do any two ranks now share a core?

## Exercise 6: Use Every Core You Asked For

```bash
cd examples/multicore
sbatch pool_pi.slurm
cat pool-pi-<jobid>.out
```

Questions:

* What does `os.cpu_count()` report, and how many CPUs did the job actually
  get? What would happen if the program started `os.cpu_count()` workers?
* How close to 8x is the speedup with 8 workers?

Now try the hyperthread experiments:

1. Delete the `#SBATCH --hint=nomultithread` line and submit again. How many
   physical cores are behind your 8 CPUs now? What happened to the time with
   8 workers?
2. Also set `--cpus-per-task=16`. Is 16 workers twice as fast as 8?

## Exercise 7: Run Many Independent Jobs with an Array

```bash
cd examples/multicore
sbatch array_sweep.slurm
squeue -u "$USER"
```

While it runs, notice how `squeue` shows the array tasks. After it completes,
collect the last line of every task:

```bash
tail -qn1 array-sweep-<jobid>_*.out
```

Questions:

* How does the error change each time `n` grows ten times?
* Change `--array=1-6` to `--array=1-6%2`. What changes in `squeue`?

## Exercise 8: Scaling Study

Run the same problem on 1 to 32 ranks, first with little communication, then
with a halo exchange every step:

```bash
cd examples/mpi
sbatch mpi_scaling.slurm
sbatch mpi_scaling.slurm mpi_heat.py
```

Each job uses all four `physical` nodes, so the second waits for the first.
The table at the end of each output file shows speedup and efficiency.

Questions:

* Is the `value` column the same on every row? Why does that matter?
* Does either program get close to the ideal 32x speedup on 32 ranks?
* Some efficiencies may be above 100%. How can more ranks be more than
  proportionally faster?

Now make the heat problem 40 times smaller and run it again:

```bash
sbatch mpi_scaling.slurm mpi_heat.py --n 200000
```

* What is the best number of ranks for this problem size?
* What happens when the job spreads to a second node, and why?

## Exercise 9: Hybrid MPI and Threads

```bash
cd examples/mpi
sbatch mpi_hybrid.slurm
```

The script runs 2 ranks per node with 4 threads each. Compare it with other
layouts of the same 16 cores (command-line options override the `#SBATCH`
lines):

```bash
sbatch --ntasks-per-node=8 --cpus-per-task=1 mpi_hybrid.slurm
sbatch --ntasks-per-node=1 --cpus-per-task=8 mpi_hybrid.slurm
```

Which layout is fastest for this program, and why? (Hint: this is Python.)
Check the `cpus` lists in each output to confirm what each rank was given.

## Exercise 10: Was My Job Efficient?

Submit a job that asks for 8 CPUs but only uses one:

```bash
cd examples/multicore
sbatch pool_pi.slurm --workers 1
```

After it completes, compare it with the normal `pool_pi.slurm` job from
Exercise 6:

```bash
sacct -j <jobid> --format=JobID,JobName,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State
```

`CPUTime` is what the job reserved (`Elapsed` x `AllocCPUS`). `TotalCPU` is
what it used. Their ratio is the CPU efficiency.

* What efficiency did each job get?
* Was the memory request close to `MaxRSS`?

## Exercise 11 (Stretch): Point-to-Point Messages

Copy `examples/mpi/mpi_pi.py` and replace the `comm.reduce(...)` call with
point-to-point messages: every rank except 0 calls `comm.send(local, dest=0)`,
and rank 0 adds up `comm.recv(source=r)` for each other rank `r`. Check that
you get the same value of pi. Why do MPI libraries provide `reduce` anyway?

## Exercise 12: Try a Container

Submit:

```bash
sbatch examples/containers/apptainer_hello.slurm
```

Then inspect the output and the generated `.sif` image.
