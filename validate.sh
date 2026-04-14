#!/usr/bin/env bash
# validate.sh — run all scientific HPC application cluster tests.
#
# Usage:
#   ./validate.sh                  # test all apps (grayscott first, then others)
#   ./validate.sh grayscott        # test a single app
#   ./validate.sh grayscott lammps # test specific apps
#
# Each app is tested in two phases:
#   1. Single-node: 4 MPI ranks on one container (--oversubscribe)
#   2. Cluster:     head + 2 workers on separate containers, MPI over SSH
#
# Exit code: 0 if all tests pass, 1 if any fail.

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((PASS++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; ((FAIL++)) || true; }
banner() {
    echo
    echo -e "${BOLD}════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}════════════════════════════════════════${NC}"
}

# ── Build the shared base image ────────────────────────────────────────────
banner "Building sci-hpc-base"
if ! docker build -t sci-hpc-base "$REPO/base" 2>&1; then
    echo -e "${RED}Base image build failed — cannot continue.${NC}"
    exit 1
fi
echo -e "${GREEN}sci-hpc-base built.${NC}"

# ── Generic MPI-app test function ──────────────────────────────────────────
# Args: <app> <build_timeout_s> <run_timeout_s>
test_mpi_app() {
    local app=$1
    local build_timeout=${2:-3600}
    local run_timeout=${3:-300}

    banner "Testing $app"
    cd "$REPO/$app"

    # Build
    echo "→ Building sci-${app}..."
    if ! timeout "$build_timeout" docker compose build 2>&1; then
        fail "$app: image build"
        cd "$REPO"
        return
    fi
    echo -e "${GREEN}Build OK${NC}"

    # Single-node
    echo "→ Single-node test (4 MPI ranks, 1 container)..."
    docker compose down -v 2>/dev/null || true
    if timeout "$run_timeout" docker compose run --rm validate 2>&1; then
        pass "$app: single-node"
    else
        fail "$app: single-node"
    fi

    # Cluster (multi-node)
    echo "→ Cluster test (head + worker1 + worker2)..."
    docker compose down -v 2>/dev/null || true
    if timeout "$run_timeout" docker compose up \
            --abort-on-container-exit \
            --exit-code-from head \
            head 2>&1; then
        pass "$app: cluster (multi-node)"
    else
        fail "$app: cluster (multi-node)"
    fi
    docker compose down -v 2>/dev/null || true

    cd "$REPO"
}

# ── AI Training test (torchrun rendezvous, not MPI+SSH) ────────────────────
test_ai_training() {
    local run_timeout=${1:-300}

    banner "Testing ai_training"
    cd "$REPO/ai_training"

    echo "→ Building sci-ai-training..."
    if ! timeout 1800 docker compose build 2>&1; then
        fail "ai_training: image build"
        cd "$REPO"
        return
    fi
    echo -e "${GREEN}Build OK${NC}"

    # Single-node
    echo "→ Single-node test..."
    docker compose down -v 2>/dev/null || true
    if timeout "$run_timeout" docker compose run --rm validate 2>&1; then
        pass "ai_training: single-node"
    else
        fail "ai_training: single-node"
    fi

    # Multi-node (all 3 nodes start together via torchrun)
    echo "→ Cluster test (3 torchrun nodes)..."
    docker compose down -v 2>/dev/null || true
    if timeout "$run_timeout" docker compose up \
            --abort-on-container-exit \
            --exit-code-from node0 \
            node0 node1 node2 2>&1; then
        pass "ai_training: cluster (multi-node)"
    else
        fail "ai_training: cluster (multi-node)"
    fi
    docker compose down -v 2>/dev/null || true

    cd "$REPO"
}

# ── Select apps to test ────────────────────────────────────────────────────
if [ $# -gt 0 ]; then
    APPS=("$@")
else
    # Default order: fast builds first
    APPS=(grayscott ai_training lammps vpic nyx warpx)
fi

for app in "${APPS[@]}"; do
    case "$app" in
        ai_training) test_ai_training 300 ;;
        grayscott)   test_mpi_app grayscott  600  120 ;;
        lammps)      test_mpi_app lammps    3600  300 ;;
        vpic)        test_mpi_app vpic      3600  300 ;;
        nyx)         test_mpi_app nyx       7200  300 ;;
        warpx)       test_mpi_app warpx     7200  300 ;;
        *)           echo "Unknown app: $app"; fail "unknown: $app" ;;
    esac
done

# ── Summary ────────────────────────────────────────────────────────────────
banner "Results"
echo -e "  ${GREEN}Passed${NC}: $PASS"
echo -e "  ${RED}Failed${NC}: $FAIL"
echo
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}$FAIL test(s) failed.${NC}"
    exit 1
fi
