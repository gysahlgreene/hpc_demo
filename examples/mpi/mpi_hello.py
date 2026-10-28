from mpi4py import MPI
import os
import socket


comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

# The CPUs this rank is pinned to: shows how Slurm placed and bound each rank.
cpus = sorted(os.sched_getaffinity(0))
print(f"Hello from rank {rank} of {size} on {socket.gethostname()} (cpus {cpus})")
