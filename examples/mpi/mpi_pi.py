"""Estimate pi with MPI, optionally with threads inside each rank (hybrid).

pi = integral of 4 / (1 + x^2) from 0 to 1, approximated with n midpoint
rectangles. Each rank integrates its own slice of the rectangles; a reduce
adds the slices together on rank 0.
"""
import argparse
import math
import os
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from mpi4py import MPI

# Rectangles per numpy call. Small enough that each call's arrays stay in the CPU
# cache: 1_000_000 runs twice as slow and stops scaling within a node (see the guide).
CHUNK = 32_768


def chunk_sum(start, stop, h):
    x = (np.arange(start, stop, dtype=np.float64) + 0.5) * h
    return np.sum(4.0 / (1.0 + x * x)) * h


comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--n", type=int, default=4_000_000_000, help="number of rectangles")
args = parser.parse_args()

# Usual pattern: rank 0 decides the input (here it just parsed it), then shares it.
n = comm.bcast(args.n if rank == 0 else None, root=0)

# Threads per rank: 1 for pure MPI, SLURM_CPUS_PER_TASK for hybrid jobs.
# numpy releases the GIL during array maths, but threads queue for it between calls.
threads = int(os.environ.get("SLURM_CPUS_PER_TASK", "1"))

# This rank's share of the rectangles, cut into chunks for the threads.
first, last = n * rank // size, n * (rank + 1) // size
chunks = [(start, min(start + CHUNK, last)) for start in range(first, last, CHUNK)]

comm.Barrier()  # start the clock together
start_time = MPI.Wtime()
with ThreadPoolExecutor(threads) as pool:
    local = sum(pool.map(lambda c: chunk_sum(c[0], c[1], 1.0 / n), chunks))
pi = comm.reduce(local, op=MPI.SUM, root=0)
seconds = MPI.Wtime() - start_time  # on rank 0 this includes waiting for the slowest rank

if rank == 0:
    error = abs(pi - math.pi)
    # Midpoint-rule error for this integral is about 1/(12 n^2); allow for rounding.
    assert error < 1.0 / n**2 + 1e-9, f"pi={pi} is wrong"
    print(f"pi = {pi:.12f} (error {error:.1e}) from {size} ranks x {threads} threads")
    print(f"RESULT ranks={size} threads={threads} seconds={seconds:.3f} value={pi:.10f}")
