"""1-D heat diffusion with MPI: the classic halo-exchange pattern.

A ring of n cells starts with a hot spot in the middle and is stepped forward
in time. Each rank owns a strip of cells plus one "ghost" cell at each end.
Every step, each rank swaps its edge cells with its left and right neighbours
(point-to-point Sendrecv), updates its strip, then joins a global Allreduce
(the kind of convergence check real solvers do every iteration).

Unlike mpi_pi.py, the ranks talk every step, so adding ranks has a cost.
"""
import argparse
import math

import numpy as np
from mpi4py import MPI

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--n", type=int, default=8_000_000, help="number of cells")
parser.add_argument("--steps", type=int, default=250, help="time steps")
args = parser.parse_args()
n, steps = args.n, args.steps

# This rank's strip of the ring, with ghost cells at u[0] and u[-1].
first, last = n * rank // size, n * (rank + 1) // size
x = (np.arange(first, last) + 0.5) / n
u = np.zeros(last - first + 2)
u[1:-1] = np.exp(-100 * (x - 0.5) ** 2)
left, right = (rank - 1) % size, (rank + 1) % size  # neighbours on the ring

heat = heat_at_start = comm.allreduce(u[1:-1].sum())

comm.Barrier()  # start the clock together
start_time = MPI.Wtime()
for step in range(steps):
    # Send my first cell left while receiving my right ghost from the right, then the mirror image.
    comm.Sendrecv(u[1:2], dest=left, recvbuf=u[-1:], source=right)
    comm.Sendrecv(u[-2:-1], dest=right, recvbuf=u[:1], source=left)
    u[1:-1] += 0.25 * (u[:-2] - 2 * u[1:-1] + u[2:])
    heat = comm.allreduce(u[1:-1].sum())
seconds = comm.allreduce(MPI.Wtime() - start_time, op=MPI.MAX)

# Every cell sees the same neighbours whatever the rank count, so the peak is identical.
peak = comm.allreduce(u[1:-1].max(), op=MPI.MAX)

if rank == 0:
    # Heat only moves around the ring, so the total must not change.
    assert math.isclose(heat, heat_at_start, rel_tol=1e-9), f"heat {heat} != {heat_at_start}"
    print(f"{n} cells, {steps} steps on {size} ranks: peak temperature {peak:.10f}")
    print(f"RESULT ranks={size} threads=1 seconds={seconds:.3f} value={peak:.10f}")
