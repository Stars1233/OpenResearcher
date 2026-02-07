#!/bin/bash
# Start multiple vLLM servers, one per TP group
# Usage: ./scripts/start_nemotron_servers.sh [tensor_parallel_size] [base_port] [cuda_visible_devices] [model_path]
# Example: ./scripts/start_nemotron_servers.sh 2 8001 "0,1,2,3,4,5" "/path/to/model"

TP_SIZE=${1:-2}
BASE_PORT=${2:-8001}
CUDA_VISIBLE_DEVICES=${3:-0,1,2,3}
MODEL=${4:-"OpenResearcher/OpenResearcher-30B-A3B"}

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Detect available GPUs
if [ -n "$CUDA_VISIBLE_DEVICES" ]; then
    IFS=',' read -ra GPU_ARRAY <<< "$CUDA_VISIBLE_DEVICES"
else
    # Auto-detect all GPUs
    NUM_GPUS=$(nvidia-smi --list-gpus | wc -l)
    GPU_ARRAY=($(seq 0 $((NUM_GPUS-1))))
fi

TOTAL_GPUS=${#GPU_ARRAY[@]}

# Calculate number of servers
if [ $((TOTAL_GPUS % TP_SIZE)) -ne 0 ]; then
    echo "Error: Total GPUs ($TOTAL_GPUS) must be divisible by TP_SIZE ($TP_SIZE)"
    exit 1
fi

NUM_SERVERS=$((TOTAL_GPUS / TP_SIZE))

echo "=========================================="
echo "Starting Multiple vLLM Servers"
echo "=========================================="
echo "Model: $MODEL"
echo "Total GPUs: $TOTAL_GPUS (${GPU_ARRAY[@]})"
echo "Tensor Parallel Size: $TP_SIZE"
echo "Number of Servers: $NUM_SERVERS"
echo "Base Port: $BASE_PORT"
echo "=========================================="
echo ""

# Create log directory
mkdir -p logs

# Start each server in background
PIDS=()
for i in $(seq 0 $((NUM_SERVERS-1))); do
    # Get GPU IDs for this server
    START_IDX=$((i * TP_SIZE))
    END_IDX=$((START_IDX + TP_SIZE - 1))

    SERVER_GPUS=""
    for j in $(seq $START_IDX $END_IDX); do
        if [ -n "$SERVER_GPUS" ]; then
            SERVER_GPUS="$SERVER_GPUS,${GPU_ARRAY[$j]}"
        else
            SERVER_GPUS="${GPU_ARRAY[$j]}"
        fi
    done

    PORT=$((BASE_PORT + i))
    LOG_FILE="logs/vllm_server_${PORT}.log"

    echo "Starting Server $((i+1))/$NUM_SERVERS:"
    echo "  - GPUs: $SERVER_GPUS"
    echo "  - Port: $PORT"
    echo "  - Log: $LOG_FILE"

    CUDA_VISIBLE_DEVICES=$SERVER_GPUS python scripts/deploy_vllm_service.py \
        --model $MODEL \
        --port $PORT \
        --tensor_parallel_size $TP_SIZE \
        --gpu_memory_utilization 0.9 \
        > "$LOG_FILE" 2>&1 &

    PID=$!
    PIDS+=($PID)
    echo "  - PID: $PID"
    echo ""

    # Wait a bit before starting next server
    sleep 2
done

echo "=========================================="
echo "All servers started!"
echo "=========================================="
echo ""
echo "Server URLs:"
for i in $(seq 0 $((NUM_SERVERS-1))); do
    PORT=$((BASE_PORT + i))
    echo "  - http://localhost:${PORT}/v1"
done
echo ""
echo "To stop all servers:"
echo "  kill ${PIDS[@]}"
echo ""
echo "Or save PIDs to file:"
echo "  echo '${PIDS[@]}' > logs/server_pids.txt"
echo ""

# Save PIDs
echo "${PIDS[@]}" > logs/server_pids.txt
echo "PIDs saved to logs/server_pids.txt"
echo ""
echo "To stop all servers later:"
echo "  kill \$(cat logs/server_pids.txt)"
echo ""
echo "Press Ctrl+C to stop all servers now, or close this terminal to keep them running."
echo "=========================================="

# Wait for any server to exit
wait -n

# If one exits, kill all others
echo ""
echo "One server exited. Stopping all servers..."
kill ${PIDS[@]} 2>/dev/null
wait
echo "All servers stopped."
