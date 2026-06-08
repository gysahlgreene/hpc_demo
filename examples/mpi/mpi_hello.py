from mpi4py import MPI
import socket


comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

print(f"Hello from rank {rank} of {size} on {socket.gethostname()}")
