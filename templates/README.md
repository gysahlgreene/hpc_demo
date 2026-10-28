# Job Script Templates

Starting points for running **your own** work on Boole. Each template is a
complete job script; copy it into your project folder and edit the lines
marked `CHANGE`.

| Your work looks like | Template | Background |
| --- | --- | --- |
| One program, one core | [serial.slurm](serial.slurm) | [Your First Batch Job](../docs/boole_hpc_platform_guide.md#your-first-batch-job) |
| One program using several cores (multiprocessing, joblib, OpenMP, R `parallel`) | [multicore.slurm](multicore.slurm) | [Many Cores on One Node](../docs/parallel_computing_guide.md#4-many-cores-on-one-node) |
| The same program on many input files or parameters | [array_files.slurm](array_files.slurm) | [Job Arrays](../docs/parallel_computing_guide.md#5-many-independent-jobs-job-arrays) |
| An MPI program across nodes | [mpi.slurm](mpi.slurm) | [MPI](../docs/parallel_computing_guide.md#6-many-nodes-mpi) |
| Training or inference on a GPU | [gpu.slurm](gpu.slurm) | [GPU Guide](../docs/gpu_guide.md) |
| A program in your own Conda environment | [conda.slurm](conda.slurm) | [Conda / Miniforge](../docs/boole_hpc_platform_guide.md#conda--miniforge) |

Not sure which? See [Pick the Right Pattern](../docs/parallel_computing_guide.md#3-pick-the-right-pattern).

## How to Use a Template

1. Copy it next to your code, e.g.
   `mkdir -p ~/myproject && cp ~/hpc_demo/templates/serial.slurm ~/myproject/run.slurm`.
2. Edit every line marked `CHANGE` (`nano ~/myproject/run.slurm`).
3. **Test small first.** Run a short version of your work with a short
   `--time`, so mistakes cost minutes, not hours.
4. When it finishes, check what it really used:

   ```bash
   sacct -j <jobid> --format=JobID,JobName,AllocCPUS,Elapsed,CPUTime,TotalCPU,MaxRSS,State
   ```

   Then set `--mem`, `--time` and the CPU count to what you saw plus a
   margin. See [Was My Job Efficient?](../docs/parallel_computing_guide.md#9-was-my-job-efficient)
5. Scale up.

Output files are named `<job name>-<job ID>.out` (`%x-%j.out`), or
`<job name>-<array job ID>_<task>.out` for the array template, and appear in
the folder you ran `sbatch` from.
