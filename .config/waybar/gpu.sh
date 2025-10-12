#!/bin/bash

GPU_INDEX=0

GPU_NAME=$(nvidia-smi --id=$GPU_INDEX --query-gpu=name --format=csv,noheader)
GPU_UTIL=$(nvidia-smi --id=$GPU_INDEX --query-gpu=utilization.gpu --format=csv,noheader,nounits)
GPU_MEM_USED=$(nvidia-smi --id=$GPU_INDEX --query-gpu=memory.used --format=csv,noheader,nounits)
GPU_MEM_TOTAL=$(nvidia-smi --id=$GPU_INDEX --query-gpu=memory.total --format=csv,noheader,nounits)
GPU_TEMP=$(nvidia-smi --id=$GPU_INDEX --query-gpu=temperature.gpu --format=csv,noheader,nounits)

GPU_MEM_PERCENT=$(awk "BEGIN {printf \"%.0f\", ($GPU_MEM_USED/$GPU_MEM_TOTAL)*100}")

GPU_MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_MEM_USED/1024}")
GPU_MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_MEM_TOTAL/1024}")

echo "{\"text\":\"$GPU_UTIL%\", \"tooltip\":\"$GPU_NAME\\nGPU Usage: $GPU_UTIL%\\nMemory: ${GPU_MEM_USED_GB}GB / ${GPU_MEM_TOTAL_GB}GB ($GPU_MEM_PERCENT%)\\nTemp: ${GPU_TEMP}°C\"}"
