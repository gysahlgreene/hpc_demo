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

## Exercise 5: Run MPI

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
cat mpi-demo-*.out
```

Change `--ntasks-per-node` and observe how the rank count changes.

## Exercise 6: Try a Container

Submit:

```bash
sbatch examples/containers/apptainer_hello.slurm
```

Then inspect the output and the generated `.sif` image.
