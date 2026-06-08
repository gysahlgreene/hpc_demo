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

## Exercise 2: Submit a CPU Job

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

## Exercise 3: Read a Job Record

Pick one completed job ID and run:

```bash
sacct -j <jobid> --format=JobID,JobName,State,Elapsed,MaxRSS
scontrol show job <jobid>
```

Questions:

* Did the job finish successfully?
* How long did it run?
* Did it use close to the memory requested?

## Exercise 4: Run MPI

From the MPI example directory:

```bash
cd examples/mpi
sbatch mpi_demo.slurm
```

After it completes:

```bash
cat mpi-demo-*.out
```

Change `--ntasks-per-node` and observe how the rank count changes.

## Exercise 5: Try a Container

Submit:

```bash
sbatch examples/containers/apptainer_hello.slurm
```

Then inspect the output and the generated `.sif` image.
