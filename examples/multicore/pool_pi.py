"""Estimate pi on one node with multiprocessing.

pi = integral of 4 / (1 + x^2) from 0 to 1, approximated with n midpoint
rectangles. The rectangles are split evenly between worker processes.
"""
import argparse
import math
import os
import time
from multiprocessing import Pool


def partial_sum(bounds):
    start, stop, n = bounds
    h = 1.0 / n
    total = 0.0
    for i in range(start, stop):
        x = (i + 0.5) * h
        total += 4.0 / (1.0 + x * x)
    return total * h


def compute_pi(n, workers):
    chunks = [(n * w // workers, n * (w + 1) // workers, n) for w in range(workers)]
    with Pool(workers) as pool:
        return sum(pool.map(partial_sum, chunks))


def cpu_info():
    """Return (logical CPUs, physical cores) this process is allowed to run on."""
    if not hasattr(os, "sched_getaffinity"):  # macOS has no affinity API
        return os.cpu_count(), None
    cpus = os.sched_getaffinity(0)
    cores = set()
    for cpu in cpus:
        topology = f"/sys/devices/system/cpu/cpu{cpu}/topology/"
        with open(topology + "physical_package_id") as package, open(topology + "core_id") as core:
            cores.add((package.read(), core.read()))
    return len(cpus), len(cores)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=100_000_000, help="number of rectangles")
    parser.add_argument("--workers", type=int,
                        default=int(os.environ.get("SLURM_CPUS_PER_TASK", cpu_info()[0])),
                        help="worker processes (default: SLURM_CPUS_PER_TASK)")
    parser.add_argument("--sweep", action="store_true",
                        help="time 1, 2, 4, ... workers up to --workers")
    args = parser.parse_args()

    logical, cores = cpu_info()
    print(f"os.cpu_count()             = {os.cpu_count()}  <- every CPU on the node, not yours")
    print(f"logical CPUs you may use   = {logical}")
    print(f"physical cores behind them = {cores}")
    print(f"SLURM_CPUS_PER_TASK        = {os.environ.get('SLURM_CPUS_PER_TASK', 'not set')}")
    print()

    counts = [args.workers]
    if args.sweep:
        counts = sorted({2**k for k in range(args.workers.bit_length())} | {args.workers})

    print(f"{'workers':>7} {'seconds':>8} {'speedup':>8} {'efficiency':>10} {'error':>9}")
    baseline = None
    for workers in counts:
        start = time.perf_counter()
        pi = compute_pi(args.n, workers)
        seconds = time.perf_counter() - start
        error = abs(pi - math.pi)
        # Midpoint-rule error for this integral is about 1/(12 n^2); allow for rounding.
        assert error < 1.0 / args.n**2 + 1e-9, f"pi={pi} is wrong"
        if workers == 1:
            baseline = seconds
        if baseline:
            scaling = f"{baseline / seconds:8.2f} {baseline / seconds / workers:10.0%}"
        else:
            scaling = f"{'-':>8} {'-':>10}"
        print(f"{workers:7d} {seconds:8.2f} {scaling} {error:9.1e}")


# Required: worker processes re-import this file, and must not re-run main().
if __name__ == "__main__":
    main()
