# AI Training — Distributed PyTorch on GPUs

A GPU-accelerated PyTorch training environment for scientific machine learning
workloads. This container provides PyTorch with CUDA 12.6, torchrun for
distributed training, and a self-contained example script
(`/opt/train_example.py`) that runs a small CNN on synthetic data.

---

## Prerequisites

- NVIDIA GPU (any CUDA 12.x-capable card)
- Docker with NVIDIA Container Toolkit
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-ai-training .
```

---

## 2  Single-Node Run

### Run the bundled example

```bash
docker run --gpus all --rm sci-ai-training \
  python3 /opt/train_example.py --epochs 5 --batch 128
```

### Mount your own training script

```bash
docker run --gpus all --rm \
  -v $(pwd)/my_train.py:/workspace/train.py \
  -v $(pwd)/data:/data \
  -v $(pwd)/checkpoints:/checkpoints \
  sci-ai-training \
  python3 /workspace/train.py --data /data --ckpt /checkpoints
```

### Multi-GPU on one node (torchrun)

```bash
docker run --gpus all --rm sci-ai-training \
  torchrun --standalone --nproc_per_node=$(nvidia-smi -L | wc -l) \
    /opt/train_example.py --epochs 5
```

---

## 3  Multi-Node Distributed Training

PyTorch uses `torchrun` (formerly `torch.distributed.launch`) for multi-node
training. Each node runs one container; a `MASTER_ADDR` / `MASTER_PORT` must
be reachable from all worker nodes.

### Head node (rank 0)

```bash
docker run --gpus all --rm \
  --network host \
  -v $(pwd)/checkpoints:/checkpoints \
  sci-ai-training \
  torchrun \
    --nnodes=3 \
    --nproc_per_node=1 \
    --node_rank=0 \
    --master_addr=$(hostname) \
    --master_port=29500 \
    /opt/train_example.py --epochs 10
```

### Worker nodes (rank 1, 2, ...)

```bash
# Run on worker1 (change --node_rank for each worker)
docker run --gpus all --rm \
  --network host \
  sci-ai-training \
  torchrun \
    --nnodes=3 \
    --nproc_per_node=1 \
    --node_rank=1 \
    --master_addr=HEAD_IP \
    --master_port=29500 \
    /opt/train_example.py --epochs 10
```

All nodes must start within the default rendezvous timeout (300 s). The
`MASTER_ADDR` must be the actual IP or hostname of the head node.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate-single
```

Expected output:
```
Training on cuda:0  world_size=1
Epoch 1/3  loss=2.3021
Epoch 2/3  loss=2.2897
Epoch 3/3  loss=2.2701
Training complete.
```

### Validate multi-node (3 containers via torchrun rendezvous)

```bash
docker compose up
```

All three `node0`, `node1`, `node2` services start together. They rendezvous
through `node0:29500` and train in lock-step. Expected output (from node0):
```
Training on cuda:0  world_size=3
Epoch 1/3  loss=2.3021
Epoch 2/3  loss=2.2912
Epoch 3/3  loss=2.2784
Training complete.
```

```bash
docker compose down
```
