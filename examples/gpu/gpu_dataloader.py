"""How many CPU cores does a GPU job need?

Each training image is made on the CPU (standing in for reading and augmenting
a real image), then a small network learns from it on the GPU. The images are
made by PyTorch data-loader worker processes, one per CPU core. With too few
workers the GPU sits waiting for data; past some point, more workers add
nothing. This times the same training with 0, 1, 2, 4, ... workers.
"""
import argparse
import math
import os
import threading
import time

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset


class SyntheticImages(Dataset):
    """Fake 3x64x64 images in 10 classes; cpu_work sets the CPU cost of each one."""

    def __init__(self, size, cpu_work):
        self.size, self.cpu_work = size, cpu_work

    def __len__(self):
        return self.size

    def __getitem__(self, i):
        label = i % 10
        img = np.random.default_rng(i).random((3, 64, 64), dtype=np.float32)
        for _ in range(self.cpu_work):  # stands in for decoding and augmentation
            img = np.sqrt(img * img + 1e-3).astype(np.float32)
        img[0] += 0.1 * label  # make the class learnable
        return torch.from_numpy(img), label


def make_model(width):
    return nn.Sequential(
        nn.Conv2d(3, width, 3, padding=1), nn.ReLU(),
        nn.Conv2d(width, width, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
        nn.Conv2d(width, 2 * width, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
        nn.AdaptiveAvgPool2d(1), nn.Flatten(), nn.Linear(2 * width, 10),
    )


class GpuMonitor(threading.Thread):
    """Samples GPU utilisation (% of time the GPU was busy) in the background."""

    def __init__(self):
        super().__init__(daemon=True)
        self.samples, self.done = [], threading.Event()

    def run(self):
        while not self.done.is_set():
            try:
                self.samples.append(torch.cuda.utilization())
            except Exception:  # NVIDIA's monitoring library can fail even when CUDA works
                self.samples = None
                return
            time.sleep(0.2)

    def stop(self):
        """Return the average GPU busy %, or None if it couldn't be measured."""
        self.done.set()
        self.join()
        return sum(self.samples) / len(self.samples) if self.samples else None


def train(workers, args, model, optimiser, loss_fn):
    """Train for args.batches batches; return (images per second, GPU busy %, losses)."""
    dataset = SyntheticImages((args.batches + 5) * args.batch, args.cpu_work)
    loader = iter(DataLoader(dataset, batch_size=args.batch, num_workers=workers,
                             shuffle=True, pin_memory=True))
    losses = []

    def step():
        images, labels = next(loader)
        images, labels = images.cuda(non_blocking=True), labels.cuda(non_blocking=True)
        optimiser.zero_grad()
        loss = loss_fn(model(images), labels)
        loss.backward()
        optimiser.step()
        losses.append(loss.item())

    for _ in range(5):  # warm-up: start the workers before timing
        step()
    torch.cuda.synchronize()
    monitor = GpuMonitor()
    monitor.start()
    start = time.perf_counter()
    for _ in range(args.batches):
        step()
    torch.cuda.synchronize()
    seconds = time.perf_counter() - start
    return args.batches * args.batch / seconds, monitor.stop(), losses


def main():
    cpus = len(os.sched_getaffinity(0))
    default_workers = sorted({w for w in (0, 1, 2, 4, 8, 16, 32) if w < cpus} | {cpus - 1})

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workers", default=",".join(map(str, default_workers)),
                        help="comma-separated data-loader worker counts to try")
    parser.add_argument("--batches", type=int, default=150, help="batches timed per run")
    parser.add_argument("--batch", type=int, default=256, help="images per batch")
    parser.add_argument("--cpu-work", type=int, default=20, help="CPU cost of each image")
    parser.add_argument("--width", type=int, default=64, help="network size (GPU cost)")
    args = parser.parse_args()

    assert torch.cuda.is_available(), (
        "No GPU visible. Did you request --gres=gpu:1? If so, PyTorch may be too new "
        "for the GPU driver: rerun setup_torch_env.sh to get the tested version.")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"CPU cores this job may use: {cpus}")
    print()

    torch.manual_seed(0)
    model = make_model(args.width).cuda()
    optimiser = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = nn.CrossEntropyLoss()

    print(f"{'workers':>7} {'images/s':>9} {'GPU busy':>9}")
    losses = []
    for workers in map(int, args.workers.split(",")):
        rate, busy, run_losses = train(workers, args, model, optimiser, loss_fn)
        losses += run_losses
        shown = "n/a" if busy is None else f"{busy:.0f}%"
        print(f"{workers:7d} {rate:9.0f} {shown:>9}", flush=True)
        print(f"RESULT workers={workers} images_per_s={rate:.0f} gpu_busy={shown}", flush=True)

    # Self-check: the network really trained (the loss is finite and went down).
    first, last = sum(losses[:10]) / 10, sum(losses[-10:]) / 10
    assert math.isfinite(last) and last < first, (first, last)
    print(f"\nLoss fell from {first:.2f} to {last:.2f}: the network is learning.")


# Required: data-loader workers re-import this file, and must not re-run main().
if __name__ == "__main__":
    main()
