# AI Training container — PyTorch + CUDA
# Provides a GPU-accelerated PyTorch environment for distributed training.
# No application-specific compression libraries.
#
# Build:
#   docker build -t sci-ai-training --build-arg CUDA_ARCH=80 .

FROM sci-hpc-base

ARG CUDA_ARCH=80

# PyTorch matching CUDA 12.6
RUN pip3 install --break-system-packages -q \
        torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu126 \
    && pip3 install --break-system-packages -q \
        numpy matplotlib tensorboard

# Example distributed training script
RUN cat > /opt/train_example.py << 'EOF'
"""
Distributed data-parallel training example.
Runs a small CNN on synthetic CIFAR-like data.

Single-node:
    python train_example.py --epochs 5

Multi-node (torchrun):
    torchrun --nnodes=N --nproc_per_node=1 \
             --node_rank=RANK \
             --master_addr=HEAD_IP \
             --master_port=29500 \
             train_example.py --epochs 5
"""
import os, argparse
import torch
import torch.nn as nn
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, TensorDataset, DistributedSampler

class SmallCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 32, 3, padding=1), nn.ReLU(),
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(),
            nn.AdaptiveAvgPool2d(4),
            nn.Flatten(),
            nn.Linear(64*4*4, 10),
        )
    def forward(self, x): return self.net(x)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--epochs', type=int, default=3)
    parser.add_argument('--batch', type=int, default=128)
    args = parser.parse_args()

    # Detect distributed environment
    rank       = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    local_rank = int(os.environ.get('LOCAL_RANK', 0))

    distributed = world_size > 1
    if distributed:
        dist.init_process_group('nccl')

    device = torch.device(f'cuda:{local_rank}' if torch.cuda.is_available() else 'cpu')
    if rank == 0:
        print(f"Training on {device}  world_size={world_size}")

    # Synthetic data (1000 samples, 3×32×32)
    X = torch.randn(1000, 3, 32, 32)
    y = torch.randint(0, 10, (1000,))
    dataset = TensorDataset(X, y)
    sampler = DistributedSampler(dataset, num_replicas=world_size, rank=rank) if distributed else None
    loader  = DataLoader(dataset, batch_size=args.batch, sampler=sampler, shuffle=(sampler is None))

    model = SmallCNN().to(device)
    if distributed:
        model = DDP(model, device_ids=[local_rank])

    opt = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = nn.CrossEntropyLoss()

    for epoch in range(args.epochs):
        if distributed: sampler.set_epoch(epoch)
        total_loss = 0.0
        for xb, yb in loader:
            xb, yb = xb.to(device), yb.to(device)
            loss = loss_fn(model(xb), yb)
            opt.zero_grad(); loss.backward(); opt.step()
            total_loss += loss.item()
        if rank == 0:
            print(f"Epoch {epoch+1}/{args.epochs}  loss={total_loss/len(loader):.4f}")

    if distributed:
        dist.destroy_process_group()
    if rank == 0:
        print("Training complete.")

if __name__ == '__main__':
    main()
EOF

CMD ["/bin/bash"]
