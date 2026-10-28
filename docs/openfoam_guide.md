# Running OpenFOAM in Parallel on Boole

[OpenFOAM](https://www.openfoam.com) is a widely used open-source package for
computational fluid dynamics (CFD). It is also a real MPI program, written in
C++. This guide shows how to run it in parallel on Boole and how well that
works in practice. All the numbers come from real runs on Boole.

Before this page, read [Many Nodes: MPI](parallel_computing_guide.md#6-many-nodes-mpi).
OpenFOAM splits its work exactly like `mpi_heat.py` there: each rank owns a
piece of the mesh and swaps boundary values with its neighbours.

## Setting Up OpenFOAM

OpenFOAM v2412 is installed on Boole. **`module load` for OpenFOAM doesn't
work at the moment** (one of its dependencies is registered under the wrong
name), so load its MPI and then OpenFOAM's own setup script:

```bash
module load openmpi/5.0.5-vzxfkrh   # the MPI build OpenFOAM was compiled with
set +u   # only needed in scripts using `set -u`: the setup script reads unset variables
source /opt/spack/spack/opt/spack/linux-cascadelake/openfoam-2412-apc5rmqfcstzgka25loohisejf6flusj/etc/bashrc
set -u
```

Load the modules after the usual
[module setup lines](boole_hpc_platform_guide.md#loading-software-with-modules).
After this, OpenFOAM commands such as `blockMesh` and `icoFoam` work, and
`$FOAM_TUTORIALS` points to the example cases that ship with OpenFOAM.
OpenFOAM is built for the `physical` nodes' processors, so run it there.

## How OpenFOAM Runs in Parallel

A parallel OpenFOAM run has four steps:

```text
blockMesh          build the mesh                       (1 process)
decomposePar       split it into one piece per rank     (1 process)
srun <solver> -parallel   every rank solves its piece   (all ranks, MPI)
reconstructPar     join the pieces back together        (1 process)
```

`decomposePar` reads `system/decomposeParDict`. Two settings matter:

- `numberOfSubdomains` must equal the number of MPI ranks (`$SLURM_NTASKS`).
- `method scotch` splits a mesh into any number of pieces automatically.
  Many tutorials use `method hierarchical` with a fixed split such as
  `(3 3 1)`, which only works for exactly 9 ranks. With any other count,
  `decomposePar` fails with `Wrong number of domain divisions`.

After `decomposePar`, the case has one `processor0`, `processor1`, ...
folder per rank, and each rank reads and writes only its own.

## The Example: a Lid-Driven Cavity

`examples/openfoam/cavity.slurm` runs OpenFOAM's first tutorial, a square
box of fluid whose lid slides sideways. Its mesh is 10 times finer in each
direction than the tutorial's: 200 x 200 = 40,000 cells. The script runs
all four steps on 8 ranks of one `physical` node:

```bash
cd ~/hpc_demo
sbatch examples/openfoam/cavity.slurm
cat openfoam-cavity-<jobid>.out
```

```text
OpenFOAM v2412 on h17u17
Mesh 200 x 200 = 40000 cells, 100 time steps. Cases in /home/<you>/hpc_demo/openfoam-cavity-<jobid>

8 ranks on 1 node(s): 7.3 s   (Courant Number mean: 0.100853 max: 0.49187)
...
```

The case is in `openfoam-cavity-<jobid>/ranks-8`: the mesh pieces
(`processor0` to `processor7`), the log of each step (`log.icoFoam` and so
on), and the result at the final time (`0.025`). To look at the result,
create an empty `case.foam` file in that folder and open it in the
**ParaView** app in Open OnDemand.

The **Courant number** in the output measures how far the flow moves in one
time step, in cells. The script picks a time step that keeps it below 1, or
the simulation becomes unstable.

Options (see the comments at the top of the script):

- `--export=ALL,MESH=100` changes the mesh size (here 100 x 100).
- Rank counts after the script name run a scaling study, e.g.
  `sbatch --nodes=4 examples/openfoam/cavity.slurm 1 2 4 8 16 32`.

## How Well Does It Scale?

The same 100 time steps on 1 to 32 ranks, for two mesh sizes:

```text
Mesh 200 x 200 = 40000 cells
 ranks  nodes  cells/rank   seconds  speedup  efficiency
     1      1       40000      38.4     1.00        100%
     2      1       20000      21.4     1.79         90%
     4      1       10000      11.9     3.23         81%
     8      1        5000       8.0     4.80         60%
    16      2        2500      46.4     0.83          5%
    32      4        1250      49.6     0.77          2%

Mesh 300 x 300 = 90000 cells
 ranks  nodes  cells/rank   seconds  speedup  efficiency
     1      1       90000     144.3     1.00        100%
     2      1       45000      71.1     2.03        101%
     4      1       22500      44.6     3.24         81%
     8      1       11250      21.5     6.71         84%
    16      2        5625      85.6     1.69         11%
    32      4        2812      48.6     2.97          9%
```

What this shows:

- **On one node, OpenFOAM scales well, and better for bigger meshes.** With
  8 ranks, the 90,000-cell mesh ran at 84% efficiency (about 11,000 cells
  per rank), the 40,000-cell mesh at 60% (5,000 cells per rank). Each rank
  needs enough cells to be worth the communication.
- **Using a second node made it 4-6 times *slower*.** The pressure solver
  takes hundreds of iterations every time step, and each iteration swaps
  boundary values and adds up a global sum across all ranks. On Boole a
  message between nodes takes about 30 times longer than within a node
  ([measured here](parallel_computing_guide.md#point-to-point-talking-to-neighbours)),
  so with ranks on several nodes the solver spends most of its time waiting.
- **The answer didn't change.** The Courant numbers were the same on every
  rank count, as they should be: splitting the mesh must not change the
  physics.

So, on Boole today:

1. **Run OpenFOAM on one node:** `--nodes=1 --ntasks-per-node=8
   --hint=nomultithread`.
2. **Before using more nodes, measure.** Run a few time steps of your own
   case on 8 and 16 ranks and compare. We didn't find a case where a second
   node helped.
3. **Keep enough cells per rank.** Below about 10,000 cells per rank,
   efficiency dropped quickly even within a node.

## Running Your Own Case

[templates/openfoam.slurm](../templates/openfoam.slurm) runs any OpenFOAM
case in parallel. Copy it into your case folder (the one with `0/`,
`constant/` and `system/`), set the solver and resources on the lines marked
`CHANGE`, and submit it from there:

```bash
cd ~/myproject/mycase
cp ~/hpc_demo/templates/openfoam.slurm .
nano openfoam.slurm
sbatch openfoam.slurm
```

It sets `numberOfSubdomains` to the number of ranks and the method to
`scotch` for you. If a step fails, the job's output file says which, and the
step's log (`log.decomposePar`, `log.<solver>`, ...) in the case folder says
why.

## Checklist

- [ ] `module load openmpi/5.0.5-vzxfkrh`, then source OpenFOAM's
      `etc/bashrc` (not `module load openfoam`).
- [ ] `numberOfSubdomains` = number of ranks, `method scotch`.
- [ ] Solver started with `srun --mpi=pmix_v5 <solver> -parallel`.
- [ ] One node, 8 ranks, `--hint=nomultithread`, unless a test showed more
      nodes help.
- [ ] Enough cells per rank (tens of thousands is comfortable).
- [ ] Time step small enough that the Courant number stays below 1.
